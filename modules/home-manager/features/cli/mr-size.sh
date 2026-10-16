# mr-size: how big is the merge request this branch would open, and is that
# more than one person can review in a sitting?
#
#   mr-size                  report the current branch against its base
#   mr-size check [MODE]     exit 1 when over the limit (MODE: range, staged, worktree)
#   mr-size claude-pre       PreToolUse hook: block git commit/push and MR creation
#   mr-size claude-post      PostToolUse hook: warn once the work in progress outgrows an MR
#
# The base is the branch this one is stacked on, not necessarily the default
# branch: branch.<name>.mrBase when set, else the nearest local branch the
# current one forked from, else origin's default branch. So a stack of small
# branches is measured one link at a time, the way each MR will be reviewed.
#
# Lockfiles and generated output are not counted. A repository adds its own
# patterns, one glob per line, in .mr-size-ignore at its root.
#
# Limits, all overridable per repository with git config:
#   mrSize.maxLines   added + deleted lines   (default 400)
#   mrSize.maxFiles   files touched           (default 20)
# branch.<name>.mrSizeOverride=true lets one branch through; that is the
# user's call, never the agent's.

ignore_globs=(
  '**/*.lock' '**/*.lockb' '**/package-lock.json' '**/npm-shrinkwrap.json'
  '**/pnpm-lock.yaml' '**/go.sum' '**/*.snap' '**/__snapshots__/**'
  '**/*.min.js' '**/*.min.css' '**/*.map' '**/dist/**' '**/generated/**'
  '**/*.generated.*' '**/*.pb.go' '**/*_pb2.py'
)

default_branch() {
  local ref
  ref="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ]; then
    echo "$ref"
    return
  fi
  for b in main master develop; do
    if git rev-parse --verify --quiet "refs/heads/$b" >/dev/null; then
      echo "$b"
      return
    fi
  done
}

# The ref this branch's MR would target, printed as "<ref> <merge-base sha>".
resolve_base() {
  local branch="$1" explicit def best="" best_mb="" best_n="" mb n
  explicit="$(git config --get "branch.$branch.mrBase" 2>/dev/null || true)"
  if [ -n "$explicit" ]; then
    echo "$explicit $(git merge-base "$explicit" HEAD)"
    return
  fi
  def="$(default_branch)"
  # The default branch itself is measured against what it has not pushed yet.
  if [ "$branch" = "${def#origin/}" ] && git rev-parse --verify --quiet '@{u}' >/dev/null; then
    echo "$(git rev-parse --abbrev-ref '@{u}') $(git merge-base '@{u}' HEAD)"
    return
  fi
  while IFS= read -r cand; do
    [ "$cand" = "$branch" ] && continue
    mb="$(git merge-base "$cand" HEAD 2>/dev/null)" || continue
    # A branch stacked on this one, or still sitting where this one started,
    # shares HEAD or nothing new; it is not what this branch forked from.
    [ "$mb" = "$(git rev-parse HEAD)" ] && continue
    n="$(git rev-list --count "$mb..HEAD")"
    if [ -z "$best_n" ] || [ "$n" -lt "$best_n" ]; then
      best="$cand" best_mb="$mb" best_n="$n"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads; [ -n "$def" ] && echo "$def")
  if [ -n "$best" ]; then
    echo "$best $best_mb"
  else
    echo "HEAD $(git rev-parse HEAD)"
  fi
}

pathspecs() {
  local g
  echo ':(top)'
  for g in "${ignore_globs[@]}"; do echo ":(top,exclude,glob)$g"; done
  if [ -f .mr-size-ignore ]; then
    while IFS= read -r g; do
      case "$g" in '' | '#'*) continue ;; esac
      echo ":(top,exclude,glob)$g"
    done <.mr-size-ignore
  fi
}

# numstat rows for the given mode against merge-base $1:
#   range    committed work only (what a push carries)
#   staged   committed + index (what the next commit would carry)
#   worktree committed + every tracked edit + untracked files
numstat() {
  local mb="$1" mode="$2" specs=()
  mapfile -t specs < <(pathspecs)
  case "$mode" in
    range) git diff --numstat -M "$mb" HEAD -- "${specs[@]}" ;;
    staged) git diff --numstat -M --cached "$mb" -- "${specs[@]}" ;;
    worktree)
      git diff --numstat -M "$mb" -- "${specs[@]}"
      git ls-files --others --exclude-standard -z -- "${specs[@]}" |
        while IFS= read -r -d '' f; do
          if grep -Iq . "$f" 2>/dev/null; then
            printf '%s\t0\t%s\n' "$(wc -l <"$f" | tr -d ' ')" "$f"
          else
            printf -- '-\t-\t%s\n' "$f"
          fi
        done
      ;;
  esac
}

# Sets: branch base files lines rows max_lines max_files
measure() {
  local mode="$1" resolved mb
  max_lines="${MR_SIZE_MAX_LINES:-$(git config --get mrSize.maxLines || echo 400)}"
  max_files="${MR_SIZE_MAX_FILES:-$(git config --get mrSize.maxFiles || echo 20)}"
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo HEAD)"
  resolved="$(resolve_base "$branch")"
  base="${resolved%% *}"
  mb="${resolved#* }"
  rows="$(numstat "$mb" "$mode")"
  read -r files lines < <(awk -F'\t' 'NF { f++; if ($1 != "-") l += $1 + $2 } END { print f + 0, l + 0 }' <<<"$rows")
}

over() { [ "$lines" -gt "$max_lines" ] || [ "$files" -gt "$max_files" ]; }

exempt() {
  local def
  [ "$branch" = HEAD ] && return 0
  [ "$(git config --type=bool --get "branch.$branch.mrSizeOverride" 2>/dev/null)" = true ] && return 0
  def="$(default_branch)"
  # Work committed straight to the default branch opens no MR.
  [ "$branch" = "${def#origin/}" ]
}

summary() {
  echo "$branch vs $base: $lines lines in $files files (limit $max_lines lines / $max_files files; lockfiles and generated files not counted)"
}

largest() {
  awk -F'\t' 'NF && $1 != "-" { printf "%6d  %s\n", $1 + $2, $3 }' <<<"$rows" | sort -rn | head -n "${1:-10}"
}

split_advice() {
  cat <<EOF
Reviewers should get this as several MRs of at most $max_lines lines / $max_files files each, every one a coherent, reviewable step that builds and passes on its own.
Split it before going further:
  - independent pieces: one branch each off $base
  - dependent pieces: a stack, each branch off the previous one, and record the parent so each link is measured alone:
      git switch -c <next-branch> && git config branch.<next-branch>.mrBase <previous-branch>
  - move already-made commits with: git switch -c <part> <base> && git cherry-pick <commits>, or git rebase --onto
Largest changes:
$(largest 10)
If this genuinely cannot be split (a mechanical rename, a vendored drop), stop and ask the user. Only they set: git config branch.$branch.mrSizeOverride true
EOF
}

# The repository a hooked command acts on: a leading `cd <dir> &&` or a
# `git -C <dir>` moves it away from the session's cwd.
hook_dir() {
  local cmd="$1" cwd="$2" d
  d="$(sed -nE 's/^[[:space:]]*cd[[:space:]]+("([^"]+)"|([^[:space:];&|]+)).*/\2\3/p' <<<"$cmd")"
  [ -z "$d" ] && d="$(sed -nE 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|([^[:space:];&|]+)).*/\2\3/p' <<<"$cmd")"
  d="${d/#\~/$HOME}"
  case "$d" in
    '') echo "$cwd" ;;
    /*) echo "$d" ;;
    *) echo "$cwd/$d" ;;
  esac
}

git_re='(^|[;&|(][[:space:]]*|^[[:space:]]*)(rtk[[:space:]]+)?git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
mr_re='(glab[[:space:]]+mr[[:space:]]+create|gh[[:space:]]+pr[[:space:]]+create|df[[:space:]]+mr-generate)'

claude_pre() {
  local input cmd cwd mode
  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
  cwd="$(jq -r '.cwd // ""' <<<"$input")"
  if grep -Eq "$mr_re" <<<"$cmd" || grep -Eq "${git_re}push([[:space:]]|$)" <<<"$cmd"; then
    # Deleting a remote branch or pushing tags opens no MR.
    grep -Eq -- '--delete|--tags|[[:space:]]:[^[:space:]]' <<<"$cmd" && exit 0
    mode=range
  elif grep -Eq "${git_re}commit([[:space:]]|$)" <<<"$cmd"; then
    mode=staged
    # commit -a carries every tracked edit, not just the index.
    grep -Eq "${git_re}commit[^;&|]*[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)" <<<"$cmd" && mode=worktree
  else
    exit 0
  fi
  cd "$(hook_dir "$cmd" "$cwd")" 2>/dev/null || exit 0
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0
  measure "$mode"
  exempt && exit 0
  over || exit 0
  {
    echo "MR size gate: blocked. $(summary)."
    split_advice
  } >&2
  exit 2
}

# After an edit, or a commit, tell the agent the moment the work in progress
# outgrows one MR, and again only each time it grows past another multiple of
# the limit, so a long refactor is not nagged on every keystroke.
claude_post() {
  local input cwd tool cmd mode state band prev
  input="$(cat)"
  cwd="$(jq -r '.cwd // ""' <<<"$input")"
  tool="$(jq -r '.tool_name // ""' <<<"$input")"
  if [ "$tool" = Bash ]; then
    cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
    grep -Eq "${git_re}commit([[:space:]]|$)" <<<"$cmd" || exit 0
    cwd="$(hook_dir "$cmd" "$cwd")"
    mode=range
  else
    cwd="$(dirname "$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")")"
    mode=worktree
  fi
  cd "$cwd" 2>/dev/null || exit 0
  git rev-parse --git-dir >/dev/null 2>&1 || exit 0
  measure "$mode"
  exempt && exit 0
  state="$(git rev-parse --git-path mr-size-warned)"
  band=$((lines / max_lines))
  [ "$((files / max_files))" -gt "$band" ] && band=$((files / max_files))
  prev="$({ sed -n "s|^$branch ||p" "$state" 2>/dev/null || true; } | tail -n1)"
  { grep -v "^$branch " "$state" 2>/dev/null || true; echo "$branch $band"; } >"$state.tmp" && mv "$state.tmp" "$state"
  over || exit 0
  [ "$band" -gt "${prev:-0}" ] || exit 0
  jq -n --arg ctx "MR size gate: the work in progress is already more than one MR. $(summary). Commits and pushes on this branch will be blocked. $(split_advice)" \
    --arg ev "PostToolUse" '{hookSpecificOutput: {hookEventName: $ev, additionalContext: $ctx}}'
}

report() {
  measure range
  echo "committed:        $(summary)"
  measure worktree
  echo "with uncommitted: $(summary)"
  if over; then
    echo
    split_advice
  fi
}

case "${1:-report}" in
  report) report ;;
  check)
    measure "${2:-range}"
    exempt && exit 0
    summary
    over && exit 1
    exit 0
    ;;
  claude-pre) claude_pre ;;
  claude-post) claude_post ;;
  *)
    echo "usage: mr-size [report | check [range|staged|worktree] | claude-pre | claude-post]" >&2
    exit 64
    ;;
esac

# mr-review-lib: what mr-review and mr-review-github share, put before each of
# them when they are built: the colouring of a show answer, and the progress
# kept per request for every screen that reviews it (Herdr's MRs tab, the
# phone's page).

# One side of a diff as a file of its own: the old side is its context and
# removed lines, the new side its context and added lines, hunks run on.
side() {
  awk -v keep="$1" '/^@@/ { next } substr($0, 1, 1) == " " || substr($0, 1, 1) == keep { print substr($0, 2) }'
}

# bat colours a side with the terminal's own sixteen colours (theme ansi),
# so the tab can paint them in Herdr's theme. PHP is named outright: a hunk
# has no <?php for bat to switch PHP on from.
colour() {
  local path=$1
  case "$path" in
  *.php) bat --color=always --theme=ansi --style=plain --paging=never --tabs=0 -l "PHP Source" ;;
  *) bat --color=always --theme=ansi --style=plain --paging=never --tabs=0 --file-name="$path" ;;
  esac
}

# Adds hl_old and hl_new to each file of the show answer in $1: its sides'
# lines, coloured with ANSI escapes, in diff order. null when there is
# nothing worth colouring or bat fails; the tab then draws plain text.
highlight() {
  local out=$1 dir i=0 path diff
  dir=$(dirname "$out")
  while IFS= read -r -d '' path && IFS= read -r -d '' diff; do
    (
      if [ -n "$diff" ] && [ "${#diff}" -lt 400000 ] &&
        old=$(printf '%s\n' "$diff" | side - | colour "$path" 2>/dev/null) &&
        new=$(printf '%s\n' "$diff" | side + | colour "$path" 2>/dev/null); then
        jq -nc --arg old "$old" --arg new "$new" '{old: ($old | split("\n")), new: ($new | split("\n"))}'
      else
        echo '{"old": null, "new": null}'
      fi >"$dir/hl.$i"
    ) &
    i=$((i + 1))
  done < <(jq -j '.files[] | (.new_path // .old_path), "\u0000", (if .too_large or .generated then "" else .diff end), "\u0000"' "$out")
  wait
  for ((j = 0; j < i; j++)); do cat "$dir/hl.$j"; done >"$dir/hl"
  state_file . "$2"
  state >"$dir/state"
  jq -c --slurpfile hl "$dir/hl" --slurpfile st "$dir/state" \
    '.files |= [to_entries[] | .value + {hl_old: $hl[.key].old, hl_new: $hl[.key].new}] | .state = $st[0]' "$out"
}

# Progress on one request: the files marked read, each with a digest of its
# diff (a push that changes the file makes another), and the place, as the
# last screen left it. One file per request, under the repository's origin.
state_file() {
  local origin key
  origin=$(git -C "$1" remote get-url origin 2>/dev/null) || fail "no origin remote"
  key=$(printf '%s' "$origin" | sed -E 's#^[a-z+]+://##; s#^[^@]+@##; s#\.git$##; s#[^A-Za-z0-9._-]#_#g')
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mr-review/$key"
  mkdir -p "$state_dir"
  state_path="$state_dir/$2.json"
}

state() {
  if [ -f "$state_path" ]; then jq -c '{reads: (.reads // {}), pos: (.pos // null)}' "$state_path"
  else echo '{"reads":{},"pos":null}'; fi
}

# Rewrites the state with a jq filter, atomically, and prints it.
change_state() {
  local next
  next=$(state | jq -c "$@") || fail "bad state change"
  printf '%s\n' "$next" >"$state_path.$$" && mv "$state_path.$$" "$state_path"
  printf '%s\n' "$next"
}

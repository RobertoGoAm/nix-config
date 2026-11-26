#!/usr/bin/env bash
# Claude Code PostToolUse hook: after a Bash call that opened a pull or merge
# request, put it up for the owner to review, and tell the agent where the
# review lives. In the Herdr TUI it splits the agent's pane for tuicr; in Orca
# it opens a tuicr tab; in Herdr desktop it hands it to an MRs tab.
# Anywhere else, or when the command did not open a request, it does nothing.
set -u -o pipefail

PATH="@runtimePath@:$PATH"
ORCA_WRAPPER="@orcaWrapper@"
HERDR_BIN="${HERDR_BIN:-herdr}"

if [[ "${HERDR_ENV:-}" == "1" ]]; then
  host=herdr
elif [[ -n "${HC_TERMINAL_ID:-}" ]] && command -v hc >/dev/null; then
  host=herdr-app
elif [[ -n "${ORCA_AGENT_SESSION_ID:-}" ]]; then
  host=orca
else
  exit 0
fi

input="$(cat)"
command="$(jq -r '.tool_input.command // ""' <<<"$input")"
case "$command" in
  *"gh pr create"* | *"glab mr create"* | *"df mr-generate"*) ;;
  *) exit 0 ;;
esac

output="$(jq -r '.tool_response | if type == "object"
  then [.stdout, .stderr] | map(select(. != null)) | join("\n")
  else tostring end' <<<"$input")"
url="$(grep -oE 'https?://[^[:space:]"'\''<>()]+/(pull/[0-9]+|-/merge_requests/[0-9]+)' <<<"$output" | tail -1 || true)"
[[ -n "$url" ]] || exit 0

cwd="$(jq -r '.cwd // empty' <<<"$input")"
cwd="${cwd:-$PWD}"

context() {
  jq -n --arg text "$1" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $text}}'
}

read_back="When they say the review is done, find the session with \`tuicr review list --repo $cwd\` (kind \"pr\") and read their comments with \`tuicr review comments --session <slug>\`, as the tuicr skill describes."

# Splits the agent's own pane, or the focused one if Herdr does not know that
# id, and runs tuicr in the new pane without waiting for it. The pane's shell
# may not be bash, so tuicr runs under `bash -c` with a single-quoted script;
# the pane closes itself when tuicr exits cleanly.
open_in_herdr() {
  local split pane script
  split="$("$HERDR_BIN" pane split "${HERDR_PANE_ID:-}" --direction right --cwd "$cwd" --focus 2>/dev/null \
    || "$HERDR_BIN" pane split --current --direction right --cwd "$cwd" --focus)" || return 1
  pane="$(jq -er '.result.pane.pane_id' <<<"$split")" || return 1
  script="tuicr pr $(printf '%q' "$url")"
  "$HERDR_BIN" pane run "$pane" "bash -c '${script//\'/\'\\\'\'}' && exit" >/dev/null || return 1
  printf '%s' "$pane"
}

# The request's name for its tab and the agent's pill: "#123 Fix login" or
# "!45 Fix login".
review_title() {
  local t
  case "$url" in
    */pull/*)
      t="$(gh pr view "$url" --json number,title --jq 'select(.number != null) | "#\(.number) \(.title)"' 2>/dev/null)" ;;
    */-/merge_requests/*)
      t="$(glab mr view "${url##*/}" -R "${url%%/-/merge_requests/*}" -F json 2>/dev/null \
        | jq -r 'select(.iid != null) | "!\(.iid) \(.title)"' 2>/dev/null)" ;;
  esac
  if [[ -z "$t" ]]; then
    case "$url" in
      */pull/*) t="#${url##*/}" ;;
      *) t="!${url##*/}" ;;
    esac
  fi
  printf '%s' "${t:0:60}"
}

# The MRs tab for the request: the space's own when the request is on the
# space's repository (the first "MRs · " tab, whatever the requests mod named
# it), and otherwise "MRs · <repository>", with its own selection and progress
# (scope). It is opened in the background when the space has none. The agent's
# terminal is labelled first, so the new tab finds the request when it starts.
# With no Herdr window on this machine to ask, the window elsewhere that shows
# the space is trusted to have the tab, or the PR pill opens it.
open_in_mrs() {
  local me="$HC_TERMINAL_ID" info space repo layout home own tab name props title
  [[ "$url" == */-/merge_requests/* || "$url" == */pull/* ]] || return 1
  info="$(hc get "$me" --json)" || return 1
  space="$(jq -er '.labels["herdr.space"]' <<<"$info")" || return 1
  repo="$(mr-review where "$url" "$cwd" 2>/dev/null | jq -er '.dir')" || return 1
  layout="$(herdr-app ls 2>/dev/null)" || layout=""
  home="$(jq -r --arg s "$space" 'first(.. | objects | select(.tabs? and .id == $s) | .folder // empty) // empty' <<<"${layout:-null}")"
  home="${home:-$cwd}"
  home="$(git -C "$home" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$home")"
  own=false
  [[ "$repo" == "$home" ]] && own=true
  name="MRs · ${repo##*/}"
  title="$(review_title)"
  hc label "$me" "review.url=$url" "review.title=$title" "review.view=mrs" "review.at=$(date +%s)" \
    "review.folder=$([[ $own == true ]] || printf '%s' "$repo")" "review.terminal=" >/dev/null || return 1
  if [[ -z "$layout" ]]; then
    printf '%s\t%s' "$name" "$repo"
    return
  fi
  tab="$(jq -r --arg s "$space" --arg n "$name" --argjson own "$own" '
    [.. | objects | select(.tabs? and .id == $s) | .tabs[] | .name | select(startswith("MRs · "))] as $t
    | if ($t | index($n)) != null then $n elif $own and ($t | length) > 0 then $t[0] else "" end' <<<"$layout")"
  if [[ -z "$tab" ]]; then
    props="$(jq -cn --arg f "$repo" --arg s "$space" --argjson own "$own" \
      '{folder: $f, space: $s} + (if $own then {} else {scope: "\($s)|\($f)"} end)')"
    herdr-app do tab.new --space "$space" --name "$name" --mod mrs --props "$props" --focus false >/dev/null || return 1
    tab="$name"
  fi
  printf '%s\t%s' "$tab" "$repo"
}

case "$host" in
  herdr-app)
    if opened="$(open_in_mrs 2>/dev/null)"; then
      tab="${opened%%$'\t'*}"
      repo="${opened#*$'\t'}"
      context "$url is open for review in this space's \"$tab\" tab, where the user reviews merge and pull requests with nvim's keys inside Herdr. It was not shown, so their view did not move; do not open tuicr or anything else for it, and do not focus it. Tell the user it is ready: Cmd+Shift+R from your row, or the PR pill, which also shows its CI state, brings the tab up on it. Their comments are drafts (GitLab draft notes, or GitHub's pending review), which only they see until they publish them. When they say the review is done, read them with \`mr-review show $repo ${url##*/} | jq '{drafts, threads}'\`: each draft has its body, \`at\` (path, old_line and new_line; null for one on the whole request) and \`reply_to\`, the id of the thread in \`threads\` it answers. Publishing or dropping their drafts is theirs to do, not yours."
    else
      context "$url has no checkout on this machine in or beside $cwd, so it could not be put in an MRs tab for review. Tell the user the request is open at $url; do not open tuicr for it."
    fi
    ;;
  herdr)
    if pane="$(open_in_herdr 2>&1)"; then
      context "tuicr is now open on $url in Herdr pane $pane, beside this one, for the user to review; do not open another. $read_back Close the pane with \`herdr pane close $pane\` once it is no longer needed."
    else
      context "Opening tuicr on $url in a Herdr pane failed: $pane. Tell the user they can run \`tuicr pr $url\` themselves."
    fi
    ;;
  orca)
    if launched="$("$ORCA_WRAPPER" "$cwd" -- pr "$url" 2>&1)"; then
      handle="$(sed -n '/^=== TUICR TERMINAL ===$/{n;p;}' <<<"$launched")"
      context "tuicr is now open on $url in Orca terminal $handle, for the user to review; do not open another. $read_back Close the tab with \`orca terminal close --terminal $handle\` once it is no longer needed."
    else
      context "Opening tuicr on $url in an Orca tab failed: $launched. Tell the user they can run \`tuicr pr $url\` themselves."
    fi
    ;;
esac

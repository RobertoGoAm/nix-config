#!/usr/bin/env bash
# Claude Code PostToolUse hook: after a Bash call that opened a pull or merge
# request, open it in tuicr for the owner to review, and tell the agent where
# the review lives. In the Herdr TUI it splits the agent's pane; in Herdr
# desktop it opens a background tab in the agent's space; in Orca, a new tab.
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

# Herdr desktop: the review opens as a new tab in the agent's own space, named
# after the request ("#123 Fix login" or "!45 Fix login") so the picker finds
# it, in the background: the owner's view never moves. Where the app does not
# run on the agent's machine (an agent on another Mac), herdr-core starts it as
# a new tab of that space, which Herdr names on its own. The agent's terminal
# is labelled with the request's URL and the review's terminal, which the
# agents-plus mod reads to draw the PR pill with its CI state and to bring the
# review back.
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

open_in_herdr_app() {
  local me="$HC_TERMINAL_ID" info space run addr argv title
  info="$(hc get "$me" --json)" || return 1
  space="$(jq -er '.labels["herdr.space"]' <<<"$info")" || return 1
  title="$(review_title)"
  argv="$(jq -cn --arg url "$url" '["tuicr", "pr", $url]')"
  if command -v herdr-app >/dev/null \
    && run="$(herdr-app do tab.new --space "$space" --name "$title" --folder "$cwd" --argv "$argv" --focus false 2>/dev/null)" \
    && addr="$(jq -er '.terminal' <<<"$run")"; then
    :
  else
    run="$(hc run --bg --json --no-parent --no-notify --rm --cwd "$cwd" \
      --label "herdr.space=$space" --label "herdr.tab=tbreview$(date +%s)$RANDOM" -- tuicr pr "$url")" || return 1
    addr="$(jq -er '.address' <<<"$run")" || return 1
  fi
  hc label "$me" "review.url=$url" "review.terminal=$addr" "review.title=$title" >/dev/null || true
  printf '%s\t%s' "$addr" "$title"
}

case "$host" in
  herdr-app)
    if opened="$(open_in_herdr_app 2>&1)"; then
      term="${opened%%$'\t'*}"
      title="${opened#*$'\t'}"
      context "tuicr is now open on $url in a new Herdr tab named \"$title\" in this space (terminal $term), opened in the background so the user's view did not move; do not open another, and do not focus it. Tell the user it is ready: they reach it with Cmd+P by that title, Cmd+Shift+R from your row, or the PR pill, which also shows its CI state. $read_back The tab holds only that terminal, so \`hc kill $term\` closes it once it is no longer needed."
    else
      context "Opening tuicr on $url in a Herdr tab failed: $opened. Tell the user they can run \`tuicr pr $url\` themselves."
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

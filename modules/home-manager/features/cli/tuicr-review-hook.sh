#!/usr/bin/env bash
# Claude Code PostToolUse hook: after a Bash call that opened a pull or merge
# request, open it in tuicr beside the agent so the owner can review it, and
# tell the agent where the review lives. Inside a Herdr pane the review opens
# in a split of the agent's pane; inside Orca, in a new tab. Anywhere else, or
# when the command did not open a request, it does nothing.
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

# Herdr desktop: where the app runs on the agent's own machine, tuicr opens as a
# split to the right of the agent's pane. Elsewhere (an agent on another
# machine) a herdr-core terminal labelled with the agent's own space and tab
# shows up as a new pane in that tab.
# The agent's terminal is labelled with the request's URL and that pane, which
# the agents-plus mod reads to draw the PR pill with its CI state. Focusing the
# pane goes through the local app and quietly does nothing on another machine.
open_in_herdr_app() {
  local me="$HC_TERMINAL_ID" info space tab run addr argv
  argv="$(jq -cn --arg url "$url" '["tuicr", "pr", $url]')"
  if command -v herdr-app >/dev/null \
    && herdr-app do pane.focus --terminal "$me" >/dev/null 2>&1 \
    && run="$(herdr-app do terminal.open --argv "$argv" --folder "$cwd" --place right 2>/dev/null)" \
    && addr="$(jq -er '.terminal' <<<"$run")"; then
    hc label "$me" "review.url=$url" "review.terminal=$addr" >/dev/null || true
    printf '%s' "$addr"
    return 0
  fi
  info="$(hc get "$me" --json)" || return 1
  space="$(jq -er '.labels["herdr.space"]' <<<"$info")" || return 1
  tab="$(jq -er '.labels["herdr.tab"]' <<<"$info")" || return 1
  run="$(hc run --bg --json --no-parent --no-notify --rm --cwd "$cwd" \
    --label "herdr.space=$space" --label "herdr.tab=$tab" -- tuicr pr "$url")" || return 1
  addr="$(jq -er '.address' <<<"$run")" || return 1
  hc label "$me" "review.url=$url" "review.terminal=$addr" >/dev/null || true
  command -v herdr-app >/dev/null && herdr-app do pane.focus --terminal "$addr" >/dev/null 2>&1 || true
  printf '%s' "$addr"
}

case "$host" in
  herdr-app)
    if term="$(open_in_herdr_app 2>&1)"; then
      context "tuicr is now open on $url in Herdr terminal $term, a pane beside this one in the same tab, focused for the user to review; do not open another. The agents list shows this request's CI state beside your row. $read_back To bring the review back to the front later run \`herdr-app do pane.focus --terminal $term\`; if it was closed, \`herdr-app do terminal.open --argv '[\"tuicr\",\"pr\",\"$url\"]' --folder $cwd --place right\`. Close it with \`hc kill $term\` once it is no longer needed."
    else
      context "Opening tuicr on $url in a Herdr pane failed: $term. Tell the user they can run \`tuicr pr $url\` themselves."
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

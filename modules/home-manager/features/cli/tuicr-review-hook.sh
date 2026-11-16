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

case "$host" in
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

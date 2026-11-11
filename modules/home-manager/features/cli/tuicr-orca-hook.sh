#!/usr/bin/env bash
# Claude Code PostToolUse hook: after a Bash call that opened a pull or merge
# request, open it in tuicr in a new Orca tab so the owner can review it, and
# tell the agent where the review lives. Outside Orca, or when the command did
# not open a request, it does nothing.
set -u -o pipefail

PATH="@runtimePath@:$PATH"
WRAPPER="@wrapper@"

[[ -n "${ORCA_AGENT_SESSION_ID:-}" ]] || exit 0

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

if launched="$("$WRAPPER" "$cwd" -- pr "$url" 2>&1)"; then
  handle="$(sed -n '/^=== TUICR TERMINAL ===$/{n;p;}' <<<"$launched")"
  context "tuicr is now open on $url in Orca terminal $handle, for the user to review; do not open another. When they say the review is done, find the session with \`tuicr review list --repo $cwd\` (kind \"pr\") and read their comments with \`tuicr review comments --session <slug>\`, as the tuicr skill describes. Close the tab with \`orca terminal close --terminal $handle\` once it is no longer needed."
else
  context "Opening tuicr on $url in an Orca tab failed: $launched. Tell the user they can run \`tuicr pr $url\` themselves."
fi

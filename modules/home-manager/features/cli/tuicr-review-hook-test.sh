#!/usr/bin/env bash
# Runs the review hook against stand-in hc, herdr-app and gh for the Herdr
# desktop case, and fails when it stops opening a background tab named after
# the request in the agent's space, labelling the agent's terminal, or telling
# the agent about a tab; or when it starts moving the owner's view.
set -euo pipefail

hook="$1"
work="$(mktemp -d)"
stubs="$work/bin"
calls="$work/calls"
mkdir -p "$stubs"
: > "$calls"

stub() {
  { printf '#!%s\n' "$BASH"; cat; } > "$stubs/$1"
  chmod +x "$stubs/$1"
}

stub hc <<'EOF'
echo "hc $*" >> "$CALLS"
case "$1" in
  get) echo '{"labels":{"herdr.space":"sp-test","herdr.tab":"tb-agent"}}' ;;
esac
EOF

stub herdr-app <<'EOF'
echo "herdr-app $*" >> "$CALLS"
case "$1" in
  ls) [ -n "${NO_WINDOW:-}" ] && exit 1
      if [ -n "${NO_MRS:-}" ]; then echo '{"spaces":[{"id":"sp-test","tabs":[]}]}'
      else echo '{"spaces":[{"id":"sp-test","tabs":[{"id":"tb-mrs","name":"MRs · repo"}]}]}'; fi ;;
  *) echo '{"space":"sp-test","tab":"tb-review","terminal":"t9"}' ;;
esac
EOF

stub glab <<'EOF'
echo '{"iid":12,"title":"Fix the logout"}'
EOF

stub gh <<'EOF'
echo '#7 Fix the login'
EOF

input='{"tool_input":{"command":"gh pr create --fill"},"tool_response":{"stdout":"https://github.com/owner/repo/pull/7\n"},"cwd":"/tmp/repo"}'
out="$(NO_MRS=1 CALLS="$calls" HC_TERMINAL_ID=t1 PATH="$stubs:$PATH" bash "$hook" <<<"$input")"

fail() {
  echo "tuicr review hook test: $1" >&2
  echo "--- calls" >&2
  cat "$calls" >&2
  echo "--- output" >&2
  echo "$out" >&2
  exit 1
}

grep -qxF 'herdr-app do tab.new --space sp-test --name #7 Fix the login --folder /tmp/repo --argv ["tuicr","pr","https://github.com/owner/repo/pull/7"] --focus false' "$calls" \
  || fail "no background tab.new named after the request in the agent's space"
grep -qxF 'hc label t1 review.url=https://github.com/owner/repo/pull/7 review.terminal=t9 review.title=#7 Fix the login review.view=' "$calls" \
  || fail "the agent's terminal was not labelled with the request and its review"
if grep -qE 'pane\.focus|tab\.select|space\.select|agent\.focus' "$calls"; then
  fail "the hook moved the owner's view"
fi
jq -e '.hookSpecificOutput.additionalContext
  | test("new Herdr tab") and test("hc kill t9") and (test("pane") | not)' <<<"$out" >/dev/null \
  || fail "the context does not describe a tab and how to close it"
echo "tuicr review hook: Herdr desktop case passes"

: > "$calls"
input='{"tool_input":{"command":"glab mr create --fill"},"tool_response":{"stdout":"https://gitlab.example.com/group/repo/-/merge_requests/12\n"},"cwd":"/tmp/repo"}'
out="$(CALLS="$calls" HC_TERMINAL_ID=t1 PATH="$stubs:$PATH" bash "$hook" <<<"$input")"
grep -qE '^hc label t1 review\.url=https://gitlab\.example\.com/group/repo/-/merge_requests/12 review\.title=!12 Fix the logout review\.view=mrs review\.at=[0-9]+ review\.terminal=$' "$calls" \
  || fail "a merge request was not handed to the space's MRs tab through the agent's labels"
if grep -qE 'tab\.new|tuicr|pane\.focus|tab\.select|space\.select' "$calls"; then
  fail "a merge request with an MRs tab opened a tab or moved the owner's view"
fi
jq -e '.hookSpecificOutput.additionalContext
  | test("MRs · repo") and test("mr-review show /tmp/repo 12") and (test("tuicr pr") | not)' <<<"$out" >/dev/null \
  || fail "the context does not point the agent at the MRs tab and its drafts"
echo "tuicr review hook: merge request to the MRs tab passes"

: > "$calls"
input='{"tool_input":{"command":"gh pr create --fill"},"tool_response":{"stdout":"https://github.com/owner/repo/pull/7\n"},"cwd":"/tmp/repo"}'
out="$(NO_WINDOW=1 CALLS="$calls" HC_TERMINAL_ID=t1 PATH="$stubs:$PATH" bash "$hook" <<<"$input")"
grep -qE '^hc label t1 review\.url=https://github\.com/owner/repo/pull/7 review\.title=#7 Fix the login review\.view=mrs review\.at=[0-9]+ review\.terminal=$' "$calls" \
  || fail "a pull request on a machine with no window was not handed to the MRs tab"
if grep -qE 'tab\.new|tuicr' "$calls"; then
  fail "a pull request on a machine with no window opened tuicr"
fi
echo "tuicr review hook: pull request with no window here passes"

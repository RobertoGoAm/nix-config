#!/usr/bin/env bash
# Runs the review hook against stand-ins for the Herdr desktop case, and fails
# when a request opens tuicr or moves the owner's view, or is not handed to the
# right MRs tab, opened in the background when the space has none.
set -euo pipefail

hook="$1"
work="$(mktemp -d)"
stubs="$work/bin"
calls="$work/calls"
mkdir -p "$stubs"

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
      if [ -n "${NO_MRS:-}" ]; then echo '{"spaces":[{"id":"sp-test","folder":"/tmp/repo","tabs":[]}]}'
      else echo '{"spaces":[{"id":"sp-test","folder":"/tmp/repo","tabs":[{"id":"tb-mrs","name":"MRs · repo"}]}]}'; fi ;;
  *) echo '{"space":"sp-test","tab":"tb-new","pane":"p9"}' ;;
esac
EOF

stub mr-review <<'EOF'
echo "mr-review $*" >> "$CALLS"
[ "$1" = where ] || exit 1
[ -n "${NO_CHECKOUT:-}" ] && { echo '{"error":"no checkout"}'; exit 1; }
echo "{\"dir\":\"${WHERE:-/tmp/repo}\"}"
EOF

stub glab <<'EOF'
echo '{"iid":12,"title":"Fix the logout"}'
EOF

stub gh <<'EOF'
echo '#7 Fix the login'
EOF

mr='{"tool_input":{"command":"glab mr create --fill"},"tool_response":{"stdout":"https://gitlab.example.com/group/repo/-/merge_requests/12\n"},"cwd":"/tmp/repo"}'
pr='{"tool_input":{"command":"gh pr create --fill"},"tool_response":{"stdout":"https://github.com/owner/repo/pull/7\n"},"cwd":"/tmp/repo"}'
out=""

hook() {
  : > "$calls"
  out="$(env CALLS="$calls" HC_TERMINAL_ID=t1 PATH="$stubs:$PATH" "$@" bash "$hook" <<<"$input")"
}

fail() {
  echo "tuicr review hook test: $1" >&2
  echo "--- calls" >&2
  cat "$calls" >&2
  echo "--- output" >&2
  echo "$out" >&2
  exit 1
}

calm() {
  if grep -qE 'tuicr|pane\.focus|tab\.select|space\.select|agent\.focus' "$calls"; then
    fail "$1 opened tuicr or moved the owner's view"
  fi
}

input="$mr"
hook
grep -qE '^hc label t1 review\.url=https://gitlab\.example\.com/group/repo/-/merge_requests/12 review\.title=!12 Fix the logout review\.view=mrs review\.at=[0-9]+ review\.folder= review\.terminal=$' "$calls" \
  || fail "a merge request was not handed to the space's MRs tab through the agent's labels"
grep -q 'tab\.new' "$calls" && fail "a space with an MRs tab got another"
calm "a merge request with an MRs tab"
jq -e '.hookSpecificOutput.additionalContext
  | test("MRs · repo") and test("mr-review show /tmp/repo 12") and (test("tuicr pr") | not)' <<<"$out" >/dev/null \
  || fail "the context does not point the agent at the MRs tab and its drafts"
echo "tuicr review hook: merge request to the space's MRs tab passes"

input="$pr"
hook NO_MRS=1
grep -qxF 'herdr-app do tab.new --space sp-test --name MRs · repo --mod mrs --props {"folder":"/tmp/repo","space":"sp-test"} --focus false' "$calls" \
  || fail "a space with no MRs tab did not get one in the background"
calm "a pull request in a space with no MRs tab"
echo "tuicr review hook: an MRs tab for a space with none passes"

input="$mr"
hook WHERE=/tmp/pkg
grep -qE '^hc label t1 .* review\.folder=/tmp/pkg review\.terminal=$' "$calls" \
  || fail "a request on the repository beside the space's was not labelled with its checkout"
grep -qxF 'herdr-app do tab.new --space sp-test --name MRs · pkg --mod mrs --props {"folder":"/tmp/pkg","space":"sp-test","scope":"sp-test|/tmp/pkg"} --focus false' "$calls" \
  || fail "a request on the repository beside the space's did not get a tab of its own"
calm "a request on another repository"
jq -e '.hookSpecificOutput.additionalContext | test("MRs · pkg") and test("mr-review show /tmp/pkg 12")' <<<"$out" >/dev/null \
  || fail "the context does not point the agent at the other repository's tab"
echo "tuicr review hook: a request on the repository beside it passes"

input="$pr"
hook NO_WINDOW=1
grep -qE '^hc label t1 review\.url=https://github\.com/owner/repo/pull/7 review\.title=#7 Fix the login review\.view=mrs review\.at=[0-9]+ review\.folder= review\.terminal=$' "$calls" \
  || fail "a pull request on a machine with no window was not handed to the MRs tab"
grep -q 'tab\.new' "$calls" && fail "a machine with no window was asked for a tab"
calm "a pull request with no window here"
echo "tuicr review hook: pull request with no window here passes"

input="$mr"
hook NO_CHECKOUT=1
calm "a request with no checkout near the agent"
jq -e '.hookSpecificOutput.additionalContext | test("no checkout")' <<<"$out" >/dev/null \
  || fail "the agent was not told the request has no checkout here"
echo "tuicr review hook: a request with no checkout here passes"

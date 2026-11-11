#!/usr/bin/env bash
set -e -u -o pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_tuicr-common.sh"

PATH="@runtimePath@:$PATH"
ORCA_BIN="${ORCA_BIN:-orca}"
TUICR_TAB_TITLE="${TUICR_TAB_TITLE:-tuicr review}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [directory] [-- tuicr-args...]

Launch tuicr in a new Orca terminal tab of the worktree under review.

Returns as soon as the tab is running and prints its terminal handle between
=== TUICR TERMINAL === markers; close it with
\`orca terminal close --terminal <handle>\`. The tab closes itself when tuicr
exits cleanly and stays open, showing the error, when it does not.

Arguments:
  directory    Git or jj repository directory to review (default: current directory)
  tuicr-args   Arguments passed through to tuicr (e.g. -w, -r <revset>, pr <url>)

Environment variables:
  ORCA_BIN          Path to the orca executable (default: orca)
  TUICR_TAB_TITLE   Title of the new tab (default: tuicr review)
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
esac

if ! command -v "$ORCA_BIN" >/dev/null 2>&1; then
  echo "[tuicr] orca command not found on PATH" >&2
  exit 1
fi

tuicr_parse_args "$@"
dir="$(cd "$TUICR_TARGET_DIR" && pwd -P)"
command="cd $(printf '%q' "$dir") && tuicr$(tuicr_quote_args "${TUICR_PASSTHROUGH_ARGS[@]+"${TUICR_PASSTHROUGH_ARGS[@]}"}") && exit"

# The worktree is named by path; a directory Orca does not track falls back to
# whichever worktree this agent runs in, and the command cds to the right place.
create() {
  "$ORCA_BIN" terminal create --worktree "$1" --title "$TUICR_TAB_TITLE" \
    --command "$command" --focus --json 2>/dev/null
}
result="$(create "path:$dir" || create current || true)"
handle="$(jq -r '.result.terminal.handle // empty' <<<"$result" 2>/dev/null || true)"

if [[ -z "$handle" ]]; then
  echo "[tuicr] Orca could not open a terminal for $dir" >&2
  [[ -n "$result" ]] && echo "$result" >&2
  exit 1
fi

echo "[tuicr] tuicr is running in an Orca tab for $dir"
echo "=== TUICR TERMINAL ==="
echo "$handle"
echo "=== END TUICR TERMINAL ==="

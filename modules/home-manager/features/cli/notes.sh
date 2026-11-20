#!/usr/bin/env bash
# notes: a code folder's notes in the Obsidian vault.
#   notes dir [FOLDER]   the notes folder for FOLDER (default: here)
#   notes [FOLDER]       open nvim in it, made if missing
set -u -o pipefail

conf="${NOTES_CONFIG:-$HOME/.config/notes/config.json}"
[ -r "$conf" ] || {
  echo "notes: no config at $conf" >&2
  exit 1
}
vault="$(jq -r .vault "$conf")"
vault="$(cd "$vault" 2>/dev/null && pwd -P || printf '%s' "$vault")"

dir_for() {
  local f="$1" common root project area
  f="$(cd "$f" 2>/dev/null && pwd -P)" || f="$1"
  case "$f/" in
    "$vault"/*)
      if [[ "$f" =~ ^(.*/Projects/[^/]+/notes)(/|$) ]]; then
        echo "${BASH_REMATCH[1]}"
      else
        echo "$vault/Inbox"
      fi
      return
      ;;
  esac
  common="$(git -C "$f" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ]; then
    root="$(dirname "$common")"
  elif [ "$f" = "$HOME" ] || [ "$f" = / ]; then
    echo "$vault/Inbox"
    return
  else
    root="$f"
  fi
  project="$(basename "$root")"
  area="$(jq -r --arg f "$root" '(.areas // {}) | to_entries
    | map(select(.key as $p | $f == $p or ($f | startswith($p + "/"))))
    | sort_by(.key | length) | last | .value // empty' "$conf")"
  [ -n "$area" ] || area="$(jq -r '.default // "Personal"' "$conf")"
  echo "$vault/$area/Projects/$project/notes"
}

case "${1:-}" in
  dir) dir_for "${2:-$PWD}" ;;
  -h | --help)
    echo "notes dir [FOLDER] | notes [FOLDER]" >&2
    exit 2
    ;;
  *)
    d="$(dir_for "${1:-$PWD}")"
    mkdir -p "$d"
    cd "$d" || exit 1
    exec nvim .
    ;;
esac

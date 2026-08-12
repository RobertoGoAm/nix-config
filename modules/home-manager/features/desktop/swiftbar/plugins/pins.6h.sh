#!/bin/sh
# Version pins nothing updates automatically — the Chromium snapshot overlay and
# the pinned marketplace extensions. Silent when everything is current.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin"

out="$(check-pins "$HOME/nix-config" --quiet 2>/dev/null || true)"
n="$(printf '%s' "$out" | grep -c 'STALE' || true)"

if [ "${n:-0}" -eq 0 ]; then
  echo "pins ✓ | color=green"
  echo "---"
  echo "Nothing behind"
else
  echo "pins $n | color=orange"
  echo "---"
  printf '%s\n' "$out" | sed 's/^ *//'
  echo "---"
  echo "Update them | bash=/bin/sh param1=-c param2='cd ~/nix-config && nix run .#check-pins -- . --update' terminal=true"
fi

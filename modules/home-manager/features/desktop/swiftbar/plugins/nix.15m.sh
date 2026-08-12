#!/bin/sh
# State of the nix-config working tree: uncommitted changes and unpushed
# commits. Both are easy to accumulate and invisible until you go looking.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin"
repo="$HOME/nix-config"
[ -d "$repo/.git" ] || { echo "nix n/a"; exit 0; }

dirty="$(git -C "$repo" status --porcelain 2>/dev/null | grep -vc '^??' || true)"
ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"

if [ "${dirty:-0}" -eq 0 ] && [ "${ahead:-0}" -eq 0 ]; then
  echo "nix ✓ | color=green"
else
  echo "nix ${dirty}△ ${ahead}↑ | color=orange"
fi
echo "---"
echo "Uncommitted files: ${dirty:-0}"
echo "Unpushed commits: ${ahead:-0}"
echo "Generation: $(basename "$(readlink /nix/var/nix/profiles/system 2>/dev/null || echo unknown)")"
echo "---"
echo "Open repo | bash=/bin/sh param1=-c param2='cd ~/nix-config && git status' terminal=true"

#!/bin/sh
# Age of the newest restic snapshot. This is the plugin that earns the menu bar:
# a crashed run once left a stale lock and backups stopped for five days while
# nothing on screen changed.
#
# --no-lock is not optional. This runs every 5 minutes; a plain `snapshots` call
# takes a repository lock and would collide with the 30-minute backup.
#
# The age is computed in python, not `date`: this PATH prefers the nix profile,
# where `date` is GNU coreutils and has no BSD `-j`.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin"

conf="$HOME/.config/restic"
[ -r "$conf/repository" ] && [ -r "$conf/password" ] || { echo "backup n/a"; exit 0; }
RESTIC_REPOSITORY="$(cat "$conf/repository")"; export RESTIC_REPOSITORY
RESTIC_PASSWORD_FILE="$conf/password"; export RESTIC_PASSWORD_FILE

ts="$(restic snapshots --no-lock --latest 1 --json 2>/dev/null | jq -r '.[0].time // empty' 2>/dev/null || true)"

if [ -z "$ts" ]; then
  echo "backup ⚠ | color=red"
  echo "---"
  echo "Repository unreadable — vulcan down, off Tailscale, or locked"
  echo "Open log | bash=/bin/sh param1=-c param2='tail -40 ~/Library/Logs/restic-backup.out.log' terminal=true"
  exit 0
fi

read -r label color <<EOF
$(python3 - "$ts" <<'PY'
import datetime, sys
age = (datetime.datetime.now(datetime.timezone.utc)
       - datetime.datetime.fromisoformat(sys.argv[1])).total_seconds() / 60
if   age < 120:  print(f"{age:.0f}m green")
elif age < 720:  print(f"{age/60:.0f}h orange")
else:            print(f"{age/1440:.0f}d red")
PY
)
EOF

echo "backup $label | color=$color"
echo "---"
echo "Newest snapshot: $ts"
echo "Run one now | bash=/bin/launchctl param1=kickstart param2=-k param3=gui/$(id -u)/org.nix-community.home.restic-backup terminal=false refresh=true"
echo "Open log | bash=/bin/sh param1=-c param2='tail -40 ~/Library/Logs/restic-backup.out.log' terminal=true"

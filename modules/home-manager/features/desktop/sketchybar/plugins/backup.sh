#!/usr/bin/env bash
# Reads the SwiftBar collector's cache instead of querying restic itself, so
# only one thing ever talks to the repository.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
cache="${TMPDIR:-/tmp}/swiftbar-status/backup"
[ -r "$cache" ] || { sketchybar --set "$NAME" label="backup ?"; exit 0; }
ts="$(cat "$cache")"
[ -n "$ts" ] || { sketchybar --set "$NAME" label="backup ?"; exit 0; }
read -r label color <<< "$(python3 - "$ts" <<'PY'
import datetime, sys
try:
    age = (datetime.datetime.now(datetime.timezone.utc)
           - datetime.datetime.fromisoformat(sys.argv[1])).total_seconds() / 60
except Exception:
    print("? 0xfff7768e"); raise SystemExit
if   age < 120: print(f"{age:.0f}m 0xffc0caf5")
elif age < 720: print(f"{age/60:.0f}h 0xffe0af68")
else:           print(f"{age/1440:.0f}d 0xfff7768e")
PY
)"
sketchybar --set "$NAME" label="↑$label" label.color="$color"

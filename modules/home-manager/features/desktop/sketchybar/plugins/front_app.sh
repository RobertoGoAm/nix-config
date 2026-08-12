#!/usr/bin/env bash
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
# sketchybar passes the app name in $INFO for front_app_switched; on a plain
# refresh there is no event, so fall back to asking the system.
name="$INFO"
[ -n "$name" ] || name="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)"
sketchybar --set "$NAME" label="$name"

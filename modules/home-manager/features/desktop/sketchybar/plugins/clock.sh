#!/usr/bin/env bash
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"

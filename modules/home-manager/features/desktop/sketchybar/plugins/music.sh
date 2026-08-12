#!/usr/bin/env bash
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
running="$(osascript -e 'application "Spotify" is running' 2>/dev/null || echo false)"
if [ "$running" != "true" ]; then sketchybar --set "$NAME" drawing=off; exit 0; fi
state="$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)"
track="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null)"
artist="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null)"
if [ -z "$track" ]; then sketchybar --set "$NAME" drawing=off; exit 0; fi
icon="▶"; [ "$state" = "playing" ] || icon="❚❚"
sketchybar --set "$NAME" drawing=on label="$icon $artist — $track"

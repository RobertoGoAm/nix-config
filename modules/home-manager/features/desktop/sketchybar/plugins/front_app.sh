#!/usr/bin/env bash
# Focused app: its glyph from sketchybar-app-font plus a clean name.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"

name="$INFO"
# $INFO is only set by front_app_switched. On a plain refresh, and when it
# arrives as a bundle id rather than a display name, fall back to asking.
case "$name" in
  ""|*.*[!\ ]*.*) name="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)" ;;
esac
[ -n "$name" ] || exit 0

icon="$(icon_map.sh "$name" 2>/dev/null | tr -d '[:space:]')"
sketchybar --set "$NAME" label="$name" icon="${icon:-:default:}"

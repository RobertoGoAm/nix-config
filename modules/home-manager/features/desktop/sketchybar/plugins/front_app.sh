#!/usr/bin/env bash
# Focused app name plus its glyph from sketchybar-app-font, whose icon_map.sh
# does the name -> glyph lookup.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"

name="$INFO"
[ -n "$name" ] || name="$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null)"
[ -n "$name" ] || exit 0

icon=""
if command -v icon_map.sh >/dev/null 2>&1; then
  # icon_map.sh emits a ":appname:" ligature that the app font renders as a
  # glyph, with a trailing space that would sit oddly against the label.
  icon="$(icon_map.sh "$name" 2>/dev/null | tr -d "[:space:]")"
fi

sketchybar --set "$NAME" label="$name" icon="${icon:-}"

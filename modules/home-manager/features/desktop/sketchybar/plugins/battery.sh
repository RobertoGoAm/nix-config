#!/usr/bin/env bash
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
read -r pct state <<< "$(pmset -g batt | awk 'NR==2{gsub(/[;%]/,""); print $3, $4}')"
[ -n "$pct" ] || exit 0
# Nerd Font glyphs: macOS has no installable "SF Pro" family, so SF Symbols
# codepoints render as empty boxes. JetBrainsMono Nerd Font is installed.
icon="󰁹"; color=0xffc0caf5
[ "$state" = "charging" ] && icon="󰂄"
[ "${pct:-100}" -le 20 ] && [ "$state" != "charging" ] && color=0xfff7768e
sketchybar --set "$NAME" icon="$icon" icon.color=$color label="${pct}%"

#!/usr/bin/env bash
export PATH="/usr/bin:/bin:/usr/sbin"
read -r pct state <<< "$(pmset -g batt | awk 'NR==2{gsub(/[;%]/,""); print $3, $4}')"
[ -n "$pct" ] || exit 0
icon="󰁹"; color=0xffc0caf5
[ "$state" = "charging" ] && icon="󰂄"
[ "${pct:-100}" -le 20 ] && [ "$state" != "charging" ] && color=0xfff7768e
sketchybar --set "$NAME" icon="$icon" icon.color=$color label="${pct}%"

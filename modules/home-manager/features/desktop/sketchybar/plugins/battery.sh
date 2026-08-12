#!/usr/bin/env bash
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
read -r pct state <<< "$(pmset -g batt | awk 'NR==2{gsub(/[;%]/,""); print $3, $4}')"
[ -n "$pct" ] || exit 0
# SF Symbols, not Nerd Font: the bar's default icon font is SF Pro, and a Nerd
# Font codepoint renders there as a tofu box.
icon="􀛨"; color=0xffc0caf5
[ "$state" = "charging" ] && icon="􀢋"
[ "${pct:-100}" -le 20 ] && [ "$state" != "charging" ] && color=0xfff7768e
sketchybar --set "$NAME" icon="$icon" icon.color=$color label="${pct}%"

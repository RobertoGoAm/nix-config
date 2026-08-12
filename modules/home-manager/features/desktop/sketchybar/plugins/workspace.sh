#!/usr/bin/env bash
# Highlight the focused workspace. $1 is the workspace this item represents,
# passed in from sketchybarrc; $NAME is sketchybar's own item name.
export PATH="/run/current-system/sw/bin:/usr/bin:/bin"
focused="$(aerospace list-workspaces --focused 2>/dev/null | head -1)"
if [ "$1" = "$focused" ]; then
  sketchybar --set "$NAME" background.drawing=on label.color=0xff1a1b26
else
  sketchybar --set "$NAME" background.drawing=off label.color=0xff565f89
fi

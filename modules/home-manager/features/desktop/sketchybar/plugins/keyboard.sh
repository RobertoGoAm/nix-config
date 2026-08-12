#!/usr/bin/env bash
# Current keyboard layout. Colemak vs ABC is not something to discover by typing.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
id="$(defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>/dev/null)"
sketchybar --set "$NAME" label="${id##*.}"

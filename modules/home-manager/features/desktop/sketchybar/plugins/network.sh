#!/usr/bin/env bash
# Wi-Fi and tailnet in one item. Worth pairing: this machine resolves all DNS
# through the tailnet, so wifi being up says nothing on its own.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
ssid="$(ipconfig getsummary en0 2>/dev/null | awk -F' SSID : ' '/ SSID : /{print $2; exit}')"
ts="$(tailscale status --json 2>/dev/null | python3 -c "
import sys, json
try: print('up' if (json.load(sys.stdin).get('Self') or {}).get('Online') else 'down')
except Exception: print('down')
" 2>/dev/null)"

if [ -z "$ssid" ]; then
  sketchybar --set "$NAME" icon="􀙈" icon.color=0xfff7768e label="offline"
  exit 0
fi
if [ "$ts" = "up" ]; then
  sketchybar --set "$NAME" icon="􀙇" icon.color=0xff9ece6a label="$ssid"
else
  # Wi-Fi but no tailnet means no DNS on this machine, not merely no VPN.
  sketchybar --set "$NAME" icon="􀙇" icon.color=0xffe0af68 label="$ssid ⚠ts"
fi

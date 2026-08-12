#!/usr/bin/env bash
# RAM and CPU temperature, spaced so they read as two values rather than one
# run-on string. Same macmon source as the SwiftBar item, so they never differ.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
read -r label color <<< "$(macmon pipe --samples 1 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('— 0xff565f89'); raise SystemExit
gib = d['memory']['ram_usage'] / 2**30
total = d['memory']['ram_total'] / 2**30
temp = d['temp']['cpu_temp_avg']
hot = gib / total > 0.9 or temp > 90
print(f\"{gib:.1f}/{total:.0f}GB__{temp:.0f}°C {'0xfff7768e' if hot else '0xffc0caf5'}\")
")"
sketchybar --set "$NAME" label="${label//__/   }" label.color="$color"

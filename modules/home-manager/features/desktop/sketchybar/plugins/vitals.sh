#!/usr/bin/env bash
# RAM and CPU temperature from macmon, which reads Apple Silicon's counters
# without sudo. Same numbers as the SwiftBar item, so the two never disagree.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
read -r label color <<< "$(macmon pipe --samples 1 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('— 0xff565f89'); raise SystemExit
gib = d['memory']['ram_usage'] / 2**30
temp = d['temp']['cpu_temp_avg']
hot = gib / (d['memory']['ram_total'] / 2**30) > 0.9 or temp > 90
print(f\"{gib:.1f}G·{temp:.0f}° {'0xfff7768e' if hot else '0xffc0caf5'}\")
")"
sketchybar --set "$NAME" label="$label" label.color="$color"

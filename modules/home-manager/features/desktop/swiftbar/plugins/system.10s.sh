#!/bin/sh
# Caffeination and machine vitals. macmon reads Apple Silicon's own counters
# through IOReport, so CPU/GPU temperature and power need no sudo — powermetrics
# would have.
#
# The bar shows the two things worth glancing at (caffeinated, memory pressure);
# everything else lives in the dropdown so it costs no width.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/sbin:/usr/sbin:/usr/bin:/bin"

# Any process holding a display-sleep assertion counts as caffeinated — that
# catches `caffeinate`, Vorssaint's keep-awake, a call, or a screen share.
awake="$(pmset -g assertions 2>/dev/null | awk '/PreventUserIdleDisplaySleep/{print $2; exit}')"
holder="$(pmset -g assertions 2>/dev/null | awk -F'[()]' '/PreventUserIdleDisplaySleep.*named/{print $2; exit}')"

disk="$(df -h / 2>/dev/null | awk 'NR==2{print $4" free ("$5" used)"}')"
metrics="$(macmon pipe --samples 1 2>/dev/null || true)"

python3 - "${awake:-0}" "${holder:-}" "$disk" "$metrics" <<'PY'
import json, sys
awake, holder, disk, raw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
icon = "☕" if awake == "1" else "☾"

m = {}
try:
    m = json.loads(raw)
except Exception:
    pass

if m:
    mem = m["memory"]
    used_pct = mem["ram_usage"] / mem["ram_total"] * 100
    cpu_pct = (m["ecpu_usage"][1] + m["pcpu_usage"][1]) / 2 * 100
    temp = m["temp"]["cpu_temp_avg"]
    color = "red" if used_pct > 90 or temp > 90 else ("orange" if used_pct > 80 or temp > 80 else "")
    bar = f"{icon} {used_pct:.0f}% {temp:.0f}°"
    print(bar + (f" | color={color}" if color else ""))
    print("---")
    print(f"Awake: {'yes' + (f' — {holder}' if holder else '') if awake == '1' else 'no, display may sleep'}")
    print("---")
    print(f"CPU {cpu_pct:.0f}%   E {m['ecpu_usage'][1]*100:.0f}%   P {m['pcpu_usage'][1]*100:.0f}%   GPU {m['gpu_usage'][1]*100:.0f}%")
    print(f"CPU {m['temp']['cpu_temp_avg']:.0f}°C   GPU {m['temp']['gpu_temp_avg']:.0f}°C")
    print(f"RAM {mem['ram_usage']/2**30:.1f} / {mem['ram_total']/2**30:.0f} GiB   swap {mem['swap_usage']/2**30:.1f} GiB")
    print(f"Power {m['all_power']:.1f} W  (cpu {m['cpu_power']:.1f}  gpu {m['gpu_power']:.1f})")
else:
    print(f"{icon} —")
    print("---")
    print("macmon returned nothing")

print(f"Disk / {disk}")
print("---")
print("Keep awake 1h | bash=/usr/bin/caffeinate param1=-d param2=-t param3=3600 terminal=false")
print("Activity Monitor | bash=/usr/bin/open param1=-a param2='Activity Monitor' terminal=false")
PY

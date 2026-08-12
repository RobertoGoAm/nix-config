"""Render the SwiftBar status item from probe results passed in the environment.

Lines before the first `---` rotate in the menu bar, so vitals, health and the
current track share one slot. Everything else goes in the dropdown, grouped
into submenus with `--`.
"""

import datetime
import json
import os

env = os.environ.get


def num(name, default=0):
    try:
        return int(env(name) or default)
    except ValueError:
        return default


metrics = {}
try:
    metrics = json.loads(env("METRICS") or "")
except Exception:
    pass

tail = {}
try:
    tail = json.loads(env("TS_JSON") or "")
except Exception:
    pass

# ---- health ---------------------------------------------------------------
problems = []

backup_line, backup_age_h = "unknown", None
ts = env("BACKUP_TS", "").strip()
if ts and ts not in ("none", "n/a"):
    age = (datetime.datetime.now(datetime.timezone.utc)
           - datetime.datetime.fromisoformat(ts)).total_seconds()
    backup_age_h = age / 3600
    backup_line = (f"{age/60:.0f}m ago" if age < 7200
                   else f"{age/3600:.0f}h ago" if age < 86400
                   else f"{age/86400:.0f}d ago")
    if backup_age_h > 12:
        problems.append(f"backup {backup_line}")
else:
    problems.append("backup unreadable")

if env("NET_CODE") != "204":
    problems.append("no internet")
elif env("FILTERED") != "0.0.0.0":
    problems.append("DNS unfiltered")

online = (tail.get("Self") or {}).get("Online")
peers = list((tail.get("Peer") or {}).values())
if tail and not online:
    problems.append("tailscale offline")

pins_stale = num("PINS_STALE")
if pins_stale:
    problems.append(f"{pins_stale} pins stale")

# ---- rotating title lines -------------------------------------------------
if metrics:
    mem = metrics["memory"]
    used = mem["ram_usage"] / mem["ram_total"] * 100
    temp = metrics["temp"]["cpu_temp_avg"]
    icon = "☕" if env("AWAKE") == "1" else "☾"
    hot = used > 90 or temp > 90
    print(f"{icon} {used:.0f}% {temp:.0f}°" + (" | color=red" if hot else ""))

print(f"⚠ {problems[0]} | color=red" if problems else "✓ | color=green")

track, artist = env("SPOT_TRACK", ""), env("SPOT_ARTIST", "")
if track:
    icon = "▶" if env("SPOT_STATE") == "playing" else "❚❚"
    print(f"{icon} {artist} — {track} | length=40")

# ---- dropdown -------------------------------------------------------------
print("---")

if problems:
    for p in problems:
        print(f"⚠ {p} | color=red")
    print("---")

print(f"Backup {backup_line}")
print(f"--Run now | bash=/bin/launchctl param1=kickstart param2=-k param3=gui/{os.getuid()}/org.nix-community.home.restic-backup terminal=false refresh=true")
print("--Open log | bash=/bin/sh param1=-c param2='tail -40 ~/Library/Logs/restic-backup.out.log' terminal=true")

net_ok = env("NET_CODE") == "204"
print(f"Network {env('IFACE','?')} {'ok' if net_ok else 'DOWN'}")
print(f"--Probe: {env('NET_CODE') or 'timeout'}")
print(f"--DNS filter: {'active' if env('FILTERED') == '0.0.0.0' else 'NOT filtering'}")

if tail:
    up = sum(1 for p in peers if p.get("Online"))
    print(f"Tailnet {up} up")
    for p in sorted(peers, key=lambda p: p.get("HostName") or ""):
        mark = "●" if p.get("Online") else "○"
        print(f"--{mark} {p.get('HostName','?')}  {(p.get('TailscaleIPs') or ['?'])[0]}")

if metrics:
    mem = metrics["memory"]
    print("System")
    print(f"--Awake: {'yes — ' + env('HOLDER','') if env('AWAKE') == '1' else 'no'}")
    print(f"--CPU  E {metrics['ecpu_usage'][1]*100:.0f}%   P {metrics['pcpu_usage'][1]*100:.0f}%   GPU {metrics['gpu_usage'][1]*100:.0f}%")
    print(f"--Temp  CPU {metrics['temp']['cpu_temp_avg']:.0f}°C   GPU {metrics['temp']['gpu_temp_avg']:.0f}°C")
    print(f"--RAM  {mem['ram_usage']/2**30:.1f} / {mem['ram_total']/2**30:.0f} GiB   swap {mem['swap_usage']/2**30:.1f} GiB")
    print(f"--Power  {metrics['all_power']:.1f} W")
    print(f"--Disk  {env('DISK','?')}")
    print("--Keep awake 1h | bash=/usr/bin/caffeinate param1=-d param2=-t param3=3600 terminal=false")

dirty, ahead = num("DIRTY"), num("AHEAD")
print(f"nix-config {'clean' if not (dirty or ahead) else f'{dirty}△ {ahead}↑'}")
print(f"--Uncommitted: {dirty}    Unpushed: {ahead}")
print(f"--Pins stale: {pins_stale}")
print("--Update pins | bash=/bin/sh param1=-c param2='cd ~/nix-config && nix run .#check-pins -- . --update' terminal=true")

if track:
    print("---")
    print(f"{artist} — {track}")
    print("--Play/Pause | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to playpause' terminal=false refresh=true")
    print("--Next | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to next track' terminal=false refresh=true")
    print("--Previous | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to previous track' terminal=false refresh=true")

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

# Containers: exited ones are not a fault — one here has been down six weeks by
# choice — but an unhealthy one means a health check is actively failing.
containers = [l.split("\t") for l in (env("CONTAINERS") or "").splitlines() if "\t" in l]
running = [c[0] for c in containers if c[1] == "running"]
stopped = [c[0] for c in containers if c[1] != "running"]
unhealthy = (env("UNHEALTHY") or "").split()
if unhealthy:
    problems.append(f"unhealthy: {' '.join(unhealthy)}")

# vulcan reports "disk|..." and one "job|name|minutes" line per backup job.
vulcan_disk, vulcan_jobs = "", []
for line in (env("VULCAN") or "").splitlines():
    parts = line.split("|")
    if parts[0] == "disk" and len(parts) > 1:
        vulcan_disk = parts[1].strip()
    elif parts[0] == "job" and len(parts) > 2:
        vulcan_jobs.append((parts[1], int(parts[2])))
try:
    if vulcan_disk and int(vulcan_disk.split("%")[0]) > 90:
        problems.append(f"vulcan disk {vulcan_disk}")
except ValueError:
    pass

# ---- rotating title lines -------------------------------------------------
if metrics:
    mem = metrics["memory"]
    used_gib = mem["ram_usage"] / 2**30
    used_pct = mem["ram_usage"] / mem["ram_total"] * 100
    temp = metrics["temp"]["cpu_temp_avg"]
    icon = "☕" if env("AWAKE") == "1" else "☾"
    hot = used_pct > 90 or temp > 90
    # GiB rather than a bare percentage: "84%" gives no clue what it measures,
    # which was the same complaint as the unlabelled coffee cup.
    print(f"{icon} {used_gib:.1f}G {temp:.0f}°" + (" | color=red" if hot else ""))

# Only shown when something is wrong. A permanent green tick would eat a third
# of the rotation to say nothing, and a line that is always there stops being
# read — the appearance of this line is meant to be the signal.
if problems:
    print(f"⚠ {problems[0]} | color=red")

track, artist = env("SPOT_TRACK", ""), env("SPOT_ARTIST", "")
if track:
    icon = "▶" if env("SPOT_STATE") == "playing" else "❚❚"
    print(f"{icon} {artist} — {track} | length=40")

# Nothing above is guaranteed: with macmon unavailable, no problems and no
# music, the item would render blank and look broken.
if not metrics and not problems and not track:
    print("✓ | color=green")

# ---- dropdown -------------------------------------------------------------
print("---")

if problems:
    for p in problems:
        print(f"⚠ {p} | color=red")
    print("---")

print(f"Backup {backup_line} | bash=/bin/sh param1=-c param2='tail -40 ~/Library/Logs/restic-backup.out.log' terminal=true")
if vulcan_disk:
    print(f"--Target: vulcan {vulcan_disk}")
# Ages only, no verdict: a log's mtime says when the job last spoke, not
# whether it succeeded. Each job has its own healthchecks for that.
for name, mins in vulcan_jobs:
    age = f"{mins}m" if mins < 120 else f"{mins//60}h" if mins < 2880 else f"{mins//1440}d"
    print(f"--vulcan {name}: {age} ago")
print(f"--Run now | bash=/bin/launchctl param1=kickstart param2=-k param3=gui/{os.getuid()}/org.nix-community.home.restic-backup terminal=false refresh=true")
print("--Open log | bash=/bin/sh param1=-c param2='tail -40 ~/Library/Logs/restic-backup.out.log' terminal=true")

net_ok = env("NET_CODE") == "204"
print(f"Network {env('IFACE','?')} {'ok' if net_ok else 'DOWN'}")
if env("SSID"):
    print(f"--Network: {env('SSID')}")
print(f"--Probe: {env('NET_CODE') or 'timeout'}")
print(f"--DNS filter: {'active' if env('FILTERED') == '0.0.0.0' else 'NOT filtering'}")

if tail:
    up = sum(1 for p in peers if p.get("Online"))
    print(f"Tailnet {up} up")
    for p in sorted(peers, key=lambda p: p.get("HostName") or ""):
        mark = "●" if p.get("Online") else "○"
        print(f"--{mark} {p.get('HostName','?')}  {(p.get('TailscaleIPs') or ['?'])[0]}")

# Caffeination gets its own labelled row: the bar only has room for an icon,
# and an unlabelled icon is a guess.
if env("AWAKE") == "1":
    holder = env("HOLDER", "")
    print(f"☕ Display staying awake{f' — {holder}' if holder else ''}")
else:
    print("☾ Display will sleep normally")
print("--Keep awake 1 hour | bash=/usr/bin/caffeinate param1=-d param2=-t param3=3600 terminal=false")
print("--Keep awake 4 hours | bash=/usr/bin/caffeinate param1=-d param2=-t param3=14400 terminal=false")
print("--Stop keeping awake | bash=/usr/bin/pkill param1=-f param2=caffeinate terminal=false refresh=true")
print("--(only stops caffeinate — an app holding the assertion keeps it)")

if metrics:
    mem = metrics["memory"]
    print("System")
    print(f"--CPU  E {metrics['ecpu_usage'][1]*100:.0f}%   P {metrics['pcpu_usage'][1]*100:.0f}%   GPU {metrics['gpu_usage'][1]*100:.0f}%")
    print(f"--Temp  CPU {metrics['temp']['cpu_temp_avg']:.0f}°C   GPU {metrics['temp']['gpu_temp_avg']:.0f}°C")
    print(f"--RAM  {mem['ram_usage']/2**30:.1f} / {mem['ram_total']/2**30:.0f} GiB   swap {mem['swap_usage']/2**30:.1f} GiB")
    print(f"--Power  {metrics['all_power']:.1f} W")
    print(f"--Disk  {env('DISK','?')}")

if env("DOCKER_UP") != "1":
    print("Containers — OrbStack not running")
elif containers:
    print(f"Containers {len(running)} up" + (f", {len(stopped)} stopped" if stopped else ""))
    for name in running:
        print(f"--● {name}")
    for name in stopped:
        print(f"--○ {name}")

dirty, ahead = num("DIRTY"), num("AHEAD")
print(f"nix-config {'clean' if not (dirty or ahead) else f'{dirty}△ {ahead}↑'}")
print(f"--Uncommitted: {dirty}    Unpushed: {ahead}")
print(f"--Pins stale: {pins_stale}")
print("--Update pins | bash=/bin/sh param1=-c param2='cd ~/nix-config && nix run .#check-pins -- . --update' terminal=true")

if track:
    print("---")
    # The controls sit at top level rather than in a submenu: SwiftBar renders a
    # row with no action as disabled, so a submenu parent looks dead and buries
    # the one thing here you actually want to click.
    print(f"♫ {artist} — {track} | bash=/usr/bin/open param1=-a param2=Spotify terminal=false")
    print("Play/Pause | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to playpause' terminal=false refresh=true")
    print("Next | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to next track' terminal=false refresh=true")
    print("Previous | bash=/usr/bin/osascript param1=-e param2='tell application \"Spotify\" to previous track' terminal=false refresh=true")

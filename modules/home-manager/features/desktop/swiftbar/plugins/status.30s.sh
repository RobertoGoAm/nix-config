#!/bin/sh
# One menu bar item for everything. SwiftBar rotates through the lines before
# the first `---`, so vitals, health and the current track share a single slot
# instead of taking three.
#
# Cost matters at this cadence: the cheap probes run every time, the slow ones
# (restic over the network, check-pins' ~15 API calls) are cached and only
# refreshed at their own interval. Without that, a 30s plugin would hammer
# vulcan and the marketplace all day.
#
# PATH traps, both of which cost a rewrite: this profile's `date` and `stat` are
# GNU coreutils, not BSD, and `route` lives in /sbin.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"

CACHE="${TMPDIR:-/tmp}/swiftbar-status"; mkdir -p "$CACHE"

# cached <name> <max-age-seconds> <command...>
cached() {
  name="$1"; max="$2"; shift 2
  f="$CACHE/$name"
  stale=$(python3 -c "
import os,sys,time
p=sys.argv[1]
print(1 if not os.path.exists(p) or time.time()-os.path.getmtime(p) > float(sys.argv[2]) else 0)
" "$f" "$max")
  if [ "$stale" = "1" ]; then
    "$@" >"$f.tmp" 2>/dev/null && mv "$f.tmp" "$f" || : >"$f"
  fi
  cat "$f" 2>/dev/null || true
}

# ---- slow probes, cached -------------------------------------------------
backup_age() {
  conf="$HOME/.config/restic"
  [ -r "$conf/repository" ] && [ -r "$conf/password" ] || { echo "n/a"; return; }
  RESTIC_REPOSITORY="$(cat "$conf/repository")" RESTIC_PASSWORD_FILE="$conf/password" \
    restic snapshots --no-lock --latest 1 --json 2>/dev/null | jq -r '.[0].time // "none"'
}
pins_state() { check-pins "$HOME/nix-config" --quiet 2>/dev/null | grep -c STALE || echo 0; }
# Free space on the backup target. A full vulcan fails backups with a different
# error than a stale lock, and the health line would just call it "unreadable".
# One SSH round trip for everything vulcan knows: free space on the backup
# target, and how long ago each of its own backup jobs last wrote a log. Those
# jobs (Home Assistant, network config) have their own healthchecks but are
# otherwise invisible from this machine.
vulcan_state() {
  ssh -o BatchMode=yes -o ConnectTimeout=8 vulcan.tail5ec262.ts.net '
    df -h ~/Backups 2>/dev/null | tail -1 | awk "{print \"disk|\"\$5\" used, \"\$4\" free\"}"
    now=$(date +%s)
    for f in ~/Library/Logs/*backup*.out.log; do
      [ -e "$f" ] || continue
      printf "job|%s|%s\n" "$(basename "$f" .out.log)" "$(( (now - $(date -r "$f" +%s)) / 60 ))"
    done
  ' 2>/dev/null
}

BACKUP_TS="$(cached backup 300 backup_age)"
# 30 min, not 6 h: the pin count is cheap to compute (concurrent lookups,
# well under a second) and a long TTL made the panel contradict itself —
# it kept showing "1 pin stale" for hours after the pin had been bumped,
# with nothing on screen to say the number was old.
PINS_STALE="$(cached pins 1800 pins_state)"
VULCAN="$(cached vulcan 1800 vulcan_state)"

# ---- cheap probes, every run --------------------------------------------
IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' || true)"
# getairportnetwork reports "not associated" on an iPhone hotspot; getsummary
# still knows the SSID, and knowing which network you are on is the first
# question when the internet is missing.
SSID="$(ipconfig getsummary en0 2>/dev/null | awk -F' SSID : ' '/ SSID : /{print $2; exit}' || true)"
NET_CODE="$(curl -s -m 5 -o /dev/null -w '%{http_code}' https://connectivitycheck.gstatic.com/generate_204 2>/dev/null || true)"
FILTERED="$(dig +short +time=2 +tries=1 tunnel.ngrok.com 2>/dev/null | head -1 || true)"
TS_JSON="$(tailscale status --json 2>/dev/null || true)"
AWAKE="$(pmset -g assertions 2>/dev/null | awk '/PreventUserIdleDisplaySleep/{print $2; exit}')"
HOLDER="$(pmset -g assertions 2>/dev/null | awk -F'[()]' '/PreventUserIdleDisplaySleep.*named/{print $2; exit}')"
DISK="$(df -h / 2>/dev/null | awk 'NR==2{print $4" free, "$5" used"}')"
METRICS="$(macmon pipe --samples 1 2>/dev/null || true)"
# Containers: show what is up and what is not. Exited containers are not
# flagged — one here has been down six weeks on purpose — but an unhealthy one
# is unambiguous.
CONTAINERS="$(timeout 8 docker ps -a --format '{{.Names}}\t{{.State}}' 2>/dev/null || true)"
# Distinguish "no containers" from "could not ask": with OrbStack closed the
# section used to vanish silently, which reads exactly like everything is fine.
DOCKER_UP=$(timeout 8 docker info >/dev/null 2>&1 && echo 1 || echo 0)
UNHEALTHY="$(timeout 8 docker ps -a --filter health=unhealthy --format '{{.Names}}' 2>/dev/null | tr '\n' ' ' || true)"

# /bin/ps explicitly: this profile's ps is procps, whose flags differ. rss is
# KiB, pcpu is a percentage, and comm is a full path that contains spaces — so
# the renderer splits on the first two fields only.
#
# No head cap here. An earlier version took the first 400 lines, but ps orders
# by PID, so that dropped an arbitrary third of 630 processes and reported
# Chrome at 1.10G instead of 2.64G. Aggregating by app needs every process.
PS_DATA="$(/bin/ps -Ao rss=,pcpu=,comm= 2>/dev/null || true)"

REPO="$HOME/nix-config"
DIRTY="$(git -C "$REPO" status --porcelain 2>/dev/null | grep -vc '^??' || echo 0)"
AHEAD="$(git -C "$REPO" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"

SPOT_STATE=""; SPOT_TRACK=""; SPOT_ARTIST=""
if [ "$(osascript -e 'application "Spotify" is running' 2>/dev/null || echo false)" = "true" ]; then
  SPOT_STATE="$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null || true)"
  SPOT_TRACK="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null || true)"
  SPOT_ARTIST="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null || true)"
fi

export BACKUP_TS PINS_STALE VULCAN SSID PS_DATA CONTAINERS DOCKER_UP UNHEALTHY IFACE NET_CODE FILTERED TS_JSON AWAKE HOLDER DISK METRICS DIRTY AHEAD SPOT_STATE SPOT_TRACK SPOT_ARTIST
python3 "$HOME/.config/swiftbar/lib/status-render.py"

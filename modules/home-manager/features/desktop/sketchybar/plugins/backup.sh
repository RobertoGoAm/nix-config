#!/usr/bin/env bash
# Reads the SwiftBar collector's cache instead of querying restic itself, so
# only one thing ever talks to the repository.
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/bin:/bin"
cache="${TMPDIR:-/tmp}/swiftbar-status/backup"
[ -r "$cache" ] || { sketchybar --set "$NAME" label="backup ?"; exit 0; }
ts="$(cat "$cache")"
[ -n "$ts" ] || { sketchybar --set "$NAME" label="backup ?"; exit 0; }
read -r label color <<< "$(python3 - "$ts" <<'PY'
import datetime
import re, sys
def _parse(ts):
    # fromisoformat on Python 3.9 wants exactly 3 or 6 fractional digits and
    # no trailing Z; restic emits whatever precision it has. No apostrophes
    # in here: this heredoc sits inside a command substitution inside a
    # here-string, and bash still matches quotes through all three.
    # See status-render.py for the long version.
    ts = ts.strip()
    if ts[-1:] in ("Z", "z"):
        ts = ts[:-1] + "+00:00"
    m = re.match(r"^(.*\d{2}:\d{2}:\d{2})\.(\d+)(.*)$", ts)
    if m:
        ts = "{}.{}{}".format(m.group(1), (m.group(2) + "000000")[:6], m.group(3))
    return datetime.datetime.fromisoformat(ts)

try:
    age = (datetime.datetime.now(datetime.timezone.utc)
           - _parse(sys.argv[1])).total_seconds() / 60
except Exception:
    print("? 0xfff7768e"); raise SystemExit
if   age < 120: print(f"{age:.0f}m 0xffc0caf5")
elif age < 720: print(f"{age/60:.0f}h 0xffe0af68")
else:           print(f"{age/1440:.0f}d 0xfff7768e")
PY
)"
sketchybar --set "$NAME" label="↑$label" label.color="$color"

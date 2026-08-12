#!/bin/sh
# Tailnet state. Worth watching because this machine resolves *all* DNS through
# the tailnet: if tailscaled stops, name resolution stops with it, not just
# tailnet names.
set -eu
export PATH="/usr/local/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin"

json="$(tailscale status --json 2>/dev/null)" || json=""
[ -n "$json" ] || { echo "ts ⚠ | color=red"; echo "---"; echo "tailscaled not responding"; exit 0; }

python3 - "$json" <<'PY'
import json, sys
s = json.loads(sys.argv[1])
self_ = s.get("Self") or {}
online = self_.get("Online")
peers = (s.get("Peer") or {}).values()
up = sum(1 for p in peers if p.get("Online"))
exit_node = next((p.get("HostName") for p in peers if p.get("ExitNode")), None)

if not online:
    print("ts ⚠ offline | color=red")
else:
    print(f"ts {up}↑" + (f" via {exit_node}" if exit_node else "") + " | color=green")
print("---")
print(f"This node: {self_.get('HostName','?')}  {(self_.get('TailscaleIPs') or ['?'])[0]}")
cv, dv = s.get("Version",""), s.get("Version","")
for p in sorted(peers, key=lambda p: p.get("HostName") or ""):
    mark = "●" if p.get("Online") else "○"
    print(f"{mark} {p.get('HostName','?')}  {(p.get('TailscaleIPs') or ['?'])[0]}")
PY

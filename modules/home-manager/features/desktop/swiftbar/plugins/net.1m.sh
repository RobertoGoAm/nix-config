#!/bin/sh
# Internet reachability, which interface carries it, and whether vulcan's DNS
# filter is actually filtering. There is deliberately no fallback resolver on
# this machine, so "DNS works" and "the filter is up" are the same question.
set -eu
export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/sbin:/usr/sbin:/usr/bin:/bin"

iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
[ -n "$iface" ] || { echo "net ⚠ no route | color=red"; exit 0; }

code="$(curl -s -m 6 -o /dev/null -w '%{http_code}' https://connectivitycheck.gstatic.com/generate_204 2>/dev/null || true)"
# A domain vulcan sinkholes: 0.0.0.0 means the filter is answering.
filtered="$(dig +short +time=3 +tries=1 tunnel.ngrok.com 2>/dev/null | head -1)"

if [ "$code" != "204" ]; then
  echo "net ⚠ $iface | color=red"
elif [ "$filtered" = "0.0.0.0" ]; then
  echo "net $iface | color=green"
else
  echo "net $iface (unfiltered) | color=orange"
fi
echo "---"
echo "Default route: $iface"
echo "Connectivity probe: ${code:-timeout}"
echo "DNS filter: $([ "$filtered" = "0.0.0.0" ] && echo 'active' || echo "NOT filtering (got ${filtered:-nothing})")"

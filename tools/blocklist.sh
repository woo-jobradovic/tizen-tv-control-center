#!/bin/sh
# Builds a DNS blocklist for a Samsung TV from blocklist/samsung-tv.tsv. Runs on the PC, needs no TV and no root.
# Usage: tools/blocklist.sh FORMAT [EXTRA_GROUPS]
#   FORMAT        adguard  AdGuard Home, AdGuard DNS user rules (blocks subdomains too, adds allow rules)
#                 domains  one hostname per line: Pi-hole, NextDNS denylist, most routers
#                 hosts    0.0.0.0 lines for a hosts file or dnsmasq addn-hosts
#                 allow    the never-block list, one hostname per line
#   EXTRA_GROUPS  comma-separated optional groups on top of ads,telemetry,acr: voice,smartthings,tvplus,hdmi-id,apps
#                 (each one turns a feature off, see the table)
# Examples:
#   tools/blocklist.sh adguard > my-tv.txt
#   tools/blocklist.sh domains voice,tvplus
#   tools/blocklist.sh --all        rebuild the ready-made files in blocklist/
H="$(dirname "$0")"; T="$H/../blocklist/samsung-tv.tsv"
DEFAULT="ads,telemetry,acr"
OPTIONAL="voice,smartthings,tvplus,hdmi-id,apps"
URL="https://github.com/woo-jobradovic/tizen-tv-control-center"

if [ "$1" = "--all" ]; then
  for f in adguard domains hosts allow; do "$0" $f > "$H/../blocklist/samsung-tv-$f.txt" || exit 1; done
  exit 0
fi

case "$1" in
  adguard|domains|hosts|allow) ;;
  *) sed -n '2,13p' "$0" | cut -c3- >&2; exit 1 ;;
esac

EXTRA="$2"
for g in $(echo "$EXTRA" | tr ',' ' '); do
  case ",$OPTIONAL," in
    *",$g,"*) ;;
    *) echo "unknown group: $g (optional groups: $OPTIONAL)" >&2; exit 1 ;;
  esac
done
WANT="$DEFAULT${EXTRA:+,$EXTRA}"

awk -F '\t' -v fmt="$1" -v groups="$WANT" -v url="$URL" '
BEGIN {
  n = split(groups, g, ","); for (i = 1; i <= n; i++) want[g[i]] = 1
  c = (fmt == "adguard") ? "!" : "#"
  if (fmt == "allow") {
    print c " Samsung TV: hostnames to never block (Smart Hub, app store, account, time)"
  } else {
    print c " Samsung TV: ads, telemetry and ACR blocklist. Groups: " groups
  }
  print c " Built from one TV'"'"'s router log. Watch your own DNS log too."
  print c " " url
  print c
}
/^#/ || NF < 3 { next }
$1 == "keep" { keep[++k] = $2; next }
want[$1] && fmt != "allow" {
  if (fmt == "adguard") print "||" $2 "^"
  else if (fmt == "hosts") print "0.0.0.0 " $2
  else print $2
}
END {
  if (fmt == "allow") for (i = 1; i <= k; i++) print keep[i]
  if (fmt == "adguard") {
    print c; print c " Never block these, even if another list does:"
    for (i = 1; i <= k; i++) print "@@||" keep[i] "^"
  }
}' "$T"

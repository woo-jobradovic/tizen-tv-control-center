#!/bin/bash
# Pull a file from the TV: gzip + base64 on the TV, fetched in 100 KB chunks, md5-verified.
# (sdb pull is blocked on retail firmware.) Usage: pull.sh <remote-file> <local-file>
REMOTE="$1"; LOCAL="$2"
H="$(dirname "$0")"; . "$H/config.sh"
[ -n "$REMOTE" ] && [ -n "$LOCAL" ] || { echo "usage: pull.sh <remote-file> <local-file>"; exit 1; }
T=/opt/usr/apps/ClaudeTVCC0/data/.pull.b64
info=$("$H/tvcmd.sh" "gzip -c $REMOTE | base64 | tr -d '[:space:]' > $T; wc -c < $T; md5sum < $REMOTE" 60 | tr -d '\r ')
size=$(echo "$info" | sed -n 1p); sum=$(echo "$info" | grep -o '^[0-9a-f]\{32\}' | head -1)
[ -n "$size" ] || { echo "PULL_FAIL: no size"; exit 1; }
: > "$LOCAL.b64"
n=$(( (size + 99999) / 100000 ))
for i in $(seq 0 $((n-1))); do
  for try in 1 2 3; do
    chunk=$("$H/tvcmd.sh" "dd if=$T bs=100000 skip=$i count=1 2>/dev/null" 60 | tr -d '\r ')
    [ -n "$chunk" ] && break
    taskkill //F //IM sdb.exe >/dev/null 2>&1
    "$SDB" connect "$TV" >/dev/null 2>&1
  done
  printf '%s' "$chunk" >> "$LOCAL.b64"
done
base64 -d "$LOCAL.b64" | gunzip > "$LOCAL" && rm -f "$LOCAL.b64"
"$H/tvcmd.sh" "rm -f $T" 20 >/dev/null
got=$(md5sum < "$LOCAL" | cut -c1-32)
[ "$got" = "$sum" ] && echo PULL_OK || echo "PULL_FAIL: md5 $got != $sum"

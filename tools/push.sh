#!/bin/bash
# Push a local file to the TV: gzip + base64 in 20 KB chunks, md5-verified, atomic replace.
# Each chunk is size-checked on the TV; on mismatch or an SDB hang, SDB is reset and the chunk resent.
# Usage: push.sh <local-file> <remote-path> [mode]
LOCAL="$1"; REMOTE="$2"; MODE="${3:-755}"
[ -f "$LOCAL" ] && [ -n "$REMOTE" ] || { echo "usage: push.sh <local-file> <remote-path> [mode]"; exit 1; }

. "$(dirname "$0")/config.sh"
CHUNK=20000

tv() {
  MSYS_NO_PATHCONV=1 "$ROOT" --sdb "$SDB" archive-root root "$TV" --command "$1" --command-timeout 60 2>&1 \
    | sed -n '/^ *stdout: /,/^ *stderr:/p' | sed '$d' | sed 's/^ *stdout: //'
}

reset_sdb() {
  taskkill //F //IM sdb.exe >/dev/null 2>&1
  sleep 2
  ( "$SDB" connect "$TV" >/dev/null 2>&1 & )
  sleep 10
}

SUM=$(md5sum "$LOCAL" | cut -d' ' -f1)
B64=$(gzip -9c "$LOCAL" | base64 -w0)
TOTAL=${#B64}
N=$(( (TOTAL + CHUNK - 1) / CHUNK ))
echo "push $LOCAL -> $REMOTE ($(wc -c < "$LOCAL") bytes, $N chunk(s))"

for ((i = 0; i < N; i++)); do
  PART=${B64:$((i * CHUNK)):$CHUNK}
  WANT=$(( i * CHUNK + ${#PART} ))
  for try in 1 2 3; do
    # Rewrite the file up to this chunk's start so a half-applied retry can't duplicate data.
    if [ $i -eq 0 ]; then
      GOT=$(tv "printf '%s' '$PART' > /tmp/push.b64; wc -c < /tmp/push.b64")
    else
      GOT=$(tv "head -c $((i * CHUNK)) /tmp/push.b64 > /tmp/push.tmp && printf '%s' '$PART' >> /tmp/push.tmp && mv /tmp/push.tmp /tmp/push.b64; wc -c < /tmp/push.b64")
    fi
    [ "$(echo "$GOT" | tr -dc 0-9)" = "$WANT" ] && break
    echo "  chunk $((i + 1)) try $try failed (got '$GOT'), resetting SDB"
    reset_sdb
  done
  [ "$(echo "$GOT" | tr -dc 0-9)" = "$WANT" ] || { echo "PUSH_FAIL chunk $((i + 1))"; exit 1; }
  echo "  chunk $((i + 1))/$N ok"
done

OUT=$(tv "base64 -d /tmp/push.b64 | gunzip > '$REMOTE.new' && S=\$(md5sum '$REMOTE.new' | cut -d' ' -f1) && if [ \"\$S\" = '$SUM' ]; then mv '$REMOTE.new' '$REMOTE' && chmod $MODE '$REMOTE' && echo PUSH_OK; else rm -f '$REMOTE.new'; echo PUSH_BAD \$S; fi; rm -f /tmp/push.b64")
echo "$OUT"
case "$OUT" in *PUSH_OK*) exit 0 ;; *) exit 1 ;; esac

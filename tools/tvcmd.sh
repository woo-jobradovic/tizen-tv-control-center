#!/bin/bash
# Run one command as root on the TV and print its stdout.
# Usage: tvcmd.sh '<command>' [timeout-seconds]
. "$(dirname "$0")/config.sh"
MSYS_NO_PATHCONV=1 "$ROOT" --sdb "$SDB" archive-root root "$TV" --command "$1" --command-timeout "${2:-60}" 2>&1 \
  | sed -n '/^ *stdout: /,/^ *stderr:/p' | sed '$d' | sed 's/^ *stdout: //'

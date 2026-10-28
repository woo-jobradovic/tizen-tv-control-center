# Shared settings for the PC-side helpers (Git Bash on Windows, or bash on Linux/macOS).
# Edit these three lines, or export the variables before running a helper.
TV="${TV:-192.168.1.50}"                                   # your TV's IP address
ROOT="${ROOT:-./samsung-tv-root/samsung-tv-root.exe}"       # samsung-tv-root binary
SDB="${SDB:-./sdb/sdb.exe}"                                 # sdb from the Tizen SDK / Studio
# Git Bash: the helpers pass paths with MSYS path conversion off, so hand Windows tools Windows paths.
if command -v cygpath >/dev/null 2>&1; then ROOT=$(cygpath -w "$ROOT"); SDB=$(cygpath -w "$SDB"); fi

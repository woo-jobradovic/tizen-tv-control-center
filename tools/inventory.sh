#!/bin/bash
# Read-only compatibility check: changes nothing on the TV.
# Shows the firmware, and which of the app IDs, programs and units this repo touches exist on your model.
# Usage: tools/inventory.sh > my-tv.txt   (paste the summary into a compatibility report)
H="$(dirname "$0")"; R="$H/../tv/opt-etc"
APPS=$(grep -v '^#' "$R/cc-disabled-apps.txt" | tr '\n' ' ')
BINS=$(grep -o 'targets = "[^"]*"' "$R/parseinfo.sh" | head -3 | cut -d'"' -f2 | tr '\n' ' ')
UNITS=$(grep -o 'loop_units = "[^"]*"' "$R/parseinfo.sh" | cut -d'"' -f2)

"$H/tvcmd.sh" "
grep -E 'Build=|Model=' /etc/prd_info.ini | tr -cd '[:print:]' ; echo
head -1 /etc/tizen-release 2>/dev/null
echo; echo '== apps (present / disabled)'
for a in $APPS; do
  n=\$(sqlite3 /opt/dbspace/.pkgmgr_parser.db \"select app_disable from package_app_info where app_id='\$a'\" 2>/dev/null)
  echo \"\$a \${n:-MISSING}\"
done
echo; echo '== programs to block'
for b in $BINS; do for d in /usr/bin /usr/sbin; do [ -f \$d/\$b ] && echo \"\$d/\$b present\"; done; done
for p in /usr/apps/org.tizen.registerav/bin/registerav /usr/apps/org.tizen.registertv/bin/registertv /usr/apps/org.tizen.welcome-mode/bin/welcome-mode /usr/apps/org.tizen.bleapp/bin/bleapp /usr/apps/com.samsung.tv.cis-api-service-app/bin/cis-api-service-app /usr/apps/screen_sharing/bin/screen_sharing; do [ -f \$p ] && echo \"\$p present\"; done
echo; echo '== restart-loop units'
for u in $UNITS; do echo \"\$u \$(systemctl show -p LoadState \$u.service | cut -d= -f2)\"; done
echo; echo '== picture processing available (expect int32 1)'
dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc org.tizen.tv.avoc.AvOutputControl.CheckAutoMotionPlus 2>&1 | tail -1
echo; echo '== key input devices'
grep -E 'Name=' /proc/bus/input/devices | tr -cd '[:print:]' ; echo
" 120

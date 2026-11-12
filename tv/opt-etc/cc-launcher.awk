#!/usr/bin/awk -f
BEGIN {
  w = "/home/owner/apps_rw/xwalk-service/data/cc_launch"
  l = "/opt/usr/apps/ClaudeTVCC0/data/cc_launcher.log"
  of = "/home/owner/apps_rw/xwalk-service/data/cc_orders.json"
  af = "/home/owner/apps_rw/xwalk-service/data/cc_appliances.json"
  # Optional feeds for the notification banners (docs/05-notifications.md); empty = off.
  # oapi returns the latest order {id,name,total,items}; aapi returns appliances [{type,state}].
  oapi = ""   # e.g. "https://example.com/api/latest-order"
  aapi = ""   # e.g. "https://example.com/api/appliances"
  # AVOC "new_home" flag: Samsung Home sets it while its UI shows, which greys out
  # Picture Clarity / Picture Mode. Nothing clears it with Control Center as home.
  newhome = "dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc org.tizen.tv.avoc.AvOutputControl.SetNewHome int32:0 >/dev/null 2>&1"
  # Boot: AMD can launch home before the CC SMACK rules are loaded, so the first
  # launch fails. Check once, 20 s after daemon start, and launch CC if missing.
  ccstart = "ps -eo args | grep -q '[C]laudeTVCC0/bin' || app_launcher -s ClaudeTVCC0.ControlCenter >/dev/null 2>&1 &"
  bc = 40
  # Log rotation for the CC daemon logs (not cc_orders.log): over 100 KB keep the last 50 KB.
  rot = "cd /opt/usr/apps/ClaudeTVCC0/data && for f in cc_launcher.log cc_keymon.log cc_backmon.log cc_homekey.log; do [ -f $f ] && [ $(wc -c < $f) -gt 102400 ] && tail -c 51200 $f > $f.tmp && mv $f.tmp $f; done"
  rc = 0
  # v10: Samsung's app auto-update reinstalls a package and clears its "disabled" flag (12-Nov: 3 of
  # the 41 were back, 2 of them running). Every ~10 min, disable again any app from the list that
  # isn't disabled. First check 1 min after start. From a systemd unit pkgcmd needs --global
  # (without it the call says "ok" and changes nothing); from the root shell it is the other way round.
  db = "/opt/dbspace/.pkgmgr_parser.db"
  guard = "sqlite3 " db " \"select app_id from package_app_info where app_disable<>'true'\" 2>/dev/null | grep -xFf /opt/etc/cc-disabled-apps.txt | while read a; do pkgcmd -D -t app -n $a --global >/dev/null 2>&1; sleep 1; echo \"re-disable $a: disabled=$(sqlite3 " db " \"select app_disable from package_app_info where app_id='$a'\") $(date)\" >> " l "; done"
  dc = 1080
  oc = 119
  nc = 59
  print "daemon v10+orders+appliances+newhome+bootcc+logrotate+launchcheck+debloatguard started " strftime() > l; close(l)
  while (1) {
    if ((getline line < w) > 0) {
      close(w)
      system("rm -f " w)
      # v10: the line is run by a root shell and any app can write this file, so only an app id
      # plus plain app-control words (letters, digits, . _ = , : -; no leading dash) is accepted.
      if (line ~ /^[A-Za-z0-9][A-Za-z0-9._-]*( [A-Za-z0-9][A-Za-z0-9._=,:-]*)*$/) {
        print "launching " line " " strftime() >> l; close(l)
        system("app_launcher -s " line " >> " l " 2>&1 &")
      } else {
        print "rejected launch request (" length(line) " chars) " strftime() >> l; close(l)
      }
    } else {
      close(w)
    }
    if (++oc >= 120) {
      oc = 0
      if (oapi != "") system("curl -sk -o " of " " oapi " 2>/dev/null")
      if (aapi != "") system("curl -sk -o " af " " aapi " 2>/dev/null")
      print "polled " strftime() >> l; close(l)
    }
    if (bc > 0 && --bc == 0) {
      system(ccstart)
      print "boot CC check " strftime() >> l; close(l)
    }
    if (++nc >= 60) {
      nc = 0
      system(newhome)
    }
    if (++rc >= 1200) {
      rc = 0
      system(rot)
    }
    if (++dc >= 1200) {
      dc = 0
      system(guard)
    }
    system("sleep 0.5")
  }
}

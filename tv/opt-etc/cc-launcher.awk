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
  oc = 119
  nc = 59
  print "daemon v8+orders+appliances+newhome+bootcc+logrotate started " strftime() > l; close(l)
  while (1) {
    if ((getline line < w) > 0) {
      close(w)
      system("rm -f " w)
      print "launching " line " " strftime() >> l; close(l)
      system("app_launcher -s " line " >> " l " 2>&1 &")
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
    system("sleep 0.5")
  }
}

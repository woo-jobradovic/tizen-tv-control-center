#!/usr/bin/awk -f
# cc-backmon.awk v6 — Back-to-CC monitor
# Monitors dbus for user app terminations and launches CC (back-to-home).
# v5: TV Plus -> HBO redirect removed (TV Plus disabled; cc-keymon handles Sweet TV);
#     systime() instead of forking date.
# v6: a listed app can also end in the background (12-Nov: the app store updated Apple TV while
#     YouTube was playing) and v5 then put the CC over the app being watched. Now, 2 s after the
#     exit, the CC is launched unless another app that is still running holds the screen.
# GNU Awk 3.1.5 compatible.
BEGIN {
    CC = "ClaudeTVCC0.ControlCenter"
    LOG = "/opt/usr/apps/ClaudeTVCC0/data/cc_backmon.log"
    # $f = app on screen. Empty or the CC itself: launch the CC as before. Another app: launch the
    # CC only if that app is no longer running.
    BACK = "(sleep 2; f=$(vconftool get memory/appfw/current_fullscreen_appid 2>/dev/null | sed -e 's/.*value = //' -e 's/ (String).*//');" \
           " case \"$f\" in \"\"|ClaudeTVCC0*) ;; *) if app_launcher -S 2>/dev/null | grep -qF \"$f (\"; then" \
           " echo \"$(date +%s) no CC: $f is on screen\" >> " LOG "; exit 0; fi ;; esac;" \
           " app_launcher -s " CC " >/dev/null 2>&1; echo \"$(date +%s) CC launched\" >> " LOG ") &"
    last_launch = 0
    got_terminate = 0

    print "cc-backmon v6 started" > LOG
    close(LOG)

    cmd = "dbus-monitor --system \"type=signal,interface=org.tizen.aul.AppStatus,member=AppTerminate\" 2>/dev/null"
    while ((cmd | getline line) > 0) {
        # match AppTerminate at end of line (not AppTerminated)
        if (line ~ /member=AppTerminate$/) {
            got_terminate = 1
        }
        if (got_terminate && line ~ /string "/) {
            got_terminate = 0
            if (line ~ /netflix/ || line ~ /primevideo/ || line ~ /DisneyPlus/ || \
                line ~ /TizenYouTube/ || line ~ /Stremio/ || line ~ /BeamCTV/ || \
                line ~ /aria-video/ || line ~ /tizen.menu/ || \
                line ~ /coba.setting/ || line ~ /cobalt-yt/ || \
                line ~ /volt.apps/) {
                now = systime()
                if (now - last_launch >= 5) {
                    print now " user app exit: " line >> LOG
                    close(LOG)
                    system(BACK)
                    last_launch = now
                }
            }
        }
    }
}

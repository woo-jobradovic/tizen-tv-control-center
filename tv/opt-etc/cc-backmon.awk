#!/usr/bin/awk -f
# cc-backmon.awk v5 — Back-to-CC monitor
# Monitors dbus for user app terminations and launches CC (back-to-home).
# v5: TV Plus -> HBO redirect removed (TV Plus disabled; cc-keymon handles Sweet TV);
#     systime() instead of forking date.
# GNU Awk 3.1.5 compatible.
BEGIN {
    CC = "ClaudeTVCC0.ControlCenter"
    LOG = "/opt/usr/apps/ClaudeTVCC0/data/cc_backmon.log"
    last_launch = 0
    got_terminate = 0

    print "cc-backmon v5 started" > LOG
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
                    system("sleep 2 && app_launcher -s " CC " >/dev/null 2>&1 &")
                    last_launch = now
                    print now " CC launched after user app exit: " line >> LOG
                    close(LOG)
                }
            }
        }
    }
}

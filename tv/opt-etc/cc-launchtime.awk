#!/usr/bin/awk -f
# Times how long an app takes to come on screen: from the launch request until the TV reports it as the
# full-screen app (memory/appfw/current_fullscreen_appid). Resolution ~10 ms (/proc/uptime) plus the poll.
# Usage: awk -v FROM=<appid shown first> -v TO=<appid to time> -v N=3 [-v COLD=1] -f cc-launchtime.awk
#   COLD=1 terminates TO first, so it starts from scratch instead of from memory.
#   For the Control Center it also reports "drawn": until the page has painted its first frame on screen
#   (the page writes the time to cc_painted).
BEGIN {
    if (N == "") N = 3
    PAINT = "/home/owner/apps_rw/xwalk-service/data/cc_painted"
    for (i = 1; i <= N; i++) {
        show(FROM, 30, TO)
        system("sleep 3")
        if (COLD) { system("app_launcher -t " TO " >/dev/null 2>&1"); system("sleep 2") }
        ms0 = ms()
        t = show(TO, 30)
        printf "run %d %s %s: on top %s s", i, (COLD ? "cold" : "warm"), TO, (t < 0 ? "timeout" : sprintf("%.2f", t))
        if (TO ~ /ClaudeTVCC0/) printf ", drawn %s s", drawn(ms0)
        printf "\n"
    }
}
# Launches app and returns seconds until it is the full-screen app (-1 on timeout). With away set, it waits
# until the screen shows anything other than away (some apps report a different id on screen, e.g. YouTube).
function show(app, limit, away,    t0, t, f) {
    t0 = now()
    system("app_launcher -s " app " >/dev/null 2>&1 &")
    while ((t = now() - t0) < limit) {
        f = fg()
        if (away != "" ? (f != "" && f != away) : f == app) return t
    }
    return -1
}
# Seconds from ms0 until the page reports a frame drawn after it (waits up to 10 s).
function drawn(ms0,    p, k) {
    for (k = 0; k < 100; k++) {
        p = ""; getline p < PAINT; close(PAINT)
        if (p + 0 > ms0) return sprintf("%.2f", (p - ms0) / 1000)
        system("sleep 0.1")
    }
    return "timeout"
}
function ms(    c, v) {
    c = "date +%s%N"; c | getline v; close(c)
    return int(substr(v, 1, length(v) - 6))
}
function fg(    c, v) {
    c = "vconftool get memory/appfw/current_fullscreen_appid 2>/dev/null"
    c | getline v; close(c)
    sub(/.*value = /, "", v); sub(/ \(String\)$/, "", v)
    return v
}
function now(    f, l, a) {
    f = "/proc/uptime"; getline l < f; close(f)
    split(l, a, " "); return a[1] + 0
}

#!/usr/bin/awk -f
# cc-notifywake.awk v4 - native Samsung notifications for the Control Center while another app
# is on screen.
# The TV suspends the CC page's JavaScript while another app is in front; a launch request
# with __K_BG_LAUNCH resumes it for ~1 min without raising its window (the app on screen stays).
# Watches cc_orders.json / cc_appliances.json (written by cc-launcher) and cc_push
# ("title|message" lines any root daemon can append) and wakes the page when they change.
# Read-only on the first two.
# v2: a background-woken page still reports document.hidden = false, so the app on screen is
# written to cc_fg for the page to decide between its own banner and a native notification.
# v3: the TV's web runtime has no tizen.notification, so the page appends "title|message" lines
# to cc_native and this daemon posts them: add_noti on data-provider-master over D-Bus (as the CC
# app's SMACK label, which holds the notification privilege), then launches Samsung's default
# viewer (com.samsung.tv.notification-app) with the new id, which shows the banner over any app.
# v4: lines carry an icon name ("title|message|icon"); icon PNGs in shared/res replace the 9-patch
# background image v3 sent as the sub-icon, which Samsung drew as an empty box.
# Run with LC_ALL=C so length() counts bytes. GNU Awk 3.1.5 compatible. UEP bypass via awk shebang.
BEGIN {
    D = "/home/owner/apps_rw/xwalk-service/data/"
    FGF = D "cc_fg"
    NAT = D "cc_native"
    LOG = "/opt/usr/apps/ClaudeTVCC0/data/cc_notifywake.log"
    FG = "vconftool get memory/appfw/current_fullscreen_appid 2>/dev/null"
    WAKE = "launch_app ClaudeTVCC0.ControlCenter __K_BG_LAUNCH enable >/dev/null 2>&1"
    ROT = "tail -c 20000 " LOG " > " LOG ".tmp && mv " LOG ".tmp " LOG
    RAW = "/tmp/cc-noti.raw"
    GV = "/tmp/cc-noti.gv"
    POST = "sh -c 'echo User::Pkg::ClaudeTVCC0 > /proc/self/attr/current && exec gdbus call --system" \
           " --dest org.tizen.data_provider_service --object-path /org/tizen/data_provider_service" \
           " --method org.tizen.data_provider_noti_service.add_noti \"$(cat " GV ")\"' 2>&1"
    # Icons in the CC style (white glyph on a soft circle), labelled "_" so Samsung's viewer can read them.
    ICONS = "/opt/usr/apps/ClaudeTVCC0/shared/res/cc-"

    # Created once with the page's owner and label; later writes keep both.
    system("touch " FGF "; chown 5001:5001 " FGF "; chmod 644 " FGF "; chsmack -a User::Pkg::ClaudeTVCC0 " FGF)
    print "cc-notifywake v4 started " strftime() > LOG
    close(LOG)

    last_data = slurp("cc_orders.json") "|" slurp("cc_appliances.json")
    last_push = slurp("cc_push")
    last_fg = "?"
    wakes = 0
    while (1) {
        system("sleep 2")
        fg = ""
        FG | getline fg
        close(FG)
        sub(/.*value = /, "", fg)
        sub(/ \(String\)$/, "", fg)
        if (fg != last_fg) {
            printf "%s", fg > FGF
            close(FGF)
            last_fg = fg
        }
        if (slurp("cc_native") != "") post_pending()
        data = slurp("cc_orders.json") "|" slurp("cc_appliances.json")
        push = slurp("cc_push")
        # cc_push is cleared by the page after reading; only new non-empty content counts.
        if (data == last_data && (push == "" || push == last_push)) {
            last_push = push
            continue
        }
        last_data = data
        last_push = push
        if (fg ~ /ClaudeTVCC0/) continue
        system(WAKE)
        print strftime() " wake (" fg ")" >> LOG
        close(LOG)
        if (++wakes % 500 == 0) system(ROT)
    }
}

function slurp(name,    s, line, f) {
    s = ""
    f = D name
    while ((getline line < f) > 0) s = s line "\n"
    close(f)
    return s
}

# Moved aside first so lines the page appends meanwhile land in a fresh cc_native.
# Lines are "title|message|icon"; icon (order, washer, dishwasher, bell) is optional.
function post_pending(    work, line, n, f) {
    work = NAT ".work"
    system("mv " NAT " " work)
    while ((getline line < work) > 0) {
        if (line == "") continue
        n = split(line, f, "|")
        if (n == 1) post("Control Center", f[1], "bell")
        else post(f[1], f[2], f[3])
    }
    close(work)
    system("rm -f " work)
}

function post(title, msg, icon,    now, text, img, out, id, cmd) {
    now = systime()
    if (icon !~ /^(order|washer|dishwasher|bell)$/) icon = "bell"
    text = bundle("0", title, "1", msg)
    img = bundle("0", ICONS icon ".png", "", "")
    printf "<{1: <0>, 2: <1>, 3: <-1>, 4: <0>, 5: <0>, 6: <'ClaudeTVCC0'>, 7: <'ClaudeTVCC0.ControlCenter'>, " \
           "30: <'%s'>, 34: <'%s'>, 36: <-1>, 39: <-1>, 42: <-1>, 46: <%d>, 47: <%d>, 49: <17>, " \
           "53: <'Control Center'>, 57: <0>, 58: <0>, 59: <0>, 60: <0>, 61: <0>, 62: <0>, " \
           "63: <8>, 64: <600>, 65: <0>, 66: <0>, 67: <1>, 68: <0>, 69: <0>, 70: <0>, 71: <5001>}>", \
           text, img, now, now > GV
    close(GV)
    out = ""
    POST | getline out
    close(POST)
    id = out
    if (sub(/^\(/, "", id) && sub(/,\)$/, "", id) && id ~ /^[0-9]+$/) {
        cmd = "launch_app com.samsung.tv.notification-app NOTIFICATION_PRIVATE_ID " id " >/dev/null 2>&1"
        system(cmd)
        print strftime() " posted " id ": " title " | " msg >> LOG
    } else {
        print strftime() " post failed: " out >> LOG
    }
    close(LOG)
}

# Tizen bundle_encode: base64(md5 hex of raw + raw); raw = per key/value
# [u32 size][u32 type 0x0401 = string][u32 key len][key\0][u32 value len][value\0].
function bundle(k1, v1, k2, v2,    md5, b64, c) {
    printf "" > RAW
    kv(k1, v1)
    if (k2 != "") kv(k2, v2)
    close(RAW)
    c = "md5sum " RAW
    c | getline md5
    close(c)
    md5 = substr(md5, 1, 32)
    c = "(printf %s " md5 "; cat " RAW ") | base64 | tr -d '\\n'"
    c | getline b64
    close(c)
    return b64
}

function kv(k, v,    kl, vl) {
    kl = length(k) + 1
    vl = length(v) + 1
    u32(16 + kl + vl)
    printf "%c%c%c%c", 1, 4, 0, 0 > RAW
    u32(kl)
    printf "%s%c", k, 0 > RAW
    u32(vl)
    printf "%s%c", v, 0 > RAW
}

function u32(n) {
    printf "%c%c%c%c", n % 256, int(n / 256) % 256, int(n / 65536) % 256, int(n / 16777216) % 256 > RAW
}

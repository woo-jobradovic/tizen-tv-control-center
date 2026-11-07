#!/usr/bin/awk -f
# cc-keymon.awk v15 - Raw input key monitor for Samsung TV remote
# Sweet TV (597)->HBO, Back EXIT (174)->CC, Power (116)->real standby, Home -> CC
# v15: the remote's input device is found BY NAME ("Smart Control 2016", kbd handler) in
#      /proc/bus/input/devices instead of a fixed /dev/input/event6. The kernel numbers input
#      devices in the order they appear at boot, and the Bluetooth remote was event6 on some
#      boots and event7 on others (7-Nov: event7, so every key incl. Power was missed).
#      If the device goes away (remote reconnects, standby/wake), the reader ends and the
#      device is looked up again. A Power press while deviced reports the screen off
#      (pm state >= 3) is treated as the wake press and doesn't send standby again.
# Power click = deviced power.PowerOff int32:1 = Samsung instant-on standby (<1 W, apps
# kept in RAM; the wake press goes to the micom and never reaches the input device).
# Holding Power ~4 s reboots the TV natively (micom), nothing to do here.
# If PowerOff is refused, fall back to the v13 screen-off/on toggle:
# OFF = ChangePowerState lcdoff (notify deviced) + DPMS off (panel off)
# ON  = ChangeState lcdon (full reinit) + DPMS on (panel on)
# touch /tmp/cc_keylog to log every key code (for mapping new buttons).
# GNU Awk 3.1.5 compatible. UEP bypass via awk shebang.

function log_line(msg) {
    print systime() " " msg >> LOG
    close(LOG)
}

# Returns "eventN" for the first device named REMOTE that has a kbd handler, else "".
function find_remote(   line, name, dev, n, i, parts, kbd, ev) {
    dev = ""
    name = ""
    while ((getline line < DEVS) > 0) {
        if (line ~ /^N: Name=/) {
            name = line
            sub(/^N: Name="/, "", name)
            sub(/"[ \t]*$/, "", name)
        } else if (line ~ /^H: Handlers=/ && name == REMOTE && dev == "") {
            n = split(line, parts, /[ =]+/)
            kbd = 0
            ev = ""
            for (i = 1; i <= n; i++) {
                if (parts[i] == "kbd") kbd = 1
                if (parts[i] ~ /^event[0-9]+$/) ev = parts[i]
            }
            if (kbd && ev != "") dev = ev
        }
    }
    close(DEVS)
    return dev
}

# deviced's display state: 1 = on (normal), 2 = dim, 3 = lcdoff, 4 = sleep. 0 if unreadable,
# which keeps the old behaviour (send standby).
function pm_state(   c, out, p) {
    c = "vconftool get memory/pm/state 2>/dev/null"
    out = ""
    c | getline out
    close(c)
    if (split(out, p, "value = ") < 2) return 0
    return p[2] + 0
}

function handle(line,   n, f, type, code, val, now, rc, ps) {
    n = split(line, f)
    if (n < 7) return
    type = f[5] + 0
    code = f[6] + 0
    val  = f[7] + 0

    if (type != 1) return

    now = systime()

    if (val == 1 && (getline dummy < KEYLOG) >= 0) {
        close(KEYLOG)
        print now " key code=" code >> LOG
        close(LOG)
    }

    if (code == 597 && val == 1) {
        if (now - last_hbo >= 3) {
            system("app_launcher -k " STORE " >/dev/null 2>&1")
            system("app_launcher -s " HBO " >/dev/null 2>&1 &")
            last_hbo = now
            print now " HBO launched" >> LOG
            close(LOG)
        }
    }

    if ((code == 174 || code == HOME) && val == 1) {
        if (now - last_cc >= 3) {
            system("app_launcher -s " CC " >/dev/null 2>&1 &")
            last_cc = now
            print now " CC launched (key " code ")" >> LOG
            close(LOG)
        }
    }

    if (code == 116 && val == 1) {
        if (now - last_power >= 2) {
            ps = pm_state()
            if (screen_off == 0 && ps >= 3) {
                # The press that wakes the TV can reach us before it has fully suspended.
                # The screen is already off, so this press is a wake: don't send standby again.
                print now " Power while screen off (pm state " ps "), wake: no standby" >> LOG
            } else if (screen_off == 0) {
                rc = ""
                STANDBY | getline rc
                close(STANDBY)
                if (rc ~ /int32 0$/) {
                    print now " STANDBY (PowerOff 1, pm state " ps ")" >> LOG
                } else {
                    system(PSTATE_OFF)
                    system(DPMS_OFF)
                    screen_off = 1
                    print now " STANDBY refused (" rc "), OFF (ChangePowerState+DPMS)" >> LOG
                }
            } else {
                system(STATE_ON)
                system(DPMS_ON)
                screen_off = 0
                print now " ON (ChangeState+DPMS)" >> LOG
            }
            close(LOG)
            last_power = now
        }
    }
}

BEGIN {
    LOG = "/opt/usr/apps/ClaudeTVCC0/data/cc_keymon.log"
    KEYLOG = "/tmp/cc_keylog"
    DEVS = "/proc/bus/input/devices"
    REMOTE = "Smart Control 2016"
    CC = "ClaudeTVCC0.ControlCenter"
    HBO = "5b8c3eb16b.BeamCTVDev"
    STORE = "com.samsung.tv.store"
    HOME = 63
    DPMS_OFF = "dbus-send --system --print-reply --dest=org.enlightenment.wm /org/enlightenment/wm org.enlightenment.wm.Test.dpms.set uint32:3 >/dev/null 2>&1"
    DPMS_ON = "dbus-send --system --print-reply --dest=org.enlightenment.wm /org/enlightenment/wm org.enlightenment.wm.Test.dpms.set uint32:0 >/dev/null 2>&1"
    STATE_ON = "dbus-send --system --print-reply --dest=org.tizen.system.deviced /Org/Tizen/System/DeviceD/Display org.tizen.system.deviced.display.ChangeState string:lcdon >/dev/null 2>&1"
    PSTATE_OFF = "dbus-send --system --print-reply --dest=org.tizen.system.deviced /Org/Tizen/System/DeviceD/Display org.tizen.system.deviced.display.ChangePowerState string:lcdoff int32:0 int32:0 string:power_key >/dev/null 2>&1"
    STANDBY = "dbus-send --system --print-reply --dest=org.tizen.system.deviced /Org/Tizen/System/DeviceD/Power org.tizen.system.deviced.power.PowerOff int32:1 2>&1 | tail -1"

    last_hbo = 0
    last_cc = 0
    last_power = 0
    screen_off = 0
    waiting = 0

    print "cc-keymon v15 started" > LOG
    close(LOG)

    while (1) {
        dev = find_remote()
        if (dev == "") {
            if (!waiting) log_line("remote '" REMOTE "' not found, waiting")
            waiting = 1
            system("sleep 2")
            continue
        }
        waiting = 0
        log_line("reading /dev/input/" dev)
        # One 16-byte input_event per line. The reader exits when the device goes away
        # (dd returns nothing), so a vanished remote can't make it spin.
        cmd = "exec 3< /dev/input/" dev " || exit 1; while true; do x=$(dd bs=16 count=1 <&3 2>/dev/null | od -A n -t u2 -w16); [ -n \"$x\" ] || exit 0; echo \"$x\"; done"
        while ((cmd | getline line) > 0) handle(line)
        close(cmd)
        log_line("/dev/input/" dev " closed, looking for the remote again")
        system("sleep 1")
    }
}

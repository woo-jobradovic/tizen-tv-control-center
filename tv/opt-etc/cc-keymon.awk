#!/usr/bin/awk -f
# cc-keymon.awk v14 - Raw input key monitor for Samsung TV remote
# Sweet TV (597)->HBO, Back EXIT (174)->CC, Power (116)->real standby, Home -> CC
# Power click = deviced power.PowerOff int32:1 = Samsung instant-on standby (<1 W, apps
# kept in RAM; the wake press goes to the micom and never reaches event6).
# Holding Power ~4 s reboots the TV natively (micom), nothing to do here.
# If PowerOff is refused, fall back to the v13 screen-off/on toggle:
# OFF = ChangePowerState lcdoff (notify deviced) + DPMS off (panel off)
# ON  = ChangeState lcdon (full reinit) + DPMS on (panel on)
# v13: systime() instead of forking date; TV Plus kill removed (app disabled);
#      Home key (code 63 on event6) handled here, replacing dmesg-polling cc-homekey;
#      touch /tmp/cc_keylog to log every key code (for mapping new buttons).
# GNU Awk 3.1.5 compatible. UEP bypass via awk shebang.
BEGIN {
    LOG = "/opt/usr/apps/ClaudeTVCC0/data/cc_keymon.log"
    KEYLOG = "/tmp/cc_keylog"
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

    print "cc-keymon v14 started" > LOG
    close(LOG)

    cmd = "exec 3< /dev/input/event6; while true; do dd bs=16 count=1 <&3 2>/dev/null | od -A n -t u2 -w16; done"
    while ((cmd | getline line) > 0) {
        n = split(line, f)
        if (n < 7) continue
        type = f[5] + 0
        code = f[6] + 0
        val  = f[7] + 0

        if (type != 1) continue

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
                if (screen_off == 0) {
                    rc = ""
                    STANDBY | getline rc
                    close(STANDBY)
                    if (rc ~ /int32 0$/) {
                        print now " STANDBY (PowerOff 1)" >> LOG
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
}

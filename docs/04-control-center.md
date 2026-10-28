# 4. Control Center: a web app as the home screen

![Control Center](../screenshots/control-center.png)

The Control Center (CC) is one HTML page: a clock, the date, and a dock of apps in an iPadOS-like
style. It runs in the TV's own web runtime as a regular Tizen web app (`ClaudeTVCC0.ControlCenter`) and
is set as the home app. Four small awk daemons do what a web page isn't allowed to do.

```
 remote ──▶ cc-keymon.awk ── Home / Back ──────────────▶ app_launcher -s ClaudeTVCC0.ControlCenter
                         └── Power ───────────────────▶ deviced PowerOff 1 (real standby)
 CC page ── click an app ──▶ writes the app id to cc_launch ──▶ cc-launcher.awk ──▶ app_launcher -s <app>
 streaming app exits ──▶ cc-backmon.awk (D-Bus AppTerminate) ──▶ back to the CC
 data changes ──▶ cc-notifywake.awk ──▶ pop-ups (chapter 5)
```

## Installing the page as an app

The app is registered by hand, not installed from a `.wgt`:

1. Files: `/opt/usr/apps/ClaudeTVCC0/res/wgt/` gets [`index.html`](../tv/control-center/index.html), the
   icons and `config.xml` (also copied to `res/config.xml`), plus two files you supply: `wallpaper.jpg`
   (1920×1080, the background) and, optionally, `noti.wav` (the banner sound). `bin/ClaudeTVCC0.ControlCenter` is a
   symlink to `/usr/bin/wrt`. Owner `5001:5001`, SMACK label `User::Pkg::ClaudeTVCC0`.
2. Package database: insert the two rows in [`tv/register/pkgmgr-cc.sql`](../tv/register/pkgmgr-cc.sql)
   into `/opt/dbspace/.pkgmgr_parser.db`.
3. Security: the boot script loads the SMACK rules, registers the app with `security-manager-cmd`
   (idempotent) and grants the notification privilege with `cyad`.
4. Make it home: `vconftool set -t string db/appfw/home_appid ClaudeTVCC0.ControlCenter -f` (also run
   at every boot).

Don't use `com.samsung.tv.coba.plateauhome` as a home app ID: on this firmware it is an empty stub.

`config.xml` notes: `transparent.support` = true; no `homereturnsupport` metadata (it caused an endless
loading circle); privileges for `application.launch`, `filesystem.read/write`, `tv.inputdevice` and
`notification`.

## Launching apps from a web page

`tizen.application.launch()` needs a partner-level privilege. So the page writes the app ID to a file in
its private storage (`wgt-private/cc_launch`, which is
`/home/owner/apps_rw/xwalk-service/data/cc_launch` on disk). The root daemon
[`cc-launcher.awk`](../tv/opt-etc/cc-launcher.awk) polls that file every 0.5 s and runs
`app_launcher -s <appid>`.

Dock app IDs on our TV (they vary by region):

| App | ID |
|---|---|
| YouTube | `9Ur5IzDKqV.TizenYouTube` |
| Netflix | `org.tizen.netflix-app` |
| HBO Max | `5b8c3eb16b.BeamCTVDev` |
| Apple TV | `com.samsung.tv.aria-video` |
| Disney+ | `MCmYXNxgcu.DisneyPlus` |
| Prime Video | `org.tizen.primevideo` |
| Stremio | `IkWsFHtOY9.Stremio` |
| App Store | `org.volt.apps` |
| Settings | `org.tizen.menu` |

`cc-launcher.awk` also does three other jobs: it resets the AV-output "new home" flag every ~30 s
([chapter 6](06-picture-clarity.md)); it launches the CC once 20 s after boot if the system tried
before the SMACK rules were loaded; and it rotates its logs.

## Remote keys

The window manager owns the Home key, so setting `home_appid` alone isn't enough.
[`cc-keymon.awk`](../tv/opt-etc/cc-keymon.awk) reads the raw input device (`/dev/input/event6` on our TV):

| Key (code) | Action |
|---|---|
| Home (63) | open the CC |
| Back held, or EXIT (174) | back to the CC |
| Power (116) | `org.tizen.system.deviced.power.PowerOff int32:1`: Samsung's instant-on standby (apps kept in RAM, off the network after ~18 s). Falls back to screen off if refused |
| a vendor button (597) | open a chosen app (HBO Max here) |

Holding Power for ~4 s reboots the TV natively. `touch /tmp/cc_keylog` makes the daemon log every key
code, which helps when mapping new buttons.

[`cc-backmon.awk`](../tv/opt-etc/cc-backmon.awk) listens for `AppTerminate` signals on D-Bus. When a
streaming app or Settings exits, it opens the CC again, so "exit" always lands at home.

## OLED care

The Control Center is mostly a still image, which is what OLED panels dislike. We left Samsung's
burn-in protection alone: the screensaver apps (`spotlight-ss`, `glscreensaver-launcher`) stay enabled
and take over after a few idle minutes. The panel care settings (Pixel Shift, logo brightness
adjustment) weren't touched. Don't disable any of these, and prefer a wallpaper without large flat bright areas. Dimming or moving the clock
while idle would be a good next addition.

## Deploying changes

```sh
tools/push.sh tv/control-center/index.html /opt/usr/apps/ClaudeTVCC0/res/wgt/index.html 644
tools/tvcmd.sh 'f=/opt/usr/apps/ClaudeTVCC0/res/wgt/index.html; chown 5001:5001 $f; chsmack -a User::Pkg::ClaudeTVCC0 $f; app_launcher -t ClaudeTVCC0.ControlCenter'
```

For a daemon: push it to `/opt/etc/`, then
`systemctl stop <name>.service; systemd-run --unit=<name> /usr/bin/awk -f /opt/etc/<name>.awk`.
Keep a `.prev` copy on the TV for a one-step rollback.

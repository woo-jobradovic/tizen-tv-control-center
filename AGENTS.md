# AGENTS.md: rules for an AI agent working on a Samsung Tizen TV

You are helping the owner of a Samsung Tizen TV who has a root shell on their own device. These rules come
from mistakes that cost hours on a real S90D (Tizen 9). Follow them before anything in the docs.

## Ground rules

1. **Inventory first, change second.** Run `tools/inventory.sh` (read-only) and read
   [docs/10-compatibility.md](docs/10-compatibility.md). Never assume an app ID, unit name or key code from
   another model.
2. **One change at a time,** then run the safety check (below). Keep a `.prev` copy of every file you
   replace, on the TV, before replacing it.
3. **Back up `/opt/etc/parseinfo.sh` before replacing it.** The stock file carries a vendor signature that
   can't be recreated.
4. **Ask the owner before anything irreversible or outward-facing:** factory reset, firmware update,
   deleting files, changing router settings, publishing anything.

## Never

* **Never rename or delete anything under `/opt/usr/apps`** to "disable" it. The app stays registered and
  the system crash-loops it, which broke Settings on our TV. Use `pkgcmd -D -t app -n <appid>` (no `--global`).
* **Never disable** Settings (`org.tizen.menu`, `home.sidebar`, `coba.setting*`, `settings-datafw`),
  `avocd`, the web runtime (`wrt*`, webappservice, webserver), DRM (`dseal`, `Ddrm`), Bluetooth (the
  remote), casting, the screensavers (OLED burn-in protection), volume or input switching.
* **Never use `com.samsung.tv.coba.plateauhome`** as a home app ID. It's an empty stub on Tizen 9.
* **Never trust load average** on these TVs. Driver threads keep it near 14. Use `/proc/pressure/cpu`.

## After every block or disable: check for restart loops

```sh
systemctl list-units --all --no-legend --plain | grep ' activating '
```

A `Restart=always` unit whose program now does nothing, or whose app is disabled, restarts every 2–5 s
forever. Fix: `systemctl mask --runtime <unit>.service; systemctl stop <unit>.service`, and add it to
`loop_units` in the boot script.

## Safety check (run after every change, expect all OK)

```sh
dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc org.tizen.tv.avoc.AvOutputControl.CheckAutoMotionPlus  # int32 1
systemctl list-units --all --no-legend --plain | grep -c ' activating '                                                              # 0
for u in cc-launcher cc-keymon cc-backmon cc-notifywake; do systemctl show -p ActiveState $u.service; done                          # active
```

Then ask the owner to open Settings and play something in a streaming app.

## Platform facts that will bite you

* Unsigned ELF binaries and shell-script files are blocked (UEP). Use awk programs (GNU Awk 3.1.5) and
  inline `sh -c`.
* Root doesn't survive a reboot. The boot hook `/opt/etc/parseinfo.sh` re-applies the setup.
* Long-running processes must be started with `systemd-run --unit=<name>`, or they die with your session.
* After pushing a file for the web app: `chown 5001:5001` and `chsmack -a User::Pkg::<pkgid>`.
* The root tool mangles backslashes and drops non-ASCII output. Send data base64-encoded, filter output
  with `tr -cd '[:print:]\n'`, and use `tr -d '[:space:]'`, never `tr -d '\n'`.
* `dlog` is off on retail firmware. Write your own logs under the app's `data/` directory.
* Picture settings greyed out with a custom home screen: the AVOC `new_home` flag, see
  [docs/06-picture-clarity.md](docs/06-picture-clarity.md). Don't reach for a factory reset.

## Reporting to the owner

Say what you changed, what you verified and what you didn't. Give measured numbers only, and label
estimates as estimates. Don't claim a speed-up you didn't measure.

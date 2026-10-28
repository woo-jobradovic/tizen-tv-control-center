# 8. Lessons and dead ends

## Mistakes worth avoiding

* **Don't rename app folders to "disable" apps.** An early attempt renamed directories under
  `/opt/usr/apps` (and some binaries) to `*.DISABLED`. The apps stayed registered, so the system kept
  launching them and they kept crashing. It broke the gear menu's "All Settings" and Samsung Home, and
  sent us looking for a factory reset. Use `pkgcmd -D` ([Debloat](03-debloat.md)). All renames were
  restored.
* **Every block can create a restart loop.** Bind-mounting `/bin/true` over a program, or disabling an
  app, makes its `Restart=always` unit loop forever. Check for `activating` units after every change.
* **Don't trust load average** on this TV ([Performance](07-performance.md)).
* **Greyed-out picture settings weren't damage.** They came from a stale flag that Samsung Home normally
  resets ([Picture Clarity](06-picture-clarity.md)). Look for state like this before reaching for a
  factory reset.
* **Back up before you start:** `/opt/etc`, the package database rows you change, and the vconf keys
  you set.

## Dead ends

| Tried | Why it failed |
|---|---|
| A native helper binary (C, cross-compiled) | UEP blocks unsigned ELF everywhere, including `/tmp`, tmpfs and loading through `ld.so` |
| Shell-script daemons | UEP blocks `sh script.sh`. awk scripts and inline `sh -c` work |
| `tizen.notification` from the web app | the TV's web runtime doesn't ship the notification module |
| Keeping the web app running in the background (`background-support`, `background.execution.support`, `disable.bgtimer.throttle`, `suspend.delay`, `multitasking.support`) | Samsung's runtime suspends hidden web apps anyway. `launch_app … __K_BG_LAUNCH enable` works (chapter 5) |
| A Tizen web *service* app | never ran our code |
| Samsung's notification service app-control keys | disabled in retail firmware |
| `dlog` / `dlogutil` for debugging | logging is off on retail firmware. Write your own log files |
| Polling `dmesg` for the Home key | worked, but scanned a 480 KB ring buffer every 0.3 s. Reading `/dev/input/event6` is far cheaper |
| Screen-off as "standby" | the panel turns off but the system stays fully on. `deviced PowerOff int32:1` gives real standby |
| Signing out of the Samsung account to stop tracking | blocked every app behind a sign-in wall, and didn't stop device registration |

## Why so many awk scripts?

UEP leaves two ways to run your own logic as root: inline `sh -c` and interpreted awk. awk on this TV
is GNU Awk 3.1.5. It can loop, read files and pipes, run commands, and even build binary data with
`printf "%c"` under `LC_ALL=C`. That was enough for a launcher, a key monitor, a D-Bus listener and a
notification client.

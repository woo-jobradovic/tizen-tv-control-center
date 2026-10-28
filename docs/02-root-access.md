# 2. Root access, and what makes Tizen 9 different

## What this guide assumes

You have a **root shell on your own TV**. This repo doesn't contain or explain a root exploit. We used
an existing community tool that runs a command as root over SDB, and every command in this guide went
through it. If you don't have root, the [privacy settings and router blocking](01-privacy-research.md)
still work, and [TizenBrew](https://github.com/reisxd/TizenBrew) offers add-ons without root.

What you do need on the PC side:
* **Developer Mode** on the TV: in Apps, type `12345` on the remote, switch Developer Mode on, enter
  your PC's IP and reboot the TV.
* **sdb** from the Tizen SDK / Tizen Studio: `sdb connect <TV_IP>`.
* The helpers in [`tools/`](../tools): set your TV's IP and tool paths in `tools/config.sh`, then use
  `tools/tvcmd.sh '<command>'`.

## Facts about a rooted Tizen 9 TV

**Root does not survive a reboot.** Persistence comes from a boot hook: during startup the firmware
runs `/opt/etc/parseinfo.sh` as root (it normally writes the model/build string to
`/proc/target_version`), and `/opt/etc` is writable. Our [`parseinfo.sh`](../tv/opt-etc/parseinfo.sh)
does the original job at the end and all of our setup before that.

**Back up the original before you replace it.** On our TV the stock file is a short bash script with
Samsung's UEP signature appended. You can't recreate that signature, so your own copy is the only way
back to stock ([Recovery](09-recovery.md)).

**Unsigned executables are blocked (UEP).** Samsung's *Unsigned Executable Protection* refuses:
* any ELF binary that isn't signed, everywhere, including `/tmp` and through `ld.so`;
* shell scripts run from a file (`sh script.sh`).

It allows inline `sh -c '…'` and **awk programs**. That's why every daemon here is written in awk
(GNU Awk 3.1.5: no `match()` capture groups, no `gensub`). The boot hook itself is an awk script.

**SMACK labels decide who can touch what.** A web app runs with the label `User::Pkg::<pkgid>`. Files
it reads must carry that label (or `_`). Rules for a manually registered app must be loaded at every
boot (`/sys/fs/smackfs/load2`, see [`smack-cc.rules`](../tv/opt-etc/smack-cc.rules)). After every file you
push: `chown 5001:5001 <file>; chsmack -a User::Pkg::<pkgid> <file>`.

**Privileges are checked by cynara and security-manager.** An app installed outside the store has to be
registered with `security-manager-cmd` and, for some privileges (notifications), granted in cynara with
`cyad`. Both are in the boot script.

**The system is read-only.** `/usr` and `/etc` are read-only. To "remove" a system program, bind-mount
`/bin/true` over it at boot ([Debloat](03-debloat.md)). Never delete or rename files under `/opt/usr/apps`
([why](08-lessons.md)).

**Other quirks worth knowing:**
* `sdb push/pull` are locked on retail firmware. Move files as base64 through the root shell
  (`tools/push.sh`, `tools/pull.sh` do that in chunks, with md5 checks).
* There is no `timeout` command. Long-running daemons must be started with
  `systemd-run --unit=<name> …`, otherwise they die with the root session.
* The root tool mangles backslashes and drops output that contains non-ASCII characters. Pipe through
  `tr -cd '[:print:]\n'`, and use `tr -d '[:space:]'` (a literal `'\n'` becomes the letter `n`).
* `systemctl status` prints a non-ASCII bullet, so use `systemctl show -p ActiveState <unit>`.
* `dlog` is disabled on retail firmware, so there are no app logs. Write your own logs to the app's
  `data/` directory.

## Firmware updates

The setup blocks Samsung's automatic firmware update services. An update could close the root method
for good, and it would replace parts of the system this setup relies on. The trade-off is that you no
longer get security updates automatically. If you decide to update by hand, first remove the boot
script's changes (restore the original `parseinfo.sh`) and accept that root may be gone afterwards.

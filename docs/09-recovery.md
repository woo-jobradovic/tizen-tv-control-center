# 9. Recovery: undo any part, or all of it

Every change in this repo can be undone. Do it in this order, with a root shell, and reboot at the end.

## Before you start: back up

* `/opt/etc/parseinfo.sh`. On our TV the stock file is a short bash script with Samsung's UEP signature
  appended. You can't recreate the signature, so this copy is your only way back to the stock boot script.
* The vconf home key: `vconftool get db/appfw/home_appid`
* A list of what is already disabled:
  `sqlite3 /opt/dbspace/.pkgmgr_parser.db "select app_id from package_app_info where app_disable='true'"`

Keep a `.prev` copy on the TV every time you replace a file, for a one-step rollback.

## Undo step by step

| What | Undo |
|---|---|
| Disabled apps | `for a in $(cat /opt/etc/cc-disabled-apps.txt); do pkgcmd -A -t app -n $a; done` |
| Blocked programs, masked units, daemons | restore your original `parseinfo.sh` and reboot. The bind mounts, runtime masks and `systemd-run` units only exist until the next boot |
| Home app | `vconftool set -t string db/appfw/home_appid <your original value> -f` |
| Control Center app | delete its two rows from `/opt/dbspace/.pkgmgr_parser.db` (`package_info`, `package_app_info` where the package is `ClaudeTVCC0`), then `rm -r /opt/usr/apps/ClaudeTVCC0` |
| Notification privilege | erase the policy with `cyad`'s erase option for the same client/user/privilege (or leave it: without the app it grants nothing) |
| Picture settings flag | nothing to do: Samsung Home sets it itself once it's back |
| Router blocking | remove the TV's DNS override and firewall rule |

## If something goes wrong

* **The TV doesn't react:** hold **Power for about 4 seconds**. The TV reboots natively, without any of
  our code involved.
* **The Control Center doesn't appear after boot:** wait 3 minutes (the launcher re-checks 20 s after it
  starts). Then press Home. Apps still open from the Apps screen and Settings.
* **A setting or app broke after a change:** run the safety check from [Debloat](03-debloat.md#safety-check-after-every-change),
  look for restart loops, and re-enable the last app you disabled.
* **The boot script itself fails:** none of our changes are applied, and the TV behaves close to stock.
  The script also writes the model/build line the stock script wrote, and we didn't test what relies on
  that line. Fix the script, or restore your original, over a root shell soon.

## Factory reset

We didn't need one, and we didn't test what it undoes on this firmware. Reports from other owners
say a factory reset restores preloaded apps and menu settings. Whether it also wipes `/opt/etc` and the
package database flags is unverified. So **undo the changes yourself first** (table above), then reset if
you still want to. Before setting the TV up again, keep it offline and switch off auto-update if you
want to keep the option of root.

Router-level blocks are not affected by a factory reset.

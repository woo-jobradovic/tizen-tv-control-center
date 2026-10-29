# Picture modes greyed out with a custom launcher? The fix

This page stands on its own. You don't need the rest of this project, and it works with any launcher
that replaces Samsung Home (Arn0-Launcher, our Control Center, or anything else).

**Tested on:** S90D, Tizen 9. On other Tizen versions, run the check in step 1 first. If the D-Bus
method isn't there, this fix doesn't apply to your TV. Please report what you find (see the end).

## Symptom

After switching to a custom home screen:
* *Picture Clarity* says "This function isn't available".
* *Picture Mode*, *Colour Booster* and *Contrast Enhancer* are greyed out, even while a video plays.

Rule out the usual causes first: a PC device icon on the HDMI input, Game Mode, Input Signal Plus with a
high-frame-rate signal, mirroring or Multi View. See [chapter 6](06-picture-clarity.md).

## Cause

The picture daemon `avocd` keeps a `new_home` flag. Samsung Home sets it to 1 while its UI is on screen,
to turn motion processing off behind the home screen, and back to 0 when it hides. With a different
launcher, nobody resets it, so it stays at 1 and the settings stay greyed out.

## Fix

You need a root shell on the TV.

**1. Check** (read-only). `int32 1` means available, `int32 0` means greyed out:

```sh
dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc \
  org.tizen.tv.avoc.AvOutputControl.CheckAutoMotionPlus
```

If this returns an error such as "UnknownMethod", your firmware works differently and the fix below
won't help.

**2. Fix it now:**

```sh
dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc \
  org.tizen.tv.avoc.AvOutputControl.SetNewHome int32:0
```

Run step 1 again. It should now say `int32 1`. Open the picture settings and they're back.

**3. Keep it fixed.** The flag lives only in memory, and Samsung code can set it again. This keeps
resetting it every 30 s until the next reboot. It's an awk loop, because Tizen blocks shell-script files:

```sh
systemd-run --unit=newhome-fix /usr/bin/awk 'BEGIN { while (1) {
  system("dbus-send --system --dest=org.tizen.tv.avoc /org/tizen/tv/avoc org.tizen.tv.avoc.AvOutputControl.SetNewHome int32:0")
  system("sleep 30") } }'
```

Stop it with `systemctl stop newhome-fix`.

**4. After a reboot:** run step 3 again, or add it to whatever boot hook your root setup uses. Our own
setup does it from `cc-launcher.awk`, started by `/opt/etc/parseinfo.sh` (see [chapter 4](04-control-center.md)).

## Is it safe?

The call only resets the flag Samsung Home would reset itself when it hides. Nothing is written to disk.
A reboot without step 3 gives you stock behaviour back.

## Did it work on your TV?

Open a [compatibility report](https://github.com/woo-jobradovic/tizen-tv-control-center/issues/new?template=compatibility.md) on GitHub with your model, Tizen
version, the output of step 1, and whether the fix worked. That's how we'll learn which models it covers.

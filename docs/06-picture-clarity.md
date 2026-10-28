# 6. Picture settings greyed out

## First, the usual causes (no root needed)

*Picture Clarity* and its neighbours are switched off on purpose in several situations. Check these first:

* **The input is set as a PC.** Source → the HDMI input → Edit → change the device icon to something
  other than PC (for example Blu-ray or Set-top box). PC mode disables motion processing.
* **Game Mode** is on (Settings → Connection → Game Mode Settings), or the TV switched to it
  automatically because a console is connected.
* **Input Signal Plus** with a high-frame-rate signal: high refresh rates disable Picture Clarity.
* Screen mirroring, Multi View/PIP or Photo mode is active.

If none of these apply, and especially if Samsung Home crashed or was replaced, read on.

## The cause on a custom home screen

**Symptom:** after replacing the home screen, *Picture Clarity* says "This function isn't available".
*Picture Mode*, *Colour Booster* and *Contrast Enhancer* are greyed out too, even while a video plays.
It looked like the debloat had broken something, and we nearly did a factory reset.

**Cause:** the AV-output daemon `avocd` keeps a **`new_home`** flag. Samsung Home sets it to 1 while its
UI is on screen, to force motion processing off behind the home screen, and back to 0 when it hides.
When Samsung Home crashes or is replaced, nobody sets it back, so it stays at 1 and every setting that
depends on motion processing is greyed out.

**Fix:** set it to 0 over D-Bus:

```sh
dbus-send --system --print-reply --dest=org.tizen.tv.avoc /org/tizen/tv/avoc \
  org.tizen.tv.avoc.AvOutputControl.SetNewHome int32:0
```

The flag lives only in memory, so [`cc-launcher.awk`](../tv/opt-etc/cc-launcher.awk) re-sends this every
~30 s. Test: we forced the flag to 1, and Picture Clarity was available again within 32 s. It also
survives reboots.

## How it was found

Tracing the call chain with Ghidra:

```
Settings JSON  /usr/apps/settings-datafw/res/jsons/tv/expert-settings.json
  └ enable-checker "picture-enable-checker" = /usr/share/menu/providers/libpicture-enablechecker.so
     └ avoc_check_auto_motion_plus(0)   in /usr/lib/libavoc.so
        └ D-Bus org.tizen.tv.avoc  /org/tizen/tv/avoc  AvOutputControl.CheckAutoMotionPlus
           └ avocd: _avocd_check_auto_motion_plus → _avocd_is_motion_plus_forced_off
              inputs: mirroring, PIP, photo mode, PC mode, HFR, multi-view, VRR, game mode,
                      common picture mode … and new_home
```

Useful read-only calls for checking: `CheckAutoMotionPlus` and `CheckPictureMode` (1 = available),
`GetPictureMode`, `GetGameMode`, `GetPcMode`.

Things that turned out **not** to be the cause: blocking the AI picture services, and the debloat in
general.

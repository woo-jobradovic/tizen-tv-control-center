# 7. Performance

![Performance](../screenshots/performance.png)

All numbers were measured on the TV over the root shell, on 27–28 Oct 2026. Where a number is an
estimate, it says so.

## Before and after the debloat (27 Oct)

| Metric | Before | After | Notes |
|---|---|---|---|
| Crash-looping Samsung app launches | 55 per 40 s | 0 per 30 s | voice-app 37, smartthings-thing 12, mde-framework 6 |
| CPU pressure (`/proc/pressure/cpu`, "some", 10 s avg) | ~6 % | ~3 % | same day. 1.5 % on the home screen on 28 Oct |
| Free memory (`MemAvailable`) | 460 MB | ~780 MB | different uptimes and open apps, so a rough comparison |


Boot to the Control Center takes about 2.5–3 minutes. The TV answers on the network after ~60–90 s.

## The finished setup (28 Oct)

| Scenario | CPU (4 cores) | GPU (Mali-G51) | Free memory |
|---|---|---|---|
| Control Center on screen, idle | ~10 % | 0 % | ~760 MB of 1.8 GB |
| YouTube playing | ~23 % | ~1 % | ~770 MB |

Video is decoded by a dedicated hardware block, so the GPU stays nearly idle during playback.

### Home key → Control Center (28 Oct)

Measured from the launch request (what the Home key sends) until the page had drawn its first frame on
screen, starting from YouTube. Three runs each:

| Start | Runs | Typical |
|---|---|---|
| Warm: the Control Center is still in memory (the normal case) | 0.46 s, 0.50 s, 0.41 s | **~0.45 s** |
| Cold: the Control Center was closed and loads from scratch | 0.55 s, 1.78 s, 1.80 s | **0.5–1.8 s** |

The window itself is on top within 0.01–0.02 s in the warm case. The rest is the page drawing. Timer:
[`cc-launchtime.awk`](../tv/opt-etc/cc-launchtime.awk), plus a small marker in the page that writes the
time of its first frame after becoming visible (`cc_painted`). There is no Samsung Home number to compare
with, because it was already replaced when we started measuring.

## What we don't claim

Menu responsiveness and app start times weren't measured before the change, so there is no
"x times faster" number here. The Home key timing above is for the finished setup only. More free memory and no crash loops mean less background
pressure. Menus are still limited by the TV's chip.

## Numbers that mislead

* **Load average stays near 14** whatever the TV does. About 8 TV driver threads (`Tuner-*`, `tzlogd`,
  `mp_capture`, `kfactoryd`…) sit permanently in uninterruptible sleep, and those count toward load.
  Judge real load by CPU pressure and by relaunch counts instead.
* **systemd's CPU use** right after boot is boot activity. Measure after ~15 minutes.
* **Standby power** (<1 W in real standby, ~10–20 W with only the screen off) is an estimate from the
  power state the TV reports. It wasn't measured with a meter.

## Measure your own TV

[`cc-perf.awk`](../tv/opt-etc/cc-perf.awk) samples CPU (`/proc/stat`), GPU busy time (the Mali
driver's `/sys/kernel/debug/mali0/dvfs_utilization`), `MemAvailable` and CPU pressure:

```sh
tools/push.sh tv/opt-etc/cc-perf.awk /opt/etc/cc-perf.awk 755
tools/tvcmd.sh 'awk -v N=6 -v T=5 -f /opt/etc/cc-perf.awk'
```

```
sample 1 cpu 7.1 gpu 0.0 memavail_mb 760 cpupressure 1.41
...
```

To spot restart loops, count units stuck restarting (expect 0):
`systemctl list-units --all --no-legend --plain | grep -c ' activating '`.

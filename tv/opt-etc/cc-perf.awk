#!/usr/bin/awk -f
# Samples CPU busy %, GPU busy % (Mali dvfs_utilization), available memory and CPU pressure.
# Usage: awk -v N=6 -v T=5 -f perf.awk   (N samples, T seconds apart)
BEGIN {
    if (N == "") N = 6; if (T == "") T = 5
    read(); pb = cb; pt = ct; pg = gb; pgi = gi
    for (i = 1; i <= N; i++) {
        system("sleep " T)
        read()
        cpu = 100 * (cb - pb) / (ct - pt)
        gpu = (gb - pg + gi - pgi) > 0 ? 100 * (gb - pg) / (gb - pg + gi - pgi) : 0
        printf "sample %d cpu %.1f gpu %.1f memavail_mb %d cpupressure %s\n", i, cpu, gpu, ma / 1024, cp
        pb = cb; pt = ct; pg = gb; pgi = gi
    }
}
function read(    f, a, n, k) {
    f = "/proc/stat"; getline line < f; close(f)
    n = split(line, a, " "); ct = 0
    for (k = 2; k <= n; k++) ct += a[k]
    cb = ct - a[5] - a[6]
    f = "/sys/kernel/debug/mali0/dvfs_utilization"; getline line < f; close(f)
    split(line, a, " "); gb = a[2]; gi = a[4]
    f = "/proc/meminfo"
    while ((getline line < f) > 0) if (line ~ /^MemAvailable/) { split(line, a, " "); ma = a[2] }
    close(f)
    f = "/proc/pressure/cpu"; getline line < f; close(f)
    split(line, a, " "); cp = a[2]; sub(/avg2=/, "", cp)
}

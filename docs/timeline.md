# Timeline

| Date (2026) | What happened |
|---|---|
| Jul | Router logs show the TV as the noisiest device on the network: ~30 DNS queries per minute, all day |
| 21 Sep | TV taken off the VPN tunnel so its hostnames become visible. First full privacy audit: ~80 hostnames classified, per-device filtering DNS set up at the router |
| 22 Sep | Filtering confirmed with live packet counts: zero packets to the ad platform and the telemetry endpoint. Signing out of the Samsung account tried and reverted |
| 26 Oct (morning) | Second audit with Developer Mode: ~650 system components and ~50 tracking hosts checked. A "Debloat Chooser" lists every service with what turning it off costs |
| 26 Oct (later) | Root shell obtained. First version of the Control Center: an iPadOS-style web page, registered as the home app. App launching works through a file and a root daemon |
| 27 Oct (night) | Home key, Back key and boot persistence. Full reboot test passes |
| 27 Oct (day) | Picture Clarity greyed out and Samsung Home crashing. Factory reset planned and backup taken. Ghidra traces the cause to the AVOC `new_home` flag: fixed, no reset needed. Renamed app folders found and restored |
| 27 Oct (evening) | Debloat done properly: 41 apps disabled with `pkgcmd -D`, 33 programs blocked, 15 restart-looping units masked. Crash loops 55 per 40 s → 0. Power button → real standby |
| 28 Oct | Notifications over any app: background wake, a D-Bus notification client written in awk, Samsung's own pop-up viewer. Friendlier texts and icons. iOS-style Settings icon in the dock |

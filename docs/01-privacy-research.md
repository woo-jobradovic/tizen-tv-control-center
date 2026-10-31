# 1. Privacy research: what the TV talks to

Everything started with a router log. The TV was the noisiest device on the network, at about
**30 DNS queries per minute**, all day, even when nobody was watching.

## Make the traffic visible first

At first the TV sat behind a VPN tunnel on the router, so the router saw only encrypted query counts and
no hostnames. Taking the TV off the tunnel for the audit made every hostname visible in the router's
DNS/web history and firewall log. A 5-hour window gave about **80 distinct hostnames** and a few hundred
connections. Most of the connections belonged to the streaming app in use, not to tracking.

Lesson: if your TV goes through a VPN, your router can't tell you what it talks to.

## What a Samsung TV contacts

| Category | Example of what it does | Verdict |
|---|---|---|
| ACR / content recognition | identifies what is on screen, including HDMI sources | none seen while *Viewing Information Services* was off. The service is blocked on the TV anyway |
| Samsung ad platform | serves and measures ads in the home screen and TV Plus | **block** |
| Device telemetry and log upload | usage analytics, crash/KPI logs | **block** |
| Voice assistant backend | contacted periodically even with no voice use | block if you don't use voice |
| Smart-home hub / device registration | SmartThings discovery at every boot | tied to the Samsung account. Disabled on the TV later |
| HDMI device identification | recognises what is plugged in (universal remote) | optional |
| Device trust / attestation | Samsung integrity service | leave alone |
| App store, account, firmware info | needed for apps and sign-in | **keep** |
| Streaming-app analytics | each app's own beacons and logs | the app's business. Blocking them is optional |
| Hard-coded DNS fallback (8.8.8.8) | the TV falls back to a public resolver around network restarts and boot | block outbound DNS to anything except your resolver |

## Blocking at the network

1. **Per-device DNS to a filtering resolver.** Give the TV a DHCP reservation whose DNS points at a
   filtering resolver (AdGuard DNS, NextDNS, a Pi-hole…). Power-cycle the TV fully so it takes the new
   lease. Our router's advertised "DNS director" feature didn't exist on its firmware, but the DNS field
   in the DHCP reservation did the job.
2. **Close the fallback.** Block outbound port 53 (and DoT 853) from the TV to anything but your
   resolver. Otherwise the hard-coded fallback bypasses the filter for a few seconds after every
   network event.
3. **Measure, don't assume.** A public filter's default list blocked only about 40 % of a sample of
   known Samsung tracking hosts. After adding custom rules and checking live packet counts, the ad
   platform and the telemetry endpoint both showed **zero** packets.

### Build your own list instead of copying one

Shared "Samsung blocklists" disagree with each other, and the big ones are known to break the app store
and Samsung TV Plus. A list built from your own TV's traffic is shorter and safer:

1. Put the TV in its own group or client profile on your filter (Pi-hole groups, NextDNS profile, AdGuard
   client), so other devices are untouched.
2. Use the TV normally for a day and export its query log.
3. Block hosts that are clearly ads, telemetry, logging or ACR. Keep app store, account, firmware info
   and every streaming app you use.
4. Check that the apps you use still start, then watch the log again for a day.

Our own list, with what each host is and whether we tested blocking it, is in [`blocklist/`](../blocklist/).
Use it as a starting point next to your own log ([No root](11-no-root.md#3-block-at-the-dns)).

What *not* to do: signing the TV out of the Samsung account didn't stop the device-registration
traffic, and it put a sign-in wall in front of every app. We signed back in. DNS blocking doesn't
depend on the account state.

## TV settings worth changing (no root needed)

Settings → General & Privacy → Terms & Privacy (names vary slightly by model and year):
* **Viewing Information Services:** off (this is ACR)
* **Interest-Based Advertisement:** off, then **Reset Advertising ID**
* **Voice Recognition Services:** off, and turn off the voice assistant / wake word
* **Autorun Smart Hub / autorun last app:** off, so the home screen stops fetching previews
* Use the **physical microphone switch** on the TV if your model has one

Some things have no switch at all. The SmartThings hub registration is the main one, and it only
stopped once the apps behind it were disabled on a rooted TV ([Debloat](03-debloat.md)).

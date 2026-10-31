# 11. No root: what any Samsung TV owner can do

Most Samsung TVs can't be rooted, and older ones (Tizen 2.4 to 5.5) never will be by the route in this
repo. You can still cut most of the ads and tracking, from the TV's own menus and from your network.
Nothing here installs anything on the TV, and every step can be undone.

| Step | What it stops | Needs |
|---|---|---|
| [1. Privacy switches](#1-privacy-switches) | content recognition (ACR), ad personalisation, voice data | the remote, 2 minutes |
| [2. Stop the home screen starting by itself](#2-stop-the-home-screen-starting-by-itself) | Smart Hub and TV Plus fetching previews and ads at every power-on | the remote |
| [3. Block at the DNS](#3-block-at-the-dns) | Samsung's ad platform, telemetry, ACR uploads | the remote (basic) or a filtering DNS service (full) |
| [4. Ad-free YouTube](#4-ad-free-youtube) | YouTube ads | a PC, Developer Mode |
| [5. Hold updates (optional)](#5-hold-updates-optional) | changes you didn't ask for | the remote. Costs you security fixes |

## Which TV do you have?

**Settings → Support → About This TV** shows the model code. The model year decides the Tizen version
and roughly where the menus are:

| Year | Tizen | Model code examples |
|---|---|---|
| 2016 | 2.4 | **K**S8500, **K**U6300 |
| 2017 | 3.0 | **M**U8000, The Frame 2017 |
| 2018 | 4.0 | **N**U7100 |
| 2019 | 5.0 | **R**U7100 |
| 2020 | 5.5 | **T**U8000 |
| 2021 | 6.0 | **A**U8000 |
| 2022 | 6.5 | **B**U8000, S95B |
| 2023 | 7.0 | **C**U8000, S90C |
| 2024 | 8.0 (some updated to 9) | **D**U8000, S90D |
| 2025 | 9.0 | U8000F, S90F |

The letter right after the screen size tells the year on Crystal UHD models (UE55**T**U8000 = 2020).
QLED and OLED codes reuse letters across years (a Q7F can be 2017 or 2025), so search your full model code
if you're unsure. Similar names can be years apart: the TU8000 is a 2020 model and the U8000F a 2025 one.

> **About the menu paths below:** we verified them on one 2024 TV. For other years we give the paths
> we know of. Samsung renames menus often, so if a path doesn't match, look for the same words under
> **Support** or **General**. Found the right path on your model?
> [Tell us](#help-fill-the-gaps) and we'll add it.

## 1. Privacy switches

Turn off:
* **Viewing Information Services.** This is ACR, the feature that recognises what's on screen, including
  HDMI sources.
* **Interest-Based Advertisement,** then **Reset Advertising ID** (or *Reset PSID*).
* **Voice Recognition Services,** and the wake word if your TV has one. Use the **microphone switch** on
  the TV if it has one.

Leave the **Smart Hub Terms and Conditions** alone. Revoking them turns off the apps.

| Years | Where |
|---|---|
| 2023–2024 | Settings → All Settings → General & Privacy → Terms & Privacy *(verified on a 2024 S90D)* |
| 2025 | Settings → Support → Terms & Privacy, or as for 2023–2024 |
| 2016–2022 | Settings → Support → Terms & Policy (on some 2022 models: Settings → General → Terms & Privacy) |

Does it work? On our TV, with Viewing Information Services off, the router log showed **no contact at
all** with any of the six known ACR servers over 5 hours. A 2024 study of Samsung and LG TVs found the
same: opting out stops the traffic to ACR servers
([Anselmi et al., IMC 2024](https://arxiv.org/abs/2409.06203)).

## 2. Stop the home screen starting by itself

Turn off **Autorun Smart Hub** (or *Start with Smart Hub Home*), **Autorun Last App** and **Autorun
Samsung TV Plus** if you see it.

| Years | Where |
|---|---|
| 2023–2024 | Settings → All Settings → General & Privacy → Start Screen Option *(verified on a 2024 S90D)* |
| 2017–2022 | Settings → General → Smart Features |
| 2016 | Settings → Smart Hub, or Settings → General → Smart Features |

## 3. Block at the DNS

Every server the TV talks to is looked up by name first. A filtering DNS answers "doesn't exist" for
the ad and tracking names, and the TV never connects. It works on every Samsung TV, any year.

### Basic: one setting on the TV, nothing else

Point the TV at **AdGuard DNS**, a free public resolver with an ad and tracker filter:

1. Settings → General → Network → **Network Status** → **IP Settings** (2023 and later: Settings → All
   Settings → Connection → Network → Network Status → IP Settings).
2. **DNS Setting → Enter manually**, DNS server **`94.140.14.14`**.
3. OK, then turn the TV off **at the wall** for 10 seconds, so it really reconnects.

What we measured: our TV contacted about 80 hostnames in 5 hours. We tested AdGuard DNS's default filter
against 19 ad, tracking, analytics and ACR hostnames (17 from that traffic, plus 2 known ACR servers) and
against 5 the TV needs. It blocked **10 of the 19**, including the whole Samsung ad platform and the main
telemetry endpoint, and left all 5 needed ones alone: the app store, account, firmware information,
Netflix and HBO Max kept working. It misses the other 9, including one ACR server. For those, use the
full setup.

### Full: a filtering DNS with our list

Use a DNS service where you can add your own lists: **AdGuard Home** or **Pi-hole** on a small computer
at home, or a hosted one like **NextDNS** or a private **AdGuard DNS** profile. Then add our list. It's
short on purpose: built from our TV's real traffic and checked against what has to keep working.

**Two entries in the default list are untested.** Our TV contacted `img-resize-cdn-prod.samsungnyc.com`
(images for Samsung's home-screen ads) and `lcprd1.samsungcloudsolution.net` (a log collector), but we
haven't yet blocked each one on its own and checked the TV afterwards. We expect nothing to break. If
something does, remove that line and [tell us](#help-fill-the-gaps).

| File | Use it for |
|---|---|
| [`samsung-tv-adguard.txt`](../blocklist/samsung-tv-adguard.txt) | AdGuard Home and AdGuard DNS. Also blocks subdomains, and protects the never-block list |
| [`samsung-tv-domains.txt`](../blocklist/samsung-tv-domains.txt) | Pi-hole, NextDNS, most routers |
| [`samsung-tv-hosts.txt`](../blocklist/samsung-tv-hosts.txt) | a hosts file, dnsmasq |
| [`samsung-tv-allow.txt`](../blocklist/samsung-tv-allow.txt) | **never block these.** Add them to your allowlist, above all if you also use a big public list |

* **AdGuard Home:** Filters → DNS blocklists → Add blocklist → Add a custom list → paste
  `https://raw.githubusercontent.com/woo-jobradovic/tizen-tv-control-center/main/blocklist/samsung-tv-adguard.txt`
* **Pi-hole:** Lists (Adlists on older versions) → add the raw URL of `samsung-tv-domains.txt`, then
  run *Update Gravity*. Add the hostnames from `samsung-tv-allow.txt` as allowed domains.
* **NextDNS:** Denylist → add each hostname from `samsung-tv-domains.txt` (subdomains are included).
  Allowlist → the hostnames from `samsung-tv-allow.txt`.

Then give the TV that DNS: either set it on the TV as in *Basic*, or give the TV a DHCP reservation on
your router with that DNS server.

**A free-tier trap:** our TV made about 30 DNS queries a minute, all day. That's over a million a month,
more than some hosted services' free tiers. Check what happens when you go over (some stop filtering).

**The list has optional parts.** Each one turns a feature off, so they're not in the ready-made files.
Build your own with [`tools/blocklist.sh`](../tools/blocklist.sh) (Git Bash, macOS or Linux):

```sh
tools/blocklist.sh adguard voice,tvplus > my-tv.txt
```

| Group | Blocks | You lose |
|---|---|---|
| `voice` | Bixby's servers, which our TV contacted with nobody speaking | voice control |
| `smartthings` | the SmartThings cloud | the SmartThings phone app for the TV |
| `tvplus` | the Samsung TV Plus channel guide | TV Plus |
| `hdmi-id` | device identification for HDMI inputs | automatic device names and universal-remote setup |
| `apps` | ads and analytics inside Netflix, Prime Video, HBO Max and YouTube | probably nothing. These are the apps' business, so it's your call |

Every hostname, what it is and whether we tested blocking it is in
[`blocklist/samsung-tv.tsv`](../blocklist/samsung-tv.tsv).

### Two holes to close

* **The hard-coded fallback.** When your DNS is briefly unreachable (a network restart, a boot), the TV
  asks Google's `8.8.8.8` directly and skips your filter. Ours sent 18 queries there in one second. If
  your router can, block outbound port **53** and **853** from the TV to anything except your DNS.
* **A VPN on the router.** If the TV's traffic goes through a VPN tunnel, its DNS usually goes to the VPN's
  resolver and your filter never sees it. Check your filter's log for the TV's queries.

### Watch your own log

Your TV, region and apps differ from ours. Give the TV its own client or group in your filter, use it
normally for a day, and look at what it asks for. Block what is clearly ads, telemetry or logging. Keep
the app store, account, firmware and every streaming app you use. Found a host that's not on our list?
[Tell us](#help-fill-the-gaps).

## 4. Ad-free YouTube

[TizenBrew](https://github.com/reisxd/TizenBrew) with its TizenTube module runs on the TV through
Developer Mode, without root. Check its README for the Tizen versions it supports, and install it from
its official releases only.

## 5. Hold updates (optional)

Settings → Support → Software Update → turn off **Auto Update**. If a pop-up still offers an update,
choose **Do not update**. This keeps the TV as it is, but you also stop getting Samsung's security fixes.
On a TV you don't plan to root, we'd leave updates on.

## What not to do

* **Don't sign out of the Samsung account.** We tried: it didn't stop the cloud traffic, and every app
  hit a sign-in wall. We signed back in.
* **Don't revoke the Smart Hub terms.** The apps stop.
* **Don't paste a big public "Samsung blocklist" on its own.** The big ones are known to break the app
  store and TV Plus. If you use one, add our allowlist next to it.

## Undo

| Step | To undo |
|---|---|
| 1, 2 | Turn the switches back on, same menus |
| 3, basic | IP Settings → DNS Setting → **Obtain automatically**, then off at the wall for 10 s |
| 3, full | Remove the list in your filter, or point the TV back at your router |
| 4 | Uninstall TizenBrew like any app, and turn Developer Mode off |
| 5 | Turn Auto Update back on |

## Help fill the gaps

We have one TV. For other years, menu paths, extra hostnames and what broke are best reported by
owners. Open a [compatibility report](../.github/ISSUE_TEMPLATE/compatibility.md) and fill in the
*No root* part. Please leave out your serial number, IP and MAC addresses, and account details.

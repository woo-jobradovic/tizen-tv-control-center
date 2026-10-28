# 10. Compatibility: check your model first

This setup was built and verified on **one** TV:

| Model | Firmware | Tizen | Status |
|---|---|---|---|
| Samsung S90D OLED, EU | T-PTMDDEUC, build from May 2026 | 9.0 | everything in this repo verified, reboot-tested |

Other 2024–2025 Tizen 9 models are probably close, but app IDs, service names and key codes differ by
model, year and region. Disabling an app ID that means something else on your TV is how things break.

## Read-only check

[`tools/inventory.sh`](../tools/inventory.sh) changes nothing. It prints:
* your firmware and Tizen version;
* for each of the 41 app IDs: whether it exists on your TV and whether it's already disabled;
* which of the 33 programs exist;
* which of the 15 restart-loop units exist;
* whether picture processing is currently available;
* the names of the input devices (to find your remote's key device).

```sh
tools/inventory.sh > my-tv.txt
```

Read it before changing anything:
* **App ID missing?** Your model doesn't have it. Skip it.
* **A program or unit missing?** Remove it from the boot script's lists.
* **An app ID you don't recognise?** Look it up before disabling. When in doubt, leave it on.
* **Keys:** turn on key logging (`touch /tmp/cc_keylog`) and press each button to find your codes.

## Report your model

Open an issue with the **Compatibility report** template. Include your model and firmware (from the first
line of `inventory.sh`), what worked and what didn't. Please leave out your serial number and network
details.

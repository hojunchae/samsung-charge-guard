# Samsung Charge Guard

[한국어 README](README_KO.md)

Samsung Charge Guard is a small root script for Samsung Galaxy devices. It limits charging around a configurable battery percentage while trying to avoid the Wi-Fi/SSH disconnect issue caused by aggressive power-state changes.

The script was designed for a setup where a Galaxy device runs Termux SSH and must remain reachable over Wi-Fi.

## What it does

Default policy:

- At or above **80%**: set `store_mode=1` to stop charging.
- At or below **78%**: set `store_mode=0` to allow charging.
- Always keep `batt_slate_mode=0`.
- Optionally keep Wi-Fi power saving off using:
  - `cmd wifi force-low-latency-mode enabled`
  - `iw dev <iface> set power_save off`

## Why `store_mode`?

Some Samsung kernels expose multiple battery control nodes. A common charge-limiter approach uses `batt_slate_mode=1`, but on some devices this makes Android report that external power is gone:

```text
mIsPowered=false
mPlugType=0
status=Discharging
```

That can trigger screen-off Wi-Fi suspend behavior and break long-lived SSH sessions.

This project intentionally avoids using `batt_slate_mode=1`. It uses:

```text
/sys/class/power_supply/battery/store_mode
```

and keeps:

```text
/sys/class/power_supply/battery/batt_slate_mode = 0
```

On the tested Samsung device, `store_mode=1` stopped battery charging while Android still reported external power as connected:

```text
status=Discharging
store_mode=1
batt_slate_mode=0
mIsPowered=true
mPlugType=1
current_now=0
```

## Important behavior

With `store_mode=1`, the phone may continue running from external power. That means the battery may **hold near the current percentage** instead of actively discharging.

Example:

- If you start at 88%, it may stay around 88%.
- If you first unplug and let it drain to 70%, then plug in, it should charge until around 80% and then stop there.

This is expected. It is a stability-first design, not a forced 78-80 discharge cycle.

## Requirements

- Root access
- Magisk-compatible `/data/adb/service.d` boot scripts
- Samsung kernel exposing:
  - `/sys/class/power_supply/battery/store_mode`
  - `/sys/class/power_supply/battery/batt_slate_mode`
- Optional but recommended:
  - `/system/bin/iw`, `/vendor/bin/iw`, or Termux `iw`

## Installation

From Termux or another shell:

```sh
unzip samsung-charge-guard.zip
cd samsung-charge-guard
su -c "sh $(pwd)/scripts/install.sh"
```

Check status:

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

Watch logs:

```sh
su -c 'tail -f /data/local/tmp/samsung-charge-guard.log'
```

## Configuration

The installer creates:

```text
/data/adb/samsung-charge-guard.conf
```

Default:

```sh
START=78
STOP=80
INTERVAL=60
BOOT_DELAY=60
WIFI_GUARD=1
STOP_BCL=1
```

Edit it with root:

```sh
su -c 'vi /data/adb/samsung-charge-guard.conf'
```

Restart:

```sh
su -c 'pkill -f samsung-charge-guard.sh'
su -c 'BOOT_DELAY=0 /data/adb/samsung-charge-guard.sh >/data/local/tmp/samsung-charge-guard.service.log 2>&1 &'
```

## Commands

Run one policy pass:

```sh
su -c '/data/adb/samsung-charge-guard.sh once'
```

Show status:

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

Reset charging nodes:

```sh
su -c '/data/adb/samsung-charge-guard.sh reset'
```

Uninstall:

```sh
su -c "sh $(pwd)/scripts/uninstall.sh"
```

## Notes about Battery Charge Limiter

If you use MuntashirAkon's BatteryChargeLimiter, do not run both tools at the same time. This script can force-stop that package at startup when:

```sh
STOP_BCL=1
```

Set `STOP_BCL=0` if you do not want that behavior.

## Safety notes

This script writes to `/sys/class/power_supply`. Wrong values may cause unexpected battery or power behavior.

Before using it unattended, verify these values while plugged in:

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

Good target state at or above STOP:

```text
store_mode=1
batt_slate_mode=0
mIsPowered=true
mPlugType=1
Wi-Fi power save: off
```

## Project layout

```text
samsung-charge-guard/
├── README.md
├── README_KO.md
├── LICENSE
├── docs/
│   └── samsung-power-nodes.md
└── scripts/
    ├── install.sh
    ├── samsung-charge-guard.sh
    ├── status.sh
    └── uninstall.sh
```

## License

MIT

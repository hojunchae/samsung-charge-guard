# Samsung power nodes

This project is based on observed behavior on a Samsung Galaxy device.

## Preferred node

```text
/sys/class/power_supply/battery/store_mode
```

Observed behavior:

- `store_mode=0`: charging is allowed.
- `store_mode=1`: charging is blocked.
- Android can still report external power as connected:
  - `mIsPowered=true`
  - `mPlugType=1`

This is useful for devices running Termux SSH, because Android does not treat the phone as fully unplugged.

## Node intentionally avoided

```text
/sys/class/power_supply/battery/batt_slate_mode
```

Observed risk:

- `batt_slate_mode=1` may make Android report:
  - `mIsPowered=false`
  - `mPlugType=0`
  - `status=Discharging`

That can make Wi-Fi power management more aggressive when the screen is off.

## Wi-Fi guard

The script tries to keep Wi-Fi awake by running:

```sh
cmd wifi force-low-latency-mode enabled
iw dev <iface> set power_save off
```

It attempts all available `iw` paths:

```text
/system/bin/iw
/vendor/bin/iw
/data/data/com.termux/files/usr/bin/iw
```

## Verification commands

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
su -c 'dumpsys power | grep -E "mIsPowered|mPlugType|mBatteryLevel"'
su -c 'iw dev wlan0 get power_save'
```

#!/system/bin/sh
set -eu

if [ "$(id -u)" != "0" ]; then
  echo "Run as root, for example:"
  echo "  su -c 'sh $(pwd)/scripts/uninstall.sh'"
  exit 1
fi

SCRIPT="/data/adb/samsung-charge-guard.sh"
SERVICE="/data/adb/service.d/99-samsung-charge-guard.sh"
CONF="/data/adb/samsung-charge-guard.conf"

pkill -f samsung-charge-guard.sh >/dev/null 2>&1 || true

if [ -x "$SCRIPT" ]; then
  "$SCRIPT" reset >/dev/null 2>&1 || true
else
  echo 0 > /sys/class/power_supply/battery/store_mode 2>/dev/null || true
  echo 0 > /sys/class/power_supply/battery/batt_slate_mode 2>/dev/null || true
  echo 0 > /sys/class/power_supply/battery/input_suspend 2>/dev/null || true
fi

rm -f "$SCRIPT" "$SERVICE"

echo "Removed samsung-charge-guard script and boot service."
echo "Config was kept at: $CONF"
echo "Remove it manually if you no longer need it:"
echo "  su -c 'rm -f $CONF'"

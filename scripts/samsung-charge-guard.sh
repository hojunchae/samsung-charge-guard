#!/system/bin/sh
# Samsung Charge Guard
# Root-only Samsung charge limiter using store_mode for charging stop and
# keeping batt_slate_mode=0 to preserve Android external-power state.

CONFIG="${CONFIG:-/data/adb/samsung-charge-guard.conf}"
[ -f "$CONFIG" ] && . "$CONFIG"

START="${START:-78}"
STOP="${STOP:-80}"
INTERVAL="${INTERVAL:-60}"
BOOT_DELAY="${BOOT_DELAY:-60}"
WIFI_GUARD="${WIFI_GUARD:-1}"
STOP_BCL="${STOP_BCL:-1}"

LOG="${LOG:-/data/local/tmp/samsung-charge-guard.log}"
STATE="${STATE:-/data/local/tmp/samsung-charge-guard.state}"

export PATH="/system/bin:/system/xbin:/vendor/bin:/odm/bin:/product/bin:/data/data/com.termux/files/usr/bin:$PATH"
export LD_LIBRARY_PATH="/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH"

require_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "This script must run as root."
    echo "Example: su -c '$0 status'"
    exit 1
  fi
}

log() {
  echo "$(date '+%F %T') $*" >> "$LOG"
}

write_node() {
  f="$1"
  v="$2"
  [ -e "$f" ] || return 1
  echo "$v" > "$f" 2>/dev/null
}

read_node() {
  f="$1"
  [ -e "$f" ] || return 1
  cat "$f" 2>/dev/null
}

capacity() {
  read_node /sys/class/power_supply/battery/capacity | tr -dc '0-9'
}

android_powered() {
  dumpsys power 2>/dev/null | grep -q 'mIsPowered=true' && return 0
  dumpsys battery 2>/dev/null | grep -Eq 'AC powered: true|USB powered: true|Wireless powered: true' && return 0
  return 1
}

reset_bad_nodes() {
  # Avoid nodes that can make Android think external power was disconnected.
  write_node /sys/class/power_supply/battery/batt_slate_mode 0
  write_node /sys/class/power_supply/battery/input_suspend 0
}

wifi_guard() {
  [ "$WIFI_GUARD" = "1" ] || return 0
  cmd wifi force-low-latency-mode enabled >/dev/null 2>&1
  for IW in /system/bin/iw /vendor/bin/iw /data/data/com.termux/files/usr/bin/iw; do
    [ -x "$IW" ] || continue
    for i in $($IW dev 2>/dev/null | awk '/Interface/ {print $2}'); do
      "$IW" dev "$i" set power_save off >/dev/null 2>&1
    done
  done
}

set_charge_on() {
  write_node /sys/class/power_supply/battery/store_mode 0
  write_node /sys/class/power_supply/battery/batt_slate_mode 0
  echo "on" > "$STATE"
  log "charge_on store_mode=0 batt_slate_mode=0"
}

set_charge_off() {
  write_node /sys/class/power_supply/battery/batt_slate_mode 0
  write_node /sys/class/power_supply/battery/store_mode 1
  sleep 2
  if ! android_powered; then
    log "unsafe: Android reports not powered after store_mode=1; reverting"
    write_node /sys/class/power_supply/battery/store_mode 0
    write_node /sys/class/power_supply/battery/batt_slate_mode 0
    echo "on" > "$STATE"
    return 1
  fi
  echo "off" > "$STATE"
  log "charge_off store_mode=1 batt_slate_mode=0"
}

apply_policy() {
  cap="$(capacity)"
  [ -n "$cap" ] || return 1
  old_state="$(cat "$STATE" 2>/dev/null)"
  [ -n "$old_state" ] || old_state="on"

  if [ "$cap" -ge "$STOP" ]; then
    set_charge_off
  elif [ "$cap" -le "$START" ]; then
    set_charge_on
  else
    if [ "$old_state" = "off" ]; then
      set_charge_off
    else
      set_charge_on
    fi
  fi
}

reset_all() {
  write_node /sys/class/power_supply/battery/store_mode 0
  write_node /sys/class/power_supply/battery/batt_slate_mode 0
  write_node /sys/class/power_supply/battery/input_suspend 0
  rm -f "$STATE"
  log "reset: store_mode=0 batt_slate_mode=0"
}

status_report() {
  echo "===== samsung-charge-guard ====="
  echo "CONFIG=$CONFIG"
  echo "START=$START STOP=$STOP INTERVAL=$INTERVAL WIFI_GUARD=$WIFI_GUARD STOP_BCL=$STOP_BCL"
  echo "state=$(cat "$STATE" 2>/dev/null)"
  echo
  echo "===== battery ====="
  for f in \
    /sys/class/power_supply/battery/capacity \
    /sys/class/power_supply/battery/status \
    /sys/class/power_supply/battery/online \
    /sys/class/power_supply/battery/store_mode \
    /sys/class/power_supply/battery/batt_slate_mode \
    /sys/class/power_supply/battery/input_suspend \
    /sys/class/power_supply/battery/current_now \
    /sys/class/power_supply/battery/batt_current_ua_now \
    /sys/class/power_supply/battery/batt_current_ua_avg
  do
    [ -e "$f" ] && printf "%s=" "$f" && cat "$f"
  done

  echo
  echo "===== power ====="
  dumpsys power 2>/dev/null | grep -E 'mWakefulness|mIsPowered|mPlugType|mBatteryLevel|Battery Saver is currently' | head -n 30

  echo
  echo "===== wifi power save ====="
  for IW in /system/bin/iw /vendor/bin/iw /data/data/com.termux/files/usr/bin/iw; do
    [ -x "$IW" ] || continue
    echo "iw=$IW"
    for i in $($IW dev 2>/dev/null | awk '/Interface/ {print $2}'); do
      echo "===== $i ====="
      "$IW" dev "$i" get power_save 2>/dev/null
    done
    break
  done

  echo
  echo "===== recent log ====="
  tail -n 80 "$LOG" 2>/dev/null
}

require_root

case "$1" in
  reset)
    reset_all
    exit 0
    ;;
  status)
    status_report
    exit 0
    ;;
  once)
    reset_bad_nodes
    wifi_guard
    apply_policy
    exit 0
    ;;
esac

[ "$STOP_BCL" = "1" ] && am force-stop io.github.muntashirakon.bcl >/dev/null 2>&1

sleep "$BOOT_DELAY"
log "starting: start=$START stop=$STOP interval=$INTERVAL wifi_guard=$WIFI_GUARD"

while true; do
  reset_bad_nodes
  wifi_guard
  apply_policy
  cap="$(capacity)"
  st="$(cat "$STATE" 2>/dev/null)"
  sm="$(cat /sys/class/power_supply/battery/store_mode 2>/dev/null)"
  sl="$(cat /sys/class/power_supply/battery/batt_slate_mode 2>/dev/null)"
  log "cap=$cap state=$st store_mode=$sm batt_slate_mode=$sl"
  sleep "$INTERVAL"
done

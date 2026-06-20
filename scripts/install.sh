#!/system/bin/sh
set -eu

if [ "$(id -u)" != "0" ]; then
  echo "Run as root, for example:"
  echo "  su -c 'sh $(pwd)/scripts/install.sh'"
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SRC="$SCRIPT_DIR/samsung-charge-guard.sh"
DEST="/data/adb/samsung-charge-guard.sh"
CONF="/data/adb/samsung-charge-guard.conf"
SERVICE="/data/adb/service.d/99-samsung-charge-guard.sh"

if [ ! -f "$SRC" ]; then
  echo "Missing $SRC"
  exit 1
fi

mkdir -p /data/adb/service.d /data/local/tmp

cp "$SRC" "$DEST"
chmod 755 "$DEST"

if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<'EOF'
# samsung-charge-guard configuration
# START: allow charging at or below this percentage.
# STOP:  stop charging at or above this percentage.
START=78
STOP=80
INTERVAL=60
BOOT_DELAY=60
WIFI_GUARD=1
STOP_BCL=1
EOF
  chmod 644 "$CONF"
fi

cat > "$SERVICE" <<'EOF'
#!/system/bin/sh
CONFIG="/data/adb/samsung-charge-guard.conf"
[ -f "$CONFIG" ] && . "$CONFIG"
export CONFIG START STOP INTERVAL BOOT_DELAY WIFI_GUARD STOP_BCL
/data/adb/samsung-charge-guard.sh >/data/local/tmp/samsung-charge-guard.service.log 2>&1 &
exit 0
EOF

chmod 755 "$SERVICE"

pkill -f samsung-charge-guard.sh >/dev/null 2>&1 || true
CONFIG="$CONF" BOOT_DELAY=0 "$DEST" >/data/local/tmp/samsung-charge-guard.service.log 2>&1 &

echo "Installed samsung-charge-guard."
echo "Config:  $CONF"
echo "Service: $SERVICE"
echo
echo "Check status:"
echo "  su -c '/data/adb/samsung-charge-guard.sh status'"
echo
echo "View log:"
echo "  su -c 'tail -f /data/local/tmp/samsung-charge-guard.log'"

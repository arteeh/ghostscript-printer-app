#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${PORT:-}" && ! "$PORT" =~ ^[0-9]+$ ]]; then
  printf 'PORT must be numeric\n' >&2
  exit 64
fi

state_dir=/var/lib/ghostscript-printer-app
mkdir -p "$state_dir/ppd" "$state_dir/spool" "$state_dir/usb" "$state_dir/cups/ssl" /run/dbus /run/avahi-daemon /run/ghostscript-printer-app

export BACKEND_DIR=/usr/lib/ghostscript-printer-app/backend
export CUPS_SERVERBIN=/usr/lib/ghostscript-printer-app
export CUPS_SERVERROOT="$state_dir/cups"
export FILTER_DIR=/usr/lib/ghostscript-printer-app/filter
export PPDC_DATADIR=/usr/share/ppdc
export PPD_PATHS="/usr/share/ppd/:$state_dir/ppd/"
export SPOOL_DIR="$state_dir/spool"
export STATE_DIR="$state_dir"
export STATE_FILE="$state_dir/ghostscript-printer-app.state"
export TESTPAGE_DIR=/usr/share/ghostscript-printer-app
export TMPDIR=/tmp
export USB_QUIRK_DIR="$state_dir"

children=()
stop_children() {
  local pid
  for pid in "${children[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  wait "${children[@]}" 2>/dev/null || true
}
trap stop_children TERM INT EXIT

dbus-daemon --system --nofork --nopidfile &
children+=("$!")
for _ in $(seq 1 30); do
  [[ -S /run/dbus/system_bus_socket ]] && break
  sleep 0.1
done
[[ -S /run/dbus/system_bus_socket ]]

avahi-daemon --no-drop-root --no-chroot &
children+=("$!")
for _ in $(seq 1 30); do
  [[ -f /run/avahi-daemon/pid ]] && break
  sleep 0.1
done
[[ -f /run/avahi-daemon/pid ]]

args=(-o "log-file=$state_dir/ghostscript-printer-app.log")
if [[ -n "${PORT:-}" ]]; then
  args+=(-o "server-port=$PORT")
fi
ghostscript-printer-app "${args[@]}" server &
children+=("$!")

wait -n "${children[@]}"
status=$?
stop_children
trap - TERM INT EXIT
exit "$status"

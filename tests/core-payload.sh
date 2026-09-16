#!/usr/bin/env bash
set -euo pipefail

image="ghcr.io/projectbluefin/ghostscript-printer-app:build"
name="ghostscript-printer-app-payload"
port="${PORT:-18010}"
state_dir="$(mktemp -d)"

cleanup() {
  podman rm -f "$name" >/dev/null 2>&1 || true
  podman unshare rm -rf "$state_dir"
}
trap cleanup EXIT

just build

podman run --rm --entrypoint /usr/bin/bash "$image" -c '
  set -euo pipefail
  test -L /usr/lib/ghostscript-printer-app
  test "$(readlink /usr/lib/ghostscript-printer-app)" = /usr/lib/cups
  test -f /usr/share/ghostscript-printer-app/testpage.ps
  test -x /usr/bin/python3
  test -x /usr/bin/xz

  filters=(foomatic-rip gstoraster pdftops rastertoescpx rastertopclx)
  for filter in "${filters[@]}"; do
    path="/usr/lib/cups/filter/$filter"
    test -x "$path"
    dependencies="$(ldd "$path")"
    [[ "$dependencies" != *"not found"* ]]
  done

  application_dependencies="$(ldd /usr/bin/ghostscript-printer-app)"
  [[ "$application_dependencies" != *"not found"* ]]

  archives=(cups-filters-ppds foomatic-ppds manufacturer-ppds)
  for archive_name in "${archives[@]}"; do
    archive="/usr/share/ppd/$archive_name"
    test -x "$archive"
    mapfile -t entries < <("$archive" list)
    ((${#entries[@]} > 0))
    uri="${entries[0]%% *}"
    uri="${uri#\"}"
    uri="${uri%\"}"
    ppd="$("$archive" cat "$uri")"
    [[ "$ppd" == *"*PPD-Adobe:"* ]]
  done
'

chmod 0777 "$state_dir"
podman run -d \
  --name "$name" \
  --network host \
  -e PORT="$port" \
  -v "$state_dir:/var/lib/ghostscript-printer-app:Z" \
  "$image" >/dev/null

for _ in $(seq 1 60); do
  http="$(curl --fail --silent --show-error "http://127.0.0.1:${port}/" 2>/dev/null || true)"
  https="$(curl --insecure --fail --silent --show-error "https://127.0.0.1:${port}/" 2>/dev/null || true)"
  if [[ "$http" == *'<title>Ghostscript Printer Application</title>'* && "$https" == *'<title>Ghostscript Printer Application</title>'* ]]; then
    printf 'OK: core driver payload and HTTPS are available\n'
    exit 0
  fi
  sleep 1
done

podman logs "$name" >&2
printf 'FAIL: HTTP/HTTPS readiness was not reached\n' >&2
exit 1

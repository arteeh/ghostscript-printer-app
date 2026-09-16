#!/usr/bin/env bash
set -euo pipefail


image="ghcr.io/projectbluefin/ghostscript-printer-app:build"
name="ghostscript-printer-app-raster-drivers"
port="${PORT:-18020}"
state_dir="$(mktemp -d)"

cleanup() {
  podman rm -f "$name" >/dev/null 2>&1 || true
  podman unshare rm -rf "$state_dir"
}
trap cleanup EXIT
wait_for_http() {
  for _ in $(seq 1 60); do
    curl --fail --silent --show-error "http://127.0.0.1:${port}/" >/dev/null 2>&1 && return 0
    sleep 1
  done
  podman logs "$name" >&2
  return 1
}

just build

podman run --rm --entrypoint /usr/bin/bash "$image" -c '
  set -euo pipefail
  executables=(c2050 cjet min12xxw pnm2ppa calibrate_ppa)
  for executable in "${executables[@]}"; do
    path="/usr/bin/$executable"
    test -x "$path"
    dependencies="$(ldd "$path")"
    [[ "$dependencies" != *"not found"* ]]
  done
  test -f /usr/share/ghostscript-printer-app/pnm2ppa.conf
  ! command -v cc
  ! command -v gcc
  ! command -v make
  ! command -v autoconf

  assert_output() {
    local first="$1" second="$2" byte_count="$3" expected="$4"
    local first_hash second_hash
    test -s "$first"
    [[ "$(od -An -tx1 -N "$byte_count" "$first")" == "$expected" ]]
    read -r first_hash _ < <(sha256sum "$first")
    read -r second_hash _ < <(sha256sum "$second")
    [[ "$first_hash" == "$second_hash" ]]
  }

  foomatic_entries="$(/usr/share/ppd/foomatic-ppds list)"
  for driver in c2050 cjet min12xxw pnm2ppa; do
    [[ "$foomatic_entries" == *"-${driver}.ppd"* ]]
  done
  printf "OK: driver executables and PPD entries are present\n"

  gs -q -dSAFER -dNOPAUSE -dBATCH -sDEVICE=bitcmyk -g2480x3507 -r300 \
    -sOutputFile=/tmp/c2050.cmyk \
    /usr/share/ghostscript-printer-app/testpage.ps
  c2050 </tmp/c2050.cmyk >/tmp/c2050.prn
  c2050 </tmp/c2050.cmyk >/tmp/c2050-repeat.prn
  assert_output /tmp/c2050.prn /tmp/c2050-repeat.prn 3 " 1b 2a 80"
  printf "OK: c2050 conversion\n"

  gs -q -dSAFER -dNOPAUSE -dBATCH -sDEVICE=ljet3 -r300 \
    -sOutputFile=/tmp/cjet.pcl \
    /usr/share/ghostscript-printer-app/testpage.ps
  cjet -q </tmp/cjet.pcl >/tmp/cjet.prn
  cjet -q </tmp/cjet.pcl >/tmp/cjet-repeat.prn
  assert_output /tmp/cjet.prn /tmp/cjet-repeat.prn 4 " 1b 3b 1b 3c"
  printf "OK: cjet conversion\n"

  gs -q -dSAFER -dNOPAUSE -dBATCH -sDEVICE=pbmraw -r600 \
    -sOutputFile=/tmp/min12xxw.pbm \
    /usr/share/ghostscript-printer-app/testpage.ps
  min12xxw -m 1200W </tmp/min12xxw.pbm >/tmp/min12xxw.prn
  min12xxw -m 1200W </tmp/min12xxw.pbm >/tmp/min12xxw-repeat.prn
  assert_output /tmp/min12xxw.prn /tmp/min12xxw-repeat.prn 4 " 1b 40 00 02"
  printf "OK: min12xxw conversion\n"
'

chmod 0777 "$state_dir"
podman run -d \
  --name "$name" \
  --network host \
  -e PORT="$port" \
  -v "$state_dir:/var/lib/ghostscript-printer-app:Z" \
  "$image" >/dev/null
wait_for_http
podman exec "$name" /usr/bin/bash -c '
  set -euo pipefail
  config=/var/lib/ghostscript-printer-app/pnm2ppa/pnm2ppa.conf
  test -f "$config"
  while IFS= read -r line; do
    if [[ "$line" == version\ 710* ]]; then
      config_initialized=1
    fi
  done < "$config"
  [[ "${config_initialized:-0}" == 1 ]]
  calibrate_ppa --center > /tmp/pnm2ppa.ppm || test -s /tmp/pnm2ppa.ppm
  pnm2ppa --bw -i /tmp/pnm2ppa.ppm -o /tmp/pnm2ppa.prn
  pnm2ppa --bw -i /tmp/pnm2ppa.ppm -o /tmp/pnm2ppa-repeat.prn
  test -s /tmp/pnm2ppa.prn
  [[ "$(od -An -tx1 -N 4 /tmp/pnm2ppa.prn)" == " 24 01 00 18" ]]
  read -r first_hash _ < <(sha256sum /tmp/pnm2ppa.prn)
  read -r second_hash _ < <(sha256sum /tmp/pnm2ppa-repeat.prn)
  [[ "$first_hash" == "$second_hash" ]]
  printf "OK: pnm2ppa conversion and initial configuration\n"
  printf "# persistence-probe\n" >> "$config"
'

podman stop --time 15 "$name" >/dev/null
podman rm "$name" >/dev/null
podman run -d \
  --name "$name" \
  --network host \
  -e PORT="$port" \
  -v "$state_dir:/var/lib/ghostscript-printer-app:Z" \
  "$image" >/dev/null
wait_for_http
podman exec "$name" /usr/bin/bash -c '
  while IFS= read -r line; do
    [[ "$line" == "# persistence-probe" ]] && exit 0
  done < /var/lib/ghostscript-printer-app/pnm2ppa/pnm2ppa.conf
  exit 1
'

printf 'OK: standalone raster drivers execute and pnm2ppa state persists\n'

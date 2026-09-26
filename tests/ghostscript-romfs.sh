#!/usr/bin/env bash
# Rule 14: full-size IJS pages exposed corrupt ROMFS ICC reads with zlib-ng.
set -euo pipefail

image="ghcr.io/projectbluefin/ghostscript-printer-app:build"
sink_port="${ROMFS_SINK_PORT:-19050}"
work="$(mktemp -d)"
sink_pid=""
cleanup() {
  if [[ -n "$sink_pid" ]]; then
    kill "$sink_pid" 2>/dev/null || true
    wait "$sink_pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# Always build from this checkout's graph. Never test an unrelated pulled image.
just build

# Bound accept as well as receive time so a broken backend cannot hang the gate.
timeout 120 python3 tests/socket-sink.py "$sink_port" "$work/output.pcl" &
sink_pid=$!
# The backend must find the sink listening, not race its startup.
wait_for_sink() {
  for _ in $(seq 1 100); do
    [[ -n "$(ss -Htln "sport = :${sink_port}")" ]] && return 0
    kill -0 "$sink_pid" 2>/dev/null || break
    sleep 0.1
  done
  printf 'FAIL: socket sink did not listen on port %s\n' "$sink_port" >&2
  return 1
}
wait_for_sink

podman run --rm --network host --entrypoint /usr/bin/bash \
  -e ROMFS_SINK_PORT="$sink_port" "$image" -c '
  set -euo pipefail
  export PATH=/usr/lib/cups/filter:/usr/bin:/bin
  export TMPDIR=/tmp
  export PPD=/tmp/pxljr.ppd
  /usr/share/ppd/pxljr-ppds cat \
    pxljr-ppds:0/HP-Color_LaserJet_3500-pxljr.ppd > "$PPD"
  grep -qx "\*DefaultPageSize: Letter" "$PPD"

  # Read the actual compiled-in profile through EOF, including its ICC header.
  # This must use gs from the rebuilt appliance, not a host Ghostscript.
  gs -q -dSAFER -dNODISPLAY -dBATCH -c "
    /profile (%rom%iccprofiles/default_rgb.icc) (r) file def
    profile 128 string readstring not { 1 .quit } if
    36 4 getinterval (acsp) ne { 1 .quit } if
    { profile 4096 string readstring exch pop not { exit } if } loop
    profile closefile
  "

  # No PageSize option or reduced -g geometry: preserve the default Letter
  # page and normal resolution that trigger lazy profile loading in IJS.
  printf "%s\n" \
    "%!PS-Adobe-3.0" "%%Pages: 1" "%%Page: 1 1" \
    "1 0 0 setrgbcolor 36 36 540 720 rectfill" \
    "0 0 1 setrgbcolor 72 72 468 648 rectfill" \
    "showpage" "%%EOF" > /tmp/letter.ps
  if ! foomatic-rip 1 nonroot romfs-letter 1 "" /tmp/letter.ps \
      3</dev/null 4<>/dev/null > /tmp/letter.pcl 2>/tmp/letter.log; then
    cat /tmp/letter.log >&2
    exit 1
  fi
  cat /tmp/letter.log >&2
  if grep -E "free\(\): invalid size|s_block_read_process" /tmp/letter.log; then
    exit 1
  fi
  test -s /tmp/letter.pcl
  [[ "$(od -An -tx1 -N 16 /tmp/letter.pcl)" == " 1b 25 2d 31 32 33 34 35 58 40 50 4a 4c 20 53 45" ]]
  # Exercise the shipped backend too; successful rendering alone is not a
  # print-to-socket result. The sink consumes real pxljr PCL XL bytes.
  DEVICE_URI="socket://127.0.0.1:${ROMFS_SINK_PORT}" \
    timeout 90 /usr/lib/cups/backend/socket \
    1 nonroot romfs-letter 1 "" /tmp/letter.pcl 3</dev/null 4<>/dev/null
  sha256sum /tmp/letter.pcl
' > "$work/render.sha256"

wait "$sink_pid"
sink_pid=""
read -r rendered_hash _ < "$work/render.sha256"
read -r received_hash _ < <(sha256sum "$work/output.pcl")
[[ "$rendered_hash" == "$received_hash" ]]
printf 'OK: bundled ROMFS ICC profile and default Letter pxljr conversion reach the socket sink intact\n'

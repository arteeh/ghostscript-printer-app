#!/usr/bin/env bash
set -euo pipefail

podman_binary="$(command -v podman)"
if ! "$podman_binary" info >/dev/null 2>&1; then
  podman() { sudo "$podman_binary" "$@"; }
fi

image="ghcr.io/projectbluefin/ghostscript-printer-app:build"
size_limit_bytes="${IMAGE_SIZE_LIMIT_BYTES:-524288000}"

just build

advertised_ghostscript_drivers="$(python3 - <<'PY'
import pathlib
import re

readme = pathlib.Path("README.md").read_text()
match = re.search(
    r"### Contained Printer Drivers.*?- \*\*Ghostscript built-in\*\*:\s*```(.*?)```",
    readme,
    re.DOTALL,
)
if match is None:
    raise SystemExit("FAIL: README Ghostscript driver inventory is missing")
print(" ".join(match.group(1).replace(",", " ").split()))
PY
)"

read -r fsdk_version fsdk_ref < <(python3 - <<'PY'
import pathlib
import re

junction = pathlib.Path("elements/freedesktop-sdk.bst").read_text()
match = re.search(r"ref: freedesktop-sdk-(.+?)-0-g([0-9a-f]{40})$", junction, re.MULTILINE)
if match is None:
    raise SystemExit("FAIL: pinned freedesktop-sdk release is missing")
print(*match.groups())
PY
)

size_bytes="$(podman image inspect "$image" --format '{{.Size}}')"
if ((size_bytes > size_limit_bytes)); then
  printf 'FAIL: uncompressed image is %s bytes; limit is %s bytes\n' "$size_bytes" "$size_limit_bytes" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) expected_arch=amd64 ;;
  aarch64) expected_arch=arm64 ;;
  *) printf 'FAIL: unsupported verification architecture %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

test "$(podman image inspect "$image" --format '{{.Architecture}}')" = "$expected_arch"
test "$(podman image inspect "$image" --format '{{.Config.User}}')" = 65532:65532
test "$(podman image inspect "$image" --format '{{json .Config.Entrypoint}}')" = '["/usr/bin/catatonit","--","/usr/bin/bash","/usr/libexec/ghostscript-printer-app/container-entrypoint"]'
test "$(podman image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.title"}}')" = ghostscript-printer-app
test "$(podman image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.source"}}')" = https://github.com/projectbluefin/ghostscript-printer-app
test "$(podman image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.licenses"}}')" = Apache-2.0
application_version="$(podman run --rm --entrypoint /usr/bin/ghostscript-printer-app "$image" --version)"
test "$application_version" = "$(< VERSION)"
test "$(podman image inspect "$image" --format '{{index .Config.Labels "org.opencontainers.image.version"}}')" = "$application_version"
test "$(podman image inspect "$image" --format '{{index .Config.Labels "io.projectbluefin.fsdk.version"}}')" = "$fsdk_version"
test "$(podman image inspect "$image" --format '{{index .Config.Labels "io.projectbluefin.fsdk.ref"}}')" = "$fsdk_ref"

podman run --rm --user 0:0 --entrypoint /usr/bin/bash \
  -e ADVERTISED_GHOSTSCRIPT_DRIVERS="$advertised_ghostscript_drivers" \
  "$image" -c '
  set -euo pipefail

  backends=(dnssd ipp ipps lpd snmp socket usb)
  for backend in "${backends[@]}"; do
    test -x "/usr/lib/cups/backend/$backend"
  done

  filters=(
    c2esp c2espC command2esp command2foo2lava-pjl
    foomatic-rip gstoraster pdftopdffx pdftops
    pstoqpdl raster2dymolm raster2dymolw rastertobrlaser
    rastertoepson rastertoescpx rastertohp rastertolabel
    rastertookidotmatrix rastertookimonochrome rastertopclx
    rastertoptch rastertoqpdl rastertosag-gdi
  )
  for filter in "${filters[@]}"; do
    test -x "/usr/lib/cups/filter/$filter"
  done

  commands=(
    c2050 cjet foo2zjs-wrapper gs hpijs m2300w-wrapper
    min12xxw pnm2ppa psnup ijs_pxljr
  )
  for command in "${commands[@]}"; do
    command -v "$command" >/dev/null
  done

  ppd_providers=(
    KodakESP_16.drv KodakESP_C_07.drv brlaser.drv
    cups-filters-ppds dymo-ppds foo2zjs-ppds foomatic-ppds
    fxlinuxprint-ppds m2300w-ppds manufacturer-ppds oki-ppds
    ptouch-ppds pxljr-ppds rastertosag-gdi-ppds splix-ppds
  )
  for provider in "${ppd_providers[@]}"; do
    test -e "/usr/share/ppd/$provider"
  done

  provider_contains() {
    local path="$1" marker="${2,,}" contents
    if [[ -x "$path" ]]; then
      contents="$("$path" list)"
    else
      contents="$(cat "$path")"
    fi
    if [[ "${contents,,}" != *"$marker"* ]]; then
      printf "FAIL: %s does not contain advertised family %s\n" "$path" "$2" >&2
      exit 1
    fi
  }
  provider_contains /usr/share/ppd/KodakESP_16.drv Kodak
  provider_contains /usr/share/ppd/KodakESP_C_07.drv Kodak
  provider_contains /usr/share/ppd/brlaser.drv Brother
  provider_contains /usr/share/ppd/cups-filters-ppds "PCL 6 CUPS"
  provider_contains /usr/share/ppd/dymo-ppds Dymo
  provider_contains /usr/share/ppd/foo2zjs-ppds Minolta
  provider_contains /usr/share/ppd/foomatic-ppds Foomatic
  provider_contains /usr/share/ppd/fxlinuxprint-ppds "Fuji Xerox"
  provider_contains /usr/share/ppd/m2300w-ppds "KONICA MINOLTA"
  for manufacturer in Gestetner InfoPrint Infotec Lanier NRG Ricoh Savin Samsung; do
    provider_contains /usr/share/ppd/manufacturer-ppds "$manufacturer"
  done
  provider_contains /usr/share/ppd/oki-ppds Oki
  provider_contains /usr/share/ppd/ptouch-ppds Brother
  provider_contains /usr/share/ppd/pxljr-ppds "HP Color LaserJet"
  provider_contains /usr/share/ppd/rastertosag-gdi-ppds Ricoh
  provider_contains /usr/share/ppd/splix-ppds Samsung
  provider_contains /usr/share/cups/drv/sample.drv Intellitech
  provider_contains /usr/share/cups/drv/sample.drv Zebra

  devices=" $(gs -h 2>&1 | tr "\n" " ") "
  foomatic_entries="$(/usr/share/ppd/foomatic-ppds list)"
  read -r -a ghostscript_drivers <<< "$ADVERTISED_GHOSTSCRIPT_DRIVERS"
  ((${#ghostscript_drivers[@]} > 0))
  for driver in "${ghostscript_drivers[@]}"; do
    if [[ "$devices" != *" $driver "* && "$foomatic_entries" != *"-$driver.ppd\""* ]]; then
      printf "FAIL: advertised Ghostscript driver %s has no device or PPD entry\n" "$driver" >&2
      exit 1
    fi
  done

  command -v bash >/dev/null
  command -v python3 >/dev/null
  for interpreter in perl ruby node lua tclsh wish; do
    ! command -v "$interpreter" >/dev/null 2>&1
  done
  for tool in apt apt-get apk dnf dpkg pacman rpm pip pip3 cc c++ gcc g++ clang make cmake meson ninja pkg-config autoconf automake libtool ld ar as nm objcopy ranlib strip; do
    ! command -v "$tool" >/dev/null 2>&1
  done

  python3 - <<"PY"
import os
import subprocess
import sys

forbidden = []
unresolved = []
for root, dirs, files in os.walk("/"):
    if root == "/":
        dirs[:] = [name for name in dirs if name not in {"dev", "proc", "run", "sys", "tmp"}]
    if root.startswith("/usr/share/licenses/"):
        dirs[:] = []
        continue
    if root == "/usr/include" or root.startswith("/usr/include/"):
        forbidden.extend(os.path.join(root, name) for name in files)
    if root == "/usr/lib/debug" or root.startswith("/usr/lib/debug/"):
        forbidden.extend(os.path.join(root, name) for name in files)
    for directory in dirs:
        if directory.lower() in {"test", "tests", "testing"}:
            forbidden.append(os.path.join(root, directory))
    for name in files:
        path = os.path.join(root, name)
        if name.endswith((".a", ".la")):
            forbidden.append(path)
        if os.path.islink(path):
            continue
        try:
            with open(path, "rb") as stream:
                is_elf = stream.read(4) == b"\x7fELF"
        except OSError as error:
            unresolved.append(f"{path}: audit failed: {error}")
            continue
        if not is_elf:
            continue
        result = subprocess.run(
            ["/usr/bin/ldd", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        output = result.stdout.strip()
        if "not found" in output:
            unresolved.append(f"{path}: {output}")
        elif result.returncode != 0 and "not a dynamic executable" not in output and "statically linked" not in output:
            unresolved.append(f"{path}: ldd exited {result.returncode}: {output}")

if forbidden:
    print("FAIL: forbidden runtime payload:\n" + "\n".join(forbidden), file=sys.stderr)
if unresolved:
    print("FAIL: unresolved ELF dependencies:\n" + "\n".join(unresolved), file=sys.stderr)
if forbidden or unresolved:
    raise SystemExit(1)
PY
'

printf 'OK: complete appliance inventory, metadata, size, and runtime closure (%s bytes)\n' "$size_bytes"

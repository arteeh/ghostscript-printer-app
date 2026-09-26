#!/usr/bin/env python3
"""Check one printer node with the appliance identity; never send USB commands."""
import argparse
import re
import subprocess
import sys

PROBE = """
import os, stat, sys
path = sys.argv[1]
try:
    if not stat.S_ISCHR(os.stat(path).st_mode):
        raise OSError('not a character device')
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    os.close(fd)
except OSError as error:
    print(f'{path}: {error}', file=sys.stderr)
    sys.exit(1)
"""
REMEDIATION = (
    "Check the selected /dev/bus/usb/BBB/DDD node after reconnecting; inspect "
    "host udev rules, device group and id output. Grant the service user read/write "
    "access through a printer-specific group rule and start a new login session. "
    "keep-groups requires crun. Check SELinux audit denials with your administrator. "
    "Do not retry with sudo, --privileged, or disabled security labeling. "
    "See docs/oci-physical-validation.md."
)


def check(image, device):
    if not re.fullmatch(r"/dev/bus/usb/[0-9]{3}/[0-9]{3}", device):
        raise ValueError("select a printer node: /dev/bus/usb/BBB/DDD")
    info = subprocess.run(
        ["podman", "info", "--format", "{{.Host.Security.Rootless}}"],
        check=True, capture_output=True, text=True,
    )
    if info.stdout.strip() != "true":
        raise ValueError("USB preflight requires rootless Podman")
    subprocess.run(
        ["podman", "run", "--rm", "--network", "host",
         "--device", "/dev/bus/usb", "--group-add", "keep-groups",
         "--user", "65532:65532", "--entrypoint", "/usr/bin/python3",
         image, "-c", PROBE, device], check=True,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="exact appliance image reference (prefer a digest)")
    parser.add_argument("device", help="printer node /dev/bus/usb/BBB/DDD")
    args = parser.parse_args()
    try:
        check(args.image, args.device)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: rootless USB preflight: {error}\n{REMEDIATION}", file=sys.stderr)
        return 1
    print("OK: rootless USB node opens read/write; physical printing remains unverified")
    return 0


if __name__ == "__main__":
    sys.exit(main())

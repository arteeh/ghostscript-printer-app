#!/usr/bin/env python3
"""Track repository-owned BuildStream sources and synchronize release metadata."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ELEMENTS = ROOT / "elements"
FSDK_ELEMENT = ELEMENTS / "freedesktop-sdk.bst"
IJS_ELEMENT = ELEMENTS / "printer-app" / "ijs.bst"
OCI_ELEMENT = ELEMENTS / "oci" / "ghostscript-printer-app.bst"
PLUGIN_ELEMENT = ELEMENTS / "plugins" / "buildstream-plugins-community.bst"
VERSION_FILE = ROOT / "VERSION"

SOURCE_BLOCK = re.compile(
    r"(?ms)^  - kind: (?P<kind>git_repo|cpan|tar)\n(?P<body>.*?)(?=^  - kind:|\Z)"
)
FSDK_REF = re.compile(r"^\s*ref: freedesktop-sdk-(.+?)-0-g([0-9a-f]{40})$", re.MULTILINE)
GHOSTSCRIPT_REF = re.compile(r"^\s*ref: ghostpdl-([0-9][^-\s]*)-\d+-g[0-9a-f]{40}$", re.MULTILINE)


def replace_one(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"expected one metadata field in {path}: {pattern}")
    if updated != text:
        path.write_text(updated)


def read_fsdk_ref() -> tuple[str, str]:
    match = FSDK_REF.search(FSDK_ELEMENT.read_text())
    if match is None:
        raise RuntimeError("freedesktop-sdk ref is not a release plus full commit")
    return match.group(1), match.group(2)


def fetch_ghostscript_version(fsdk_ref: str) -> str:
    url = (
        "https://gitlab.com/freedesktop-sdk/freedesktop-sdk/-/raw/"
        f"{fsdk_ref}/elements/components/ghostscript.bst"
    )
    with urllib.request.urlopen(url, timeout=30) as response:
        element = response.read().decode()
    match = GHOSTSCRIPT_REF.search(element)
    if match is None:
        raise RuntimeError("selected freedesktop-sdk has no parseable Ghostscript release ref")
    return match.group(1)


def refresh_plugin_tarball() -> None:
    with urllib.request.urlopen(
        "https://pypi.org/pypi/buildstream-plugins-community/json", timeout=30
    ) as response:
        metadata = json.load(response)
    version = metadata["info"]["version"]
    sdists = [item for item in metadata["releases"][version] if item["packagetype"] == "sdist"]
    if len(sdists) != 1:
        raise RuntimeError(f"expected one buildstream-plugins-community {version} sdist")
    sdist = sdists[0]
    url = f"pypi:source/b/buildstream-plugins-community/{sdist['filename']}"
    replace_one(PLUGIN_ELEMENT, r"^\s*url: pypi:.*$", f"    url: {url}")
    replace_one(PLUGIN_ELEMENT, r"^\s*ref: [0-9a-f]{{64}}$", f"    ref: {sdist['digests']['sha256']}")


def track_sources() -> None:
    subprocess.run(
        [
            "just",
            "bst",
            "source",
            "track",
            "--deps",
            "all",
            "oci/ghostscript-printer-app.bst",
        ],
        cwd=ROOT,
        check=True,
    )


def sync_fsdk_metadata() -> None:
    fsdk_version, fsdk_ref = read_fsdk_ref()
    ghostscript_version = fetch_ghostscript_version(fsdk_ref)
    current_version = VERSION_FILE.read_text().strip()
    match = re.fullmatch(r".+-([0-9]+)", current_version)
    if match is None:
        raise RuntimeError("VERSION must end in a numeric packaging revision")
    VERSION_FILE.write_text(f"{ghostscript_version}-{match.group(1)}\n")
    replace_one(IJS_ELEMENT, r"^\s*track: ghostpdl-.*$", f"    track: ghostpdl-{ghostscript_version}")
    replace_one(
        OCI_ELEMENT,
        r"^(\s*'io\.projectbluefin\.fsdk\.version': )'[^']+'$",
        rf"\1'{fsdk_version}'",
    )
    replace_one(
        OCI_ELEMENT,
        r"^(\s*'io\.projectbluefin\.fsdk\.ref': )'[^']+'$",
        rf"\1'{fsdk_ref}'",
    )
    subprocess.run(
        ["just", "bst", "source", "track", "printer-app/ijs.bst"],
        cwd=ROOT,
        check=True,
    )


def check_source_inventory() -> None:
    errors: list[str] = []
    count = 0
    for path in sorted(ELEMENTS.rglob("*.bst")):
        text = path.read_text()
        for source in SOURCE_BLOCK.finditer(text):
            count += 1
            kind = source.group("kind")
            body = source.group("body")
            relative = path.relative_to(ROOT)
            required = {
                "git_repo": ("url", "track", "ref"),
                "cpan": ("name", "suffix", "sha256sum"),
                "tar": ("url", "ref"),
            }[kind]
            missing = [key for key in required if re.search(rf"^\s*{key}:", body, re.MULTILINE) is None]
            if missing:
                errors.append(f"{relative}: {kind} source missing {', '.join(missing)}")
            ref = re.search(r"^\s*(?:ref|sha256sum):\s*([^\s]+)$", body, re.MULTILINE)
            if ref is None or re.search(r"[0-9a-f]{40,64}$", ref.group(1)) is None:
                errors.append(f"{relative}: {kind} source has no immutable integrity ref")
    if count == 0:
        errors.append("no external BuildStream sources found")
    if errors:
        raise RuntimeError("\n".join(errors))
    print(f"OK: {count} external BuildStream sources expose update and integrity metadata")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update", action="store_true", help="track sources and synchronize metadata")
    args = parser.parse_args()
    if args.update:
        refresh_plugin_tarball()
        track_sources()
        sync_fsdk_metadata()
    check_source_inventory()


if __name__ == "__main__":
    main()

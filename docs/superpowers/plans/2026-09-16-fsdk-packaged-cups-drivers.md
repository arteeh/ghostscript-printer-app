# FSDK Packaged CUPS Drivers Implementation Plan

**Goal:** Restore c2esp, Dymo, fxlinuxprint, Oki, pxljr, rastertosag-gdi, SpliX, brlaser, and P-Touch with discoverable driver data and executable conversion paths.

**Architecture:** One pinned element per source package. Elements install filters under `/usr/lib/ghostscript-printer-app/filter` and either pyppd archives or `.drv` descriptions under `/usr/share/ppd`. FSDK remains the sole CUPS/libcupsfilters/libppd owner. Minimal IJS/JBIG helper artifacts are allowed only where FSDK exposes no usable artifact. Shared runtime composition and verification stay centralized.

## Task 1: Build immutable driver artifacts

- [ ] Add c2esp at `90a09ca4927fca5e1ae08307cd3ca9c0f0ca5b5b`, apply and execute the existing libcupsfilters2 patch.
- [ ] Add Dymo at `e69dceba792dc23d2894d57b0468009e52109625` and generate `dymo-ppds`.
- [ ] Add fxlinuxprint at `3e640d5cf2881b01b6dab16e7d899290e61b0417` and generate `fxlinuxprint-ppds`.
- [ ] Add Oki at `9f48d5a6c5938126a5aa91a902668aa877c3c22b`, replacing confinement paths with real OCI paths, and generate `oki-ppds`.
- [ ] Add pxljr at `6b0dafe66965e5fa398733c04160bd6436d13254`, including the minimal IJS dependency and 3500/3550/3600 PPD archive.
- [ ] Add rastertosag-gdi at `6f4028f36f015692a602077b7060438d0bf9f634` and generate its PPD archive.
- [ ] Add SpliX at `505f24d43fdb86eaa41a44486e7ef88226bb2c0c`, including the minimal JBIG dependency, QPDL filters, and PPD archive.
- [ ] Add brlaser at `23117fe9e0266396e4791cdae84d979928aed135` with its filter and `.drv` description.
- [ ] Add P-Touch at `ccfa92351be3ce601f212048b174147a5496d8be` and generate only its Foomatic PPD archive.

## Task 2: Compose runtime and prove discovery

- [ ] Add all driver artifacts to `core-stack.bst`; keep toolchains, source databases, and generators build-only.
- [ ] Add an image-level `verify-packaged-drivers` command that checks filters, helper executables/libraries, PPD archives/descriptions, and complete ELF/interpreter closure.
- [ ] Start the real appliance and require representative driver names from every family in the Printer Application driver list.

## Task 3: Exercise conversion families

- [ ] Run c2esp's FSDK libcupsfilters2 path and require printer-language output.
- [ ] Exercise representative raster filters for Dymo, pxljr, SpliX, brlaser, and P-Touch with valid deterministic raster/input fixtures.
- [ ] Exercise shell/script families for Oki, fxlinuxprint, and rastertosag-gdi with inherited runtime paths and TMPDIR.
- [ ] Require stable protocol signatures and repeatable output digests; a successful process with empty output fails.

## Task 4: Verify and publish

- [ ] Run `just validate`, prior slice gates, `just verify-packaged-drivers`, workflow lint, shell syntax checks, and `git diff --check`.
- [ ] Review the full diff from `feat/fsdk-raster-drivers`.
- [ ] Resolve issue 05, commit the completed plan, push `feat/fsdk-packaged-drivers`, and open a stacked PR based on `feat/fsdk-raster-drivers`.

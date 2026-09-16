# FSDK Stateful Profile Drivers Implementation Plan

**Goal:** Restore HPIJS, foo2zjs, and m2300w with immutable builds, valid OCI paths, discoverable driver data, and persistent user-editable configuration/profile state.

**Architecture:** Add one pinned BuildStream element per upstream source. Build HPLIP in its minimal HPIJS-only configuration and keep its mutable `hplip.conf` under `/var/lib/ghostscript-printer-app/hplip`, reached through `/etc/hp/hplip.conf`. Build foo2zjs and m2300w against the existing FSDK CUPS/Ghostscript graph and the single repository-owned JBIG artifact. Their wrappers use `/usr` for executables and `/var/lib/ghostscript-printer-app/{foo2zjs,m2300w}` for profile data. Immutable defaults live under `/usr/share/ghostscript-printer-app/defaults`; the entrypoint copies only missing files into persistent state before starting the application.

## Task 1: Build immutable driver artifacts

- [x] Add HPLIP from `debian/3.26.4+dfsg0-3-0-gf27f786d5f1060cce7c92e42488bd5e5d00ba135`, configured for HPIJS only, and install only `hpijs`, its required libraries, and a valid default `hplip.conf` seed.
- [x] Add foo2zjs from `debian/20200505dfsg0-5-0-g816bcd01d5fa0b3171fe6d09c093a9290ccf7c25`, sharing the existing JBIG owner and installing only runtime encoders, wrappers, command filter, immutable profile defaults, and a pyppd archive.
- [x] Exclude foo2zjs models that require per-boot firmware loading, preserving the existing container contract.
- [x] Add m2300w from `debian/0.51-15-0-gf4ebe31fe93e8f2f56ecce2f927e59bb41432d53`, installing its encoder, wrapper, PostScript resources, and four generated PPDs in a pyppd archive.
- [x] Install all CUPS filters at `/usr/lib/cups/filter`; use `/usr/bin` for wrapper helpers and real `/usr`, `/etc`, and `/var/lib/ghostscript-printer-app` paths only.

## Task 2: Initialize persistent state

- [x] Store immutable HPLIP, foo2zjs, and m2300w defaults under `/usr/share/ghostscript-printer-app/defaults`.
- [x] Point `/etc/hp/hplip.conf` at `/var/lib/ghostscript-printer-app/hplip/hplip.conf` while keeping HPIJS compiled for `/etc/hp`.
- [x] Extend `container-entrypoint.sh` to create the three state directories and copy default files only when their destination is absent.
- [x] Preserve existing user files byte-for-byte across container restarts while allowing newly added defaults to seed later images.

## Task 3: Compose and verify

- [x] Add the three artifacts to `core-stack.bst` without adding a second CUPS, Ghostscript, JBIG, or Foomatic owner.
- [x] Add `just verify-stateful-drivers` and `tests/stateful-drivers.sh`.
- [x] Assert executable, shebang, and ELF closure for HPIJS, foo2zjs, and m2300w plus every wrapper helper they invoke.
- [x] Require representative HPIJS/IJS, foo2zjs, and m2300w conversions to emit non-empty, repeatable printer-language output with stable protocol signatures.
- [x] Start the real appliance with persistent state, modify one seeded HPLIP configuration/profile file per state family, restart, and prove the modifications survive.
- [x] Require representative HPIJS, foo2zjs, and m2300w entries in the live Printer Application driver catalog.

## Task 4: Verify and publish

- [x] Run `just validate`, all prior slice gates, `just verify-stateful-drivers`, workflow lint, shell syntax checks, and `git diff --check`.
- [x] Review the full diff from `feat/fsdk-packaged-drivers` and resolve all blocking findings.
- [ ] Resolve issue 06, commit and push `feat/fsdk-stateful-drivers`, and open a stacked PR based on `feat/fsdk-packaged-drivers`.

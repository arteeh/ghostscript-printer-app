# FSDK OCI Cutover Plan

**Goal:** Make BuildStream the sole OCI implementation while preserving the independent Snap product.

**Architecture:** Delete the obsolete Rockcraft manifest and its two service launchers. Keep `snap/`, shared source patches, and Snap automation. Replace the README's Docker Hub, mutable-tag, and Rockcraft instructions with the immutable Project Bluefin GHCR image, BuildStream development commands, numeric-user persistence, host networking, USB requirements, release policy, and physical-validation link.

## Task 1: Remove the legacy OCI path

- [x] Delete `rockcraft.yaml`, `scripts/start-server.sh`, and `scripts/run-avahi.sh`.
- [x] Remove the obsolete `*.rock` ignore rule.
- [x] Update FSDK patching guidance to treat the retired OCI path as Git history rather than a live contract.

## Task 2: Replace operator documentation

- [x] Document immutable `ghcr.io/projectbluefin/ghostscript-printer-app:<VERSION>` use.
- [x] Document `just build`, `just verify`, host networking, writable persistence, optional `PORT`, and USB access.
- [x] Link physical validation and describe tag-only signed multi-architecture releases.
- [x] Remove Docker Hub, mutable OCI tags, obsolete prerequisites, and the stale component list.

## Task 3: Verify and publish

- [ ] Run `just verify`, Snap validation, workflow lint, shell syntax checks, stale-reference searches, and `git diff --check`.
- [x] Review the full diff from `feat/fsdk-dependency-updates` and resolve all blocking findings.
- [ ] Resolve issue 10, commit and push `feat/fsdk-cutover`, and open a stacked PR based on `feat/fsdk-dependency-updates`.

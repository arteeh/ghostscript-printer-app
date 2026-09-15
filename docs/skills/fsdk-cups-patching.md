---
name: fsdk-cups-patching
description: Use when changing the freedesktop-sdk junction, CUPS build configuration, CUPS backends, or CUPS source patches for the OCI appliance.
metadata:
  context7-sources:
    - /apache/buildstream
---

# FSDK CUPS Patching

## When to Use

- Changing the pinned freedesktop-sdk junction.
- Changing CUPS TLS configuration, backends, filters, or source patches.
- Diagnosing CUPS graph or source-staging failures in the OCI build.

## When NOT to Use

- Snap-only dependency changes unrelated to CUPS.
- Printer Application behavior implemented in `ghostscript-printer-app.c`.
- Legacy driver elements that do not alter CUPS.

## Core Process

1. Treat `rockcraft.yaml`, `snap/snapcraft.yaml`, and root `patches/` as the existing behavior contract.
2. Keep one CUPS artifact owner. The FSDK junction must continue to own CUPS so its reverse dependencies build against the same libraries.
3. Keep CUPS-only source patches under `patches/cups/`. The `patch_queue` plugin applies every file in its directory, so unrelated patches must stay elsewhere.
4. Stage `patches/cups/` into the FSDK junction with a `local` source. Apply `patches/freedesktop-sdk/` at the junction project level; that project patch injects the nested CUPS source `patch_queue` and adjusts FSDK's CUPS configuration.
5. Do not use `config.overrides` for small CUPS patches or feature switches. BuildStream documents overrides as complete downstream ownership that stops inheriting upstream element updates.
6. Do not stage a second CUPS implementation. Duplicate `libcups.so*` ownership creates an artifact overlap and can compile reverse dependencies against a different library than the application receives.
7. When moving a shared patch, update both Snap and Rock references while Rock remains. Apply patches from the source root when their paths start with `a/backend/` and use `-p1`.
8. Cross-junction source checkouts nest under `<junction>/<element-path>/`; the CUPS probe therefore checks `freedesktop-sdk/components-_private-cups-base/`, not the checkout root.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| “The public `cups.bst` exists, so it contains every needed tool.” | It is a filter for libraries and licenses; inspect the staged payload before relying on it. |
| “A local CUPS element is simpler.” | It overlaps FSDK's CUPS and breaks the single-owner dependency graph. |
| “`config.overrides` is cleaner than two patch levels.” | It replaces the entire upstream element and forfeits inherited maintenance for a small downstream delta. |
| “All patches can share one directory.” | `patch_queue` applies every file in its directory; an unrelated c2esp patch will fail against CUPS. |
| “`bst show` proves source patches apply.” | It proves graph and source-path resolution; source checkout proves the nested patches apply to CUPS. |

## Red Flags

- More than one element installs `libcups.so*`.
- An application element depends directly on `components/_private/cups-base.bst`.
- The FSDK project patch embeds a second copy of a CUPS source patch.
- `cups-libs` or `cups-license` disappears from the FSDK CUPS split rules.
- A manifest invokes a patch after changing into a subdirectory incompatible with its `a/...` paths.
- An FSDK junction update lands without rerunning the patch-chain verification.

## Verification

- [ ] `just verify-cups-patch-chain` exits successfully.
- [ ] The CUPS-dependent Ghostscript element resolves.
- [ ] The graph contains exactly one FSDK private CUPS base.
- [ ] The staged CUPS source contains the DNS-SD and `USB_QUIRK_DIR` changes.
- [ ] The CUPS base still exposes `cups-libs` and `cups-license`.
- [ ] Both current Snap and Rock CUPS source versions accept the canonical patches while both packaging paths exist.

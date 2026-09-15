# FSDK Container Modernization Design

**Status:** Accepted

## Problem Statement

The OCI distribution is defined by a 1,609-line `rockcraft.yaml` that rebuilds roughly twenty upstream projects on Ubuntu 22.04. It duplicates much of the Snap manifest, has already drifted behind it, and publishes through mutable `edge`, `stable`, and `latest` tags. The current workflow builds on an amd64 runner despite declaring three platforms, does not create a verified multi-architecture index, and does not provide the signing, SBOM, provenance, or runtime-contract checks used by the Project Bluefin FSDK container tooling.

The runtime also depends on Rock's service manager to coordinate D-Bus, Avahi, and the Printer Application. Its helper scripts do not form a safe standalone OCI process supervisor: D-Bus is backgrounded, Avahi occupies the foreground, and code after Avahi is unreachable.

### Repository contract

- `ghostscript-printer-app.c` is intentionally small: it configures the PAPPL retrofit, CUPS backends, conversion graph, and driver selection. The migration does not redesign that logic.
- `Makefile` defines the application compile/link contract against PAPPL, CUPS, libppd, libcupsfilters, and pappl-retrofit.
- `snap/snapcraft.yaml` and `rockcraft.yaml` define the current driver payload. The Snap manifest is the newer dependency reference; the Rock manifest remains the OCI behavior reference until cutover.
- `patches/cups-dnssd-backend-socket-only.patch` and `patches/c2esp-libcupsfilters2-api.patch` are shared by Snap and OCI. They remain shared repository inputs after Rockcraft is removed.
- `.github/workflows/ci.yml`, `auto-update.yml`, and `registry-actions.yml` are the current validation, update, and publication surfaces. The FSDK migration replaces only their Rock-specific paths.

## Solution

Replace only the OCI build and publication lane with a self-contained BuildStream project patterned after `projectbluefin/fsdk-containers`. Compose supported libraries and tools directly from freedesktop-sdk 26.08, build only the application-specific and legacy-driver components that FSDK does not provide, chisel the result to its measured runtime closure, and export one multi-architecture OCI appliance.

Preserve the current driver payload and user-facing container behavior. Keep Snap packaging and Snap CI independent and unchanged. Once parity verification passes, remove Rockcraft and its OCI-specific scripts and workflows rather than maintaining two OCI definitions.

The appliance will be minimal but not declared distroless. Full driver parity and multi-process startup take precedence over removing every interpreter. It will contain no package manager or build tool, and every retained shell or interpreter must be justified by an executable runtime path.

## User Stories

1. As an existing container user, I want every currently advertised printer driver to remain available so that modernization does not remove printer support.
2. As an existing container user, I want the same persistent state location so that upgrades retain configured printers and settings.
3. As a network-printer user, I want host-network discovery through Avahi to continue working so that printers remain discoverable.
4. As a USB-printer user, I want the documented device mount and cgroup rule to continue working so that local printers remain usable.
5. As an operator, I want D-Bus, Avahi, and the Printer Application supervised as one container lifecycle so that child failures and shutdown are observable and deterministic.
6. As an operator, I want an optional numeric `PORT` override and unchanged default PAPPL port behavior so that existing deployments remain configurable.
7. As an operator, I want an amd64/arm64 image index so that both supported architectures use the same application release.
8. As an operator, I want immutable application-version tags with no `latest` alias so that deployments cannot change without an explicit version update.
9. As an operator, I want OCI metadata to identify both the application release and exact FSDK source so that a running artifact is auditable.
10. As a security reviewer, I want SBOMs, keyless signatures, and GitHub provenance attestations so that the published artifact's origin and contents are verifiable.
11. As a contributor, I want pull requests to build and exercise the affected image without registry write credentials so that untrusted changes cannot publish artifacts.
12. As a maintainer, I want dependency updates to change human-readable versions and integrity refs atomically so that source drift cannot silently enter the image.
13. As an upstream maintainer, I want the build to depend on upstream freedesktop-sdk rather than Project Bluefin infrastructure at runtime so that the completed work can be adopted whole.
14. As a Snap user, I want Snap behavior and release automation to remain unchanged so that the OCI migration does not destabilize another distribution format.
15. As a release manager, I want a Git tag whose version matches the packaged application version to be the only publication trigger so that releases are intentional and immutable.

## Implementation Decisions

### Build graph

- The repository owns a minimal BuildStream 2 project and a pinned freedesktop-sdk 26.08 junction.
- At the examined 26.08rc.1 junction, FSDK provides Ghostscript 10.07.1, CUPS 2.4.19, cups-filters 2.0.1, libcupsfilters 2.2.1, libppd 2.1.1, Foomatic, Avahi, D-Bus, libusb, Python, and catatonit. QPDF and PAPPL are not present in that pinned component set.
- CUPS has one artifact owner: FSDK's CUPS base. Repository changes follow BuildStream's recommended downstream-project pattern instead of overriding the element, because an override would transfer complete ownership and forfeit FSDK's CUPS updates and security maintenance. Ghostscript, cups-filters, libppd, Foomatic, and the application therefore continue to consume the same FSDK-owned `libcups.so*` artifact; staging a second CUPS build is prohibited.
- CUPS customization has two explicit levels. The top-level FSDK junction stages the repository's canonical `patches/cups/` directory as a `local` source and applies a project-level `patch_queue`. That queue modifies FSDK's private CUPS element to select GnuTLS unless an HTTPS smoke proves the newer OpenSSL build safe, preserve its `cups-libs`/`cups-license` split-rule interface, inject a second-level CUPS source `patch_queue` referencing the staged canonical files, and expose the required `snmp`, `dnssd`, `socket`, `ipp`, `ipps`, `lpd`, and `usb` backends plus `rastertoepson`, `rastertohp`, and `rastertolabel`. Application elements do not directly depend on `components/_private/cups-base.bst`; its use is confined to the project patch and must be revalidated on every FSDK update.
- PAPPL, pappl-retrofit, the Printer Application, pyppd, HPIJS, and legacy drivers absent from FSDK are represented by focused local elements. QPDF remains Snap-only: repository source and legacy drivers do not link it directly, while FSDK's libcupsfilters 2.2.1 uses pdfio and poppler. Pyppd generates self-extracting PPD archives, so its matching Python runtime and xz remain in the runtime closure.
- Existing source modifications form an explicit compatibility inventory: four PAPPL changes, the CUPS DNS-SD patch, CUPS `USB_QUIRK_DIR` support, the CUPS TLS selection if still required, and the libcupsfilters2 c2esp patch. CUPS source patches live once under `patches/cups/`; the junction stages that directory into FSDK rather than embedding copies in its project patch. Moving the existing DNS-SD patch and replacing Snap's inline USB rewrite with the canonical patch are deliberate, behavior-preserving Snap manifest edits gated by Snap CI. The c2esp patch remains outside the CUPS-only directory so CUPS's `patch_queue` cannot apply it accidentally.
- The broken Rock-only HPLIP rewrites to `/ghostscript-printer-app/current/...` are not compatibility behavior and must not be carried forward. The new element uses real OCI paths under `/etc`, `/usr`, and `/var/lib/ghostscript-printer-app`.
- Non-FSDK sources use immutable refs and automated version discovery. Version and integrity-ref updates are atomic and never auto-merged without a successful build.
- A stack element defines the complete runtime dependency closure. A compose element excludes debug, development, documentation, test, static, and other unused domains. The OCI export applies an appliance-specific prune based on measured runtime use.
- The final artifact contains no package manager or compiler. A shell, Python, Perl, xz, or other interpreter is retained only when the built driver payload or launcher executes it.

### Runtime process model

- This image is a documented shell-enabled FSDK appliance lane, not a distroless image. Its verification contract must not reuse the distroless "no shell" gate.
- Catatonit is PID 1 and starts one small POSIX launcher; the retained shell is also available to legacy filters that demonstrably require it.
- The launcher validates `PORT`, initializes persistent configuration without overwriting user changes, starts D-Bus, waits for its socket, starts Avahi, waits for readiness, and then starts the Printer Application.
- TERM and INT stop the Printer Application first, then Avahi and D-Bus. Unexpected exit of any required process fails the container.
- `/var/lib/ghostscript-printer-app` remains the single persistent volume.
- Host networking remains the supported mode for LAN discovery. Existing USB mount and device-cgroup requirements remain supported.
- The default runtime identity is numeric and has matching passwd/group entries. The current setuid USB backend behavior remains an explicit compatibility/security exception until physical-hardware testing can prove a safer replacement.

### Compatibility and architecture

- Driver parity means every working driver family and runtime behavior advertised by the existing OCI documentation is present before the new image is published. Known broken packaging, including the Rock-only HPLIP path rewrites, is fixed rather than reproduced.
- The OCI artifact supports amd64 and arm64. This explicitly drops the Rock manifest's declared armhf target; the existing workflows build Rockcraft on one amd64 runner and do not prove or publish a multi-architecture index. The Snap retains its separate armhf and riscv64 support.
- The migration may proceed through incomplete internal slices, but no partial driver image is published as a release.

### Versioning and publication

- The application release remains Ghostscript-derived: `<actual packaged Ghostscript version>-<packaging revision>`.
- One canonical version value feeds the binary, OCI metadata, and release validation. Because the Ghostscript pin moves into the FSDK junction, the current Rockcraft updater cannot remain the source of this value.
- The existing update workflow continues to update the Snap independently. FSDK junction updates and non-FSDK element updates use their own atomic source-ref workflow.
- Pull requests build and verify but cannot log into or write to a registry.
- The repository currently has no Git tags. After migration, a `v<application-version>` Git tag is the release boundary and publishes the matching immutable application-version tag to the repository owner's GHCR namespace; the published image is keyless-signed.
- No `latest`, `edge`, or `stable` OCI alias is published.
- OCI labels and index annotations include application version, source revision, creation time, license, source URL, exact FSDK version, and exact FSDK ref.
- Published indexes receive an SPDX SBOM, a keyless signature, and GitHub provenance attestation.

### Cutover

- Snap source, launcher scripts, and CI remain functionally unchanged. Its deliberate packaging-only edits update the moved CUPS DNS-SD patch path and replace the inline USB rewrite with the canonical CUPS patch; both are gated by Snap CI.
- Rockcraft remains during development only as the parity reference.
- After the FSDK image passes the complete compatibility contract, `rockcraft.yaml`, the two Rock-only scripts under `scripts/`, and Rock-specific build/publish/update workflow branches are removed in the same cutover. The shared `patches/` directory remains because Snap consumes it. There is no long-lived compatibility shim or second OCI implementation.
- User documentation is updated from Rockcraft and mutable-tag instructions to the BuildStream workflow and immutable GHCR release tags. Docker Hub is removed from the documented contract because its publish steps are currently commented out.

## Testing Decisions

The highest useful seam is the built OCI appliance. Tests assert observable artifact and runtime behavior rather than BuildStream source text.

- `just validate` must resolve the complete graph.
- amd64 and arm64 must each build the appliance.
- Artifact verification checks a documented uncompressed size ceiling, absence of package managers/build tools, expected numeric user and entrypoint, every driver/filter/PPD named by the current manifests, required runtime interpreters, OCI metadata, and complete ELF shared-library resolution.
- Patch verification covers PAPPL's vendor-option limit, disabled log rotation, `cups:socket` URI, and linked LDFLAGS; CUPS DNS-SD filtering and USB quirk lookup; c2esp's libcupsfilters2 API; correct HPLIP runtime paths; preservation of FSDK's `cups-libs`/`cups-license` split-rule interface; and the invariant that Snap and the staged FSDK project receive identical CUPS source patches from one repository directory.
- Runtime smoke starts the actual image with host networking and a temporary persistent volume; observes D-Bus, Avahi, HTTP and HTTPS readiness; submits a deterministic synthetic/file-backed print job; restarts the image and proves state persists; then stops it and proves children terminate cleanly.
- Release verification inspects both architectures in the published index and verifies its signature, SBOM, and provenance.
- Existing Snap CI remains green.
- Physical USB and network-printer checks are documented for upstream validation but are not automated release gates because the development and CI environment has no guaranteed printer hardware.

## Out of Scope

- Changing Printer Application behavior or driver-selection logic.
- Removing legacy drivers or reducing the advertised driver set.
- Migrating or redesigning the Snap.
- Adding 32-bit ARM or riscv64 OCI builds.
- Publishing a reduced strict-distroless variant.
- Vendoring a second complete CUPS/printing stack alongside FSDK's printing components.
- Adding Docker Hub publication.
- Requiring Project Bluefin's private remote-execution service for upstream builds; local and GitHub-hosted builds must remain possible.
- Replacing the existing USB privilege model before hardware-backed evidence is available.

## Risks

- The FSDK element name is not a sufficient compatibility signal: filtered elements may omit required backends or filters. Compare staged payloads and execute the affected path before accepting reuse.
- The two-level CUPS patch chain necessarily names FSDK's private CUPS implementation. Pinning makes that coupling explicit, the junction stages canonical repository patches rather than duplicating their contents, and any upstream layout/configuration change must fail patch application for review while later FSDK CUPS updates remain inheritable.
- The two-level CUPS patch chain is not yet proven in this repository. The first delivery slice must stage the canonical CUPS patch directory through the junction and run `bst show` on a CUPS-dependent element. If resolution fails, stop and reopen ADR-0001 before any CUPS-dependent implementation proceeds.
- FSDK component versions may expose API differences from the Rock/Snap pins. Resolve these at the junction patch boundary with the smallest upstreamable patch; do not stage a second copy of a library already owned by the FSDK printing graph.
- Legacy driver sources contain generated Python PPD archives and may contain shell wrappers. Inventory the built artifact before pruning interpreters.
- A deterministic synthetic print proves orchestration and filter execution, not hardware compatibility. Preserve a separate physical-printer acceptance checklist.
- The image will be larger than a strict distroless runtime. Set the size ceiling from the first complete measured build, with explicit headroom, rather than guessing before the payload exists.

## Delivery Order

1. Run a CUPS patch-chain feasibility spike: scaffold only enough of the FSDK junction to stage `patches/cups/`, inject the nested CUPS source patch queue, and resolve a CUPS-dependent element with `bst show`. Every later CUPS-dependent slice is blocked on this result.
2. Establish the remaining self-contained FSDK graph and build/export tooling.
3. Prove the FSDK-owned printer stack.
4. Build PAPPL, pappl-retrofit, and the application.
5. Restore legacy drivers in independently verifiable groups until driver parity is complete.
6. Add process supervision, state initialization, and runtime smoke coverage.
7. Add multi-architecture CI and immutable tagged publication with supply-chain metadata.
8. Add atomic update automation for the FSDK junction and every non-FSDK source.
9. Remove the Rockcraft lane and update OCI documentation after parity passes.

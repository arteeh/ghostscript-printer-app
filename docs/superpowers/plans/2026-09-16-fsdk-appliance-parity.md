# FSDK Appliance Parity Implementation Plan

**Goal:** Provide one local command that proves the complete FSDK OCI appliance contract against the real built image, while keeping physical printer validation explicit and honest.

**Architecture:** Keep the existing slice-specific smoke tests as the owners of conversion and lifecycle behavior. Add one final image-audit script for cross-cutting invariants: OCI metadata, uncompressed size, runtime bloat, interpreter/toolchain policy, complete ELF closure, and the advertised backend/filter/driver/PPD-family inventory. Expose an aggregate `just verify` recipe that runs graph validation, every slice gate, and the final audit. Strip the residual FSDK debug payload during OCI layer assembly rather than adding another compose layer.

## Task 1: Enforce final image invariants

- [x] Remove `/usr/lib/debug` from the assembled OCI layer; keep licenses and runtime data.
- [x] Add `tests/appliance-parity.sh` with a 500 MiB uncompressed x86_64 image ceiling and exact OCI user, entrypoint, architecture, source, license, title, application-version, and FSDK-version checks.
- [x] Reject package managers, compilers, build systems, headers, debug files, non-license test trees, and static archives in the final image.
- [x] Require Bash and Python as the only application interpreters, and reject Perl, Ruby, Node, Lua, and Tcl runtimes.
- [x] Walk every ELF file in the running image and fail if any shared-library dependency is unresolved.

## Task 2: Enforce advertised payload parity

- [x] Require the complete CUPS backend set used by the appliance: DNS-SD, IPP/IPPS, LPD, SNMP, socket, and USB.
- [x] Require every README-advertised Ghostscript/Foomatic driver plus executables and CUPS filters for HPIJS, pnm2ppa, pxljr, foo2zjs, SpliX, brlaser, fxlinuxprint, c2esp, rastertosag-gdi, Dymo, P-Touch, c2050, cjet, min12xxw, m2300w, CUPS, and cups-filters.
- [x] Require every PPD provider family: core cups-filters/Foomatic/manufacturer data plus pxljr, foo2zjs, SpliX, brlaser, fxlinuxprint, c2esp, rastertosag-gdi, Dymo, P-Touch, OKI, and m2300w.
- [x] Add `just verify` as the single aggregate command running graph validation, the CUPS patch-chain proof, all real-image behavior gates, and the final parity audit.

## Task 3: Document physical validation

- [x] Add `docs/oci-physical-validation.md` with separate USB and network-printer procedures, the automated size ceiling, expected discovery/printing observations, and a result-record template.
- [x] State explicitly that CI and local synthetic gates do not prove physical printer behavior.

## Task 4: Verify and publish

- [x] Run `just verify`, workflow lint, shell syntax checks, and `git diff --check`.
- [x] Review the full diff from `feat/fsdk-stateful-drivers` and resolve all blocking findings.
- [ ] Resolve issue 07, commit and push `feat/fsdk-appliance-parity`, and open a stacked PR based on `feat/fsdk-stateful-drivers`.

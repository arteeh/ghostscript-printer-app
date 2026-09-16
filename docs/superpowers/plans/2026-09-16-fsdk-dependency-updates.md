# FSDK Dependency Update Automation Plan

**Goal:** Propose atomic, fully verified updates for the FSDK junction and every repository-owned external BuildStream source while preserving the Snap updater as an independent lane.

**Architecture:** Give every Git source a deliberate moving selector and immutable resolved ref, keep CPAN name/suffix/checksum contracts, and keep the plugin tarball's version/checksum explicit. A standard-library Python coordinator runs BuildStream tracking for the complete root graph, refreshes the PyPI plugin tarball, derives the application version from the newly selected FSDK Ghostscript source, synchronizes the IJS source and OCI FSDK labels, and validates the source inventory. A scheduled workflow runs the CUPS patch-chain gate and complete appliance gate before minting a short-lived Mergeraptor token and opening one non-auto-merged PR containing every related version/ref change. The existing updater becomes Snap-only.

## Task 1: Make every source trackable

- [x] Use bounded wildcard selectors for release-series sources and moving branch selectors only where upstream has no releases.
- [x] Retain immutable Git describe refs, CPAN SHA-256 sums, and the plugin tarball SHA-256 sum.
- [x] Add a source-inventory check that rejects external Git sources without `track`/`ref`, CPAN sources without name/suffix/checksum, or tar sources without URL/checksum.

## Task 2: Coordinate atomic metadata updates

- [x] Track every root-project source without crossing into the FSDK junction project.
- [x] Refresh the buildstream-plugins-community PyPI sdist URL and checksum from PyPI metadata.
- [x] Read the selected FSDK Ghostscript element, derive `<ghostscript-version>-<packaging-revision>`, update `VERSION`, and synchronize the IJS track/ref.
- [x] Synchronize the OCI FSDK release/ref labels with the selected junction.
- [x] Fail without writing partial metadata when upstream responses are missing or malformed.

## Task 3: Automate verified proposals

- [x] Add a scheduled/manual FSDK-source workflow with read-only permissions during tracking and verification.
- [x] Run `just verify-cups-patch-chain` and `just verify` before minting write credentials.
- [x] Mint a short-lived Mergeraptor token only after verification, then commit all changes atomically and create or update one dependency PR.
- [x] Never enable auto-merge in the updater; native PR CI remains the merge gate.
- [x] Reduce the existing updater to the independent Snap dependency lane.

## Task 4: Verify and publish

- [x] Run source-inventory checks, an isolated updater smoke, `just verify`, workflow lint, script syntax checks, and `git diff --check`.
- [x] Review the full diff from `feat/fsdk-secure-releases` and resolve all blocking findings.
- [ ] Resolve issue 09, commit and push `feat/fsdk-dependency-updates`, and open a stacked PR based on `feat/fsdk-secure-releases`.

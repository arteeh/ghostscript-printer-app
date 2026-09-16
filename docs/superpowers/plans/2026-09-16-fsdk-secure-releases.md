# FSDK Secure Multi-Architecture Releases Implementation Plan

**Goal:** Build and verify native amd64/arm64 FSDK appliances on pull requests, and publish an immutable, attestable multi-architecture GHCR release only when a Git tag exactly matches the packaged application version.

**Architecture:** Make the application version a repository-level source consumed by both the application build and OCI metadata. Keep pull-request CI read-only and run the complete `just verify` gate on native GitHub-hosted x86_64 and arm64 runners. A separate tag-only release workflow builds and verifies both architectures, adds release-specific config labels, pushes immutable architecture manifests, assembles one versioned OCI index with matching annotations, attaches a BuildStream-native SPDX document for the complete dependency graph, keyless-signs the index and SBOM artifact, creates GitHub provenance, and verifies every published object. No mutable channel tag is created.

## Task 1: Establish canonical release metadata

- [x] Add one `VERSION` file containing the Ghostscript-derived application version.
- [x] Make the application build and OCI version label read `VERSION` rather than duplicating literals.
- [x] Add the exact FSDK commit label and retain the FSDK release label.
- [x] Extend the appliance parity gate to compare the binary version, image label, `VERSION`, FSDK junction ref, and FSDK labels.

## Task 2: Validate pull requests on both architectures

- [x] Preserve the independent Snap build job.
- [x] Replace the Rockcraft CI job with a native `x86_64`/`aarch64` matrix on GitHub-hosted runners.
- [x] Install only the host tools needed to run BuildStream and Podman, then run `just verify`.
- [x] Give pull-request jobs read-only repository permission and no package, attestation, or identity-token permission.

## Task 3: Publish immutable multi-architecture releases

- [x] Replace the mutable Rock publication workflow with a `v*` tag-only workflow.
- [x] Reject tags other than `v$(cat VERSION)` before any login or write-capable job runs.
- [x] Build and verify natively on amd64 and arm64, then add source revision, creation time, exact FSDK version, and exact FSDK ref to each image config.
- [x] Push immutable architecture manifests and create exactly one `${VERSION}` multi-architecture index with matching OCI annotations.
- [x] Never publish `latest`, `edge`, or `stable` aliases.

## Task 4: Attach and verify supply-chain evidence

- [x] Generate a BuildStream-native SPDX JSON SBOM for the complete dependency graph and attach it to the index as an OCI referrer artifact.
- [x] Keyless-sign the image index and SBOM artifact with GitHub OIDC.
- [x] Publish GitHub build provenance for the index digest.
- [x] Verify the index platforms, OCI annotations, keyless signature, SBOM referrer/signature, and GitHub attestation after publication.

## Task 5: Verify and publish

- [x] Run `just verify`, workflow lint, shell syntax checks, version-contract checks, and `git diff --check`.
- [x] Review the full diff from `feat/fsdk-appliance-parity` and resolve all blocking findings.
- [x] Resolve issue 08, commit and push `feat/fsdk-secure-releases`, and open a stacked PR based on `feat/fsdk-appliance-parity`.

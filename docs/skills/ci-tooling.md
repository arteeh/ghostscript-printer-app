---
name: ghostscript-printer-app-ci-tooling
description: Use when changing pull-request validation, FSDK source updates, OCI release publication, signatures, SBOMs, or provenance for ghostscript-printer-app.
metadata:
  context7-sources:
    - /websites/github_en_actions
    - /apache/buildstream
---

# CI tooling

## When to Use

- Changing `.github/workflows/ci.yml`, `registry-actions.yml`, or `update-fsdk-sources.yml`.
- Changing `VERSION`, FSDK release metadata, GHCR tags, SBOM attachment, signing, or provenance.

## When NOT to Use

- Local BuildStream element work that does not change CI or release behavior.
- Snap packaging internals outside workflow triggers and permissions.

## Core Process

1. Keep pull-request CI credential-free: `contents: read`, native amd64/arm64 runners, and `just verify`.
2. Treat `VERSION` as the application release source. A release tag must equal `v$(cat VERSION)` before any write-capable job starts.
3. Grant `packages: write`, `id-token: write`, and `attestations: write` only to tag-release jobs that need them.
4. Refuse an existing immutable tag. Proceed only when the authenticated registry response explicitly reports a missing manifest or repository; network and authentication failures are fatal.
5. Add version, revision, creation time, license, source URL, FSDK version, and FSDK ref to every architecture image config and to the multi-architecture index.
6. Generate one BuildStream-native SPDX JSON document for the complete dependency graph, attach it to the index, keyless-sign the index and SBOM artifact, publish GitHub provenance with `actions/attest`, then verify all three forms of evidence.
7. Run dependency tracking and full verification before exposing the write-scoped `GITHUB_TOKEN` to a shell. Push one atomic update branch, explicitly dispatch CI because token-authored pushes do not trigger it, and never enable auto-merge.
8. Keep the Snap update/build lanes independent from FSDK OCI publication.
9. Give every external BuildStream source a project alias. Prefer an authoritative, checksummed release archive over a personal Git mirror when upstream Git is unreliable.
10. Give pull-request CI a PR-scoped concurrency group with `cancel-in-progress: true`; stacked force-pushes must not leave duplicate multi-hour architecture jobs consuming the runner pool.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| “A failed registry lookup means the tag is absent.” | Authentication and network failures also return nonzero; accept only explicit manifest/name-not-found responses. |
| “The index inherits child labels.” | GHCR renders index metadata; copy required OCI labels into index annotations explicitly. |
| “One host can emulate both architectures.” | Native runners expose architecture-specific source and runtime failures that emulation can hide. |
| “Signing the image covers the SBOM.” | The SBOM is a separate OCI referrer and must be signed and verified separately. |
| “A personal mirror is reachable, so it is a safe fallback.” | Reachability is not provenance. Use an authoritative archive with a verified digest or an organization-controlled mirror. |

## Red Flags

- Registry login, package write permission, or OIDC access in a pull-request job.
- A publish trigger other than a matching `v<VERSION>` tag.
- `latest`, `edge`, or `stable` in the OCI release workflow.
- Unpinned third-party actions.
- Source tracking after a write-capable token has been minted.
- Index creation without checking both native architecture manifests and their config labels.
- An SBOM generated for only the runner's architecture.
- An unaliased external source URL or a source pinned only to a personal fork.
- Pull-request CI without cancellation of superseded runs.

## Verification

- [ ] `actionlint .github/workflows/*.yml` succeeds.
- [ ] `just verify` succeeds locally.
- [ ] Pull-request CI completes on native amd64 and arm64 runners without registry credentials.
- [ ] BuildStream resolves and fetches every repository-owned source without `[unaliased-url]` warnings.
- [ ] Pushing a replacement commit cancels the superseded run for the same pull request.
- [ ] A mismatched tag fails in the metadata job before any write-capable job.
- [ ] The published index contains exactly amd64 and arm64 and has the required annotations.
- [ ] `cosign verify` succeeds for the index and SBOM artifact.
- [ ] `gh attestation verify oci://<image>@<digest> --repo <owner/repo>` succeeds.

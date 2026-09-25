# Contributions and stable promotion

Target `testing` for all code, documentation, and dependency pull requests.
Sign commits with `git commit -s` using the author's email, and use descriptive
Conventional Commit titles (for example, `ci: validate stable promotions`).

CI runs on pull requests into `testing` and `stable`, and pushes to either branch.
Both native FSDK jobs (`FSDK (x86_64)` and `FSDK (aarch64)`) run `just fetch` and the
complete `just verify` contract with only `contents: read` and no publication
credentials. Snap builds run separately. Locally, run `actionlint .github/workflows/*.yml` and
`python3 tests/test-promotion.py` for workflow changes, and `just verify` for appliance
verification; the latter requires Just, Podman, FUSE, and the pinned BuildStream
builder. The real OCI print-to-socket-sink tests establish automated shipping
behavior. Physical paper output still requires hardware validation as described
in [physical validation](oci-physical-validation.md).

## Promote a tested revision

1. Finish integration PRs into `testing` and select its exact commit SHA.
2. Open a separate PR from this repository's `testing` branch into `stable`.
   Record the source SHA in the PR description. Keep the branch at that revision
   while it is reviewed; a new push requires fresh checks.
3. Require both native FSDK checks and the Snap check on the promotion PR.
   CI rejects other source branches/repositories, requires the stable base to be
   an ancestor of the source, and checks that the proposed merge has exactly the
   source tree. It then checks out the event's immutable source SHA and runs the
   full verification again. No previous run or mock result substitutes for it.
4. A maintainer merges using **Create a merge commit**, preserving the tested
   source SHA in stable history. Do not squash or rebase promotions. Before the
   next promotion, merge `stable` back into `testing` through a tested PR so its
   merge commit is included in the next source history.
5. Create `v<VERSION>` release tags only on promoted stable history. The release
   metadata job rejects tags outside `stable` before write-capable jobs start.
   Release jobs still run full native verification before publishing immutable
   versioned images; branch names do not create mutable OCI aliases.

Maintainers must configure branch protection for `testing` and `stable`: require
up-to-date PR branches and `FSDK (x86_64)`, `FSDK (aarch64)`, and `build-snap` checks,
block direct pushes and force pushes, and disallow bypasses. Workflow files alone
cannot enforce repository merge settings. This change does not alter those
settings or retire `main`.

## Main caller inventory (2026-09-25)

| Caller | Migration / retirement requirement |
| --- | --- |
| `.github/workflows/ci.yml` push trigger | Changed from `main` to `testing` and `stable`; PR bases explicitly match. |
| `.github/workflows/update-fsdk-sources.yml` | Checkout and generated PR base both use `testing`, including manual runs. |
| `.github/workflows/auto-update.yml` | Snap updater uses repository default branch, now `testing`; no explicit `main` ref. |
| `.github/workflows/registry-actions.yml` | Tag-triggered; require revision in `stable`, then retain full verification. |
| [Open PR #11](https://github.com/projectbluefin/ghostscript-printer-app/pull/11) | Still targets `main` at inventory time; its owner/maintainer must retarget it to `testing` and rerun CI before retiring `main`. |
| `docs/superpowers/plans/2026-09-16-fsdk-core-appliance.md` | Historical completed plan includes `git rebase main`; retained as historical evidence, not current contribution instructions. |
| External consumers and repository settings | Before deleting `main`, maintainers must inventory downstream workflow callers, raw/blob URLs, rulesets, and webhook/default-branch assumptions outside this checkout. |

The tracked-file scan found no reusable `workflow_call` or repository `@main`
callers. `main` remains available until the open PR and external audit are handled.

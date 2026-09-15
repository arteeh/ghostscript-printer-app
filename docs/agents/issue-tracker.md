# Issue tracker: Local Markdown

Issues and specs for this repo live as Markdown files in `.scratch/` because GitHub Issues are disabled on `projectbluefin/ghostscript-printer-app`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in dependency order.
- Triage state is recorded as a `Status:` line near the top of each issue file.
- Comments and conversation history append under a `## Comments` heading.

## Skill operations

- **Publish a spec:** create `.scratch/<feature-slug>/spec.md`.
- **Fetch a ticket:** read the referenced file under `.scratch/<feature-slug>/issues/`.
- **Block:** list every prerequisite in the ticket's `Blocked by:` field.
- **Claim:** set `Status: claimed` before implementation.
- **Resolve:** set `Status: resolved` and append the outcome under `## Answer`.

Do not infer a GitHub target from this clone: its `upstream` remote is marked as the default GitHub repository. GitHub Issues must not be used unless the repository enables them and this configuration is deliberately changed.

# TODO And Plan Audit Prompt

Scan the repo for TODOs, plans, roadmap notes, issue references, temporary workarounds, and unfinished implementation markers.

## Search Targets

Look for:

- `TODO`
- `FIXME`
- `HACK`
- `XXX`
- `later`
- `follow up`
- active plan files
- roadmap docs
- unchecked markdown tasks
- test TODOs, skipped tests, xfail markers, and coverage notes

## Verify Against The Repo

Do not assume a checkbox or TODO is accurate. For each meaningful item:

- Inspect the referenced code, docs, tests, or config.
- Check whether the work appears implemented but not marked done.
- Check whether a plan says work is done but verification is missing.
- Check whether tests or CI cover the claimed completion.
- Identify duplicated items across `to_do.md`, source comments, plans, and issues.

Do not mark items complete unless the evidence is concrete.

## Verify Completion Logging

For each completed item found (marked [x] in plans, or items that appear done):

- [ ] Was it removed from `to_do.md`?
- [ ] Was it logged in the appropriate changelog?
  - User-visible → `CHANGELOG.md`
  - Internal → `CHANGELOG.dev.md`
  - Maintenance → `MAINTENANCE.md`
- [ ] Was the related plan archived to `plans/archive/`?
- [ ] Are references/links preserved (commit hashes, issue numbers)?
- [ ] Was scratch cleanup performed in `.context/`?

Flag items that are marked complete but missing logging steps. These should be remediated by running [`prompts/cleanup-completed-work.md`](cleanup-completed-work.md).

## Output

Write a markdown report with:

- Open items grouped by area.
- Items that appear stale, duplicated, or already completed.
- Plan checkboxes that need updating, with evidence.
- Plans that appear ready to move to `plans/archive/`.
- **Completion logging gaps** - items marked done but missing proper logging/archival.
- Test-related TODOs or skipped/xfail tests that need explicit follow-up.
- Blockers.
- Low-risk quick wins.
- High-leverage project work.
- Items that should become `plans/*.md` via `prompts/backlog-to-plans.md`.
- Recommended next actions (including cleanup if logging gaps found).

Do not delete or rewrite TODOs unless asked.

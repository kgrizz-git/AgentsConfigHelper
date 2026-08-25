# Plan: Tool Catalog Integrity

Last reviewed: 2026-08-25
Date: 2026-08-23
Author: maintainers
Status: in progress (Phase 2 foundation: deterministic internal-link CI + checker tests; strict catalog-marker/coverage activation deferred to Phase 0/1 evidence review)
Linked issue/PR: n/a
Related: [Supported Tools](../../docs/supported-tools.md),
[Structured Configuration Roadmap](structured-configuration-roadmap.md), and
[Documentation Freshness policy](../../policies/doc-freshness.md)

## Goal

Keep the app's supported-tool catalog evidence-based as vendors change paths, formats,
permission semantics, and documentation. Every registered tool should have a clear record
of what is known, which primary source supports it, and whether the repository includes a
safe representative example. Mechanical documentation breakage should fail CI; vendor-link
liveness and periodic catalog review should create actionable maintenance work without
blocking unrelated feature pull requests.

## Current state

- `lib/catalog/tool_descriptor_registry.dart` is the runtime source of truth for supported
  tools and discovery targets.
- `docs/supported-tools.md` covers each registered tool's paths and format summary. A
  partial evidence table has been added (Claude Code and Codex reviewed rows; all other
  registered tools recorded as pending). Source links and token-free examples are uneven
  across the remaining tools. In particular, Antigravity IDE/App, Kilo, Cline, LM Studio,
  and some Copilot surfaces need a recorded evidence status rather than an implied schema
  guarantee.
- `ci/scripts/check_doc_links.py` checks internal Markdown links, can probe external links,
  and recognizes `Catalog reviewed through:` markers. Its catalog scope now explicitly
  includes `docs/supported-tools.md` (not only `inventory/`), and an offline CI docs job
  invokes the deterministic internal-link check plus the checker's unittest suite. The
  strict `--catalog-strict` gate (catalog review marker + registry-coverage check) is
  implemented and tested but intentionally not yet wired into PR CI; it activates only
  after a full-catalog evidence change truthfully adds the marker.
- The existing maintenance-loop prompt describes manual catalog review, but no recurring
  workflow turns a stale tool catalog into a visible repository task.

## Decisions

- The Dart registry owns runtime discovery. The documentation must cite or summarize it;
  it must not become a second hand-maintained discovery-path source of truth.
- `docs/supported-tools.md` is the curated public catalog and carries both `Last reviewed:`
  and `Catalog reviewed through:` markers. The latter means a maintainer actually evaluated
  current vendor evidence, not merely that a link returned HTTP 200.
- A per-tool evidence table is descriptive, not a promise that every target has a complete
  schema editor. Use three explicit states: **verified example**, **primary docs only**, and
  **paths recorded; schema needs verification**.
- Committed examples are synthetic and token-free. Never copy a user's real settings or
  vendor examples that contain credential-shaped values.
- Internal Markdown links and required catalog metadata are deterministic CI gates.
  External HTTP outcomes are advisory because valid vendor sites can reject `HEAD`, require
  sign-in, or rate-limit automation.
- The quarterly process opens or updates one GitHub issue labeled for documentation review;
  it does not fail routine PRs or automatically rewrite/remove tool entries.

## Scope

### In scope

- A concise evidence/status table for every `ToolDescriptorRegistry` tool in
  `docs/supported-tools.md`.
- Primary documentation links for path and schema/permission claims where vendors publish
  them; an honest unknown status where they do not.
- Representative schema examples or fixture references only for tools whose structure is
  sufficiently verified and useful to upcoming work.
- Checker support for the supported-tool catalog's internal links, external links, and
  catalog review marker.
- A PR CI documentation gate and a quarterly scheduled advisory/reminder workflow.
- Tests for checker behavior and workflow-facing scripts where practical.

### Out of scope

- Discovering, parsing, or editing new tool configurations.
- A universal machine-readable vendor schema database.
- Automatically treating an HTTP failure, redirect, or stale marker as proof a tool should
  be removed.
- Sending private configuration content, credentials, or user paths to any checker.
- Blocking the Claude Code read-only card on documenting every lower-priority tool.

## Catalog evidence contract

Add one compact table near the top of `docs/supported-tools.md` (or a clearly linked
adjacent catalog file if it becomes unwieldy) with these columns:

| Field | Meaning |
| --- | --- |
| Tool | Exact display name/ID from the registry. |
| Discovery coverage | Registry-defined target categories, summarized without duplicating every path. |
| Primary evidence | Official vendor documentation, official schema, or `not published`. |
| Schema evidence | `verified example`, `primary docs only`, or `paths recorded; schema needs verification`. |
| Fixture/reference | Link to a synthetic repository fixture when one exists; otherwise `none`. |
| Reviewed | Date of substantive vendor/source review. |

The table must not claim a schema is editable simply because it is parseable. When a source
cannot be found, say so and leave the raw editor as the only supported representation.

## Implementation phases

### Phase 0 — reconcile the catalog boundary

- [ ] Enumerate every `ToolId`/display name and target class from the registry in a focused
      unit test or deterministic validation input.
- [ ] Compare the registry, quick-comparison table, per-tool sections, and evidence table.
      Resolve terminology differences (for example, Cursor Agent vs Cursor IDE) without
      changing discovery behavior.
- [ ] Add `Catalog reviewed through: YYYY-MM-DD` to `docs/supported-tools.md` only after
      completing the initial evidence review.
- [ ] Update `docs/research/README.md` to explain that raw dated research supports the
      catalog, while `supported-tools.md` is the reviewed curated reference.

### Phase 1 — source and fixture evidence

- [x] Populate source/status rows for the first high-priority slice (Claude Code, Codex).
      Established the evidence-table pattern in `docs/supported-tools.md` with the contract
      fields (Tool, Discovery coverage, Primary evidence, Schema evidence, Fixture/reference,
      Reviewed). Remaining registered tools are recorded as pending — no schema/fixture claim
      is implied for them.
- [ ] Populate source/status rows for the remaining registered tools. Prefer vendor-owned
      docs and schemas; mark community/unpublished facts distinctly.
- [x] Verify and record the first high-priority structured-schema pair: Claude Code and Codex
      (verified examples via token-free staging fixtures).
- [ ] Verify and record the remaining high-priority structured-schema tools: Cursor,
      Opencode, Kiro, and Devin.
- [x] Add or link token-free fixtures for the Claude Code and Codex rows. Existing
      synthetic staging fixtures used; no new fixtures required for this slice.
- [ ] For paths-only tools, record the reason and a follow-up research question instead of
      fabricating a partial schema example.
- [ ] Add a fixture-intake checklist to the safe-testing documentation: source provenance,
      redaction/synthetic rewrite, secret scan, and raw-editor fallback expectation.

### Phase 2 — deterministic pull-request checks

- [x] Refactor `ci/scripts/check_doc_links.py` so catalog paths are explicit and include
      `docs/supported-tools.md`, rather than relying only on the `inventory/` directory.
- [x] Keep `--internal-only --strict` as the routine PR command, and implement a narrow
      companion validation (`--catalog-strict`) that fails if `docs/supported-tools.md`
      lacks/misformats its required catalog review marker or omits an expected registry
      tool row.
- [ ] Wire `--catalog-strict` into PR CI. Deferred until a Phase 0/1 evidence change
      truthfully adds the `Catalog reviewed through:` marker; see activation note below.
- [x] Add focused Python tests or shell fixtures for: ignored `tmp/`, supported-tool catalog
      inclusion, valid/stale/malformed dates, internal links, and non-fatal external outcomes.
- [x] Add a lightweight CI docs job that runs the deterministic command. It must not require
      external network access or new write permissions.

> **Activation note:** The `--catalog-strict` gate (catalog review marker + registry-coverage
> check) is implemented and covered by tests, but is intentionally NOT yet wired into PR CI.
> It activates only after a Phase 0/1 evidence change truthfully adds the
> `Catalog reviewed through:` marker to `docs/supported-tools.md`. The current CI job runs
> the deterministic internal-link check plus the checker's unittest suite.
>
> **CI-wiring note:** When `--catalog-strict` is finally wired into PR CI, the truthful
> `Catalog reviewed through: YYYY-MM-DD` marker must be added in the same full-catalog
> evidence review change — the gate requires the marker, so wiring and the marker arrive
> together, not in separate PRs.

### Phase 3 — quarterly advisory and reminder

- [ ] Add a separate scheduled GitHub Actions workflow (quarterly, not on pull requests)
      that runs the external-link/catalog-date advisory check.
- [ ] Give that workflow the minimum `issues: write` permission and use an idempotent action
      or `gh issue` script to create/update one open `documentation-review` issue. Include
      checker output, review deadline, and links to the catalog and maintenance instructions.
- [ ] Do not use issue content derived from local config files; the workflow reads repository
      documentation only.
- [ ] Make failure to create/update the reminder visible in workflow logs, but do not turn
      transient vendor HTTP failures into a release or PR gate.
- [ ] Document the schedule, issue label, manual rerun command, and review/close criteria in
      `prompts/maintenance-loop.md` and `ci/README.md`.

### Phase 4 — acceptance and ongoing ownership

- [ ] Confirm every registry tool has one evidence-table row and a per-tool documentation
      section or an explicit reason it shares one.
- [ ] Confirm all table links resolve internally and external checks report only advisory
      findings that have been triaged.
- [ ] Manually dispatch the quarterly workflow once; verify it creates/updates the intended
      issue without duplicate spam.
- [ ] Re-run it after closing the issue to verify the next overdue review can open a new one.
- [ ] Refresh `Catalog reviewed through:` only after reviewing sources and recording changed,
      added, rejected, or unchanged tools.

## Validation

Run before review:

```bash
python3 ci/scripts/check_doc_links.py --internal-only --strict
python3 ci/scripts/check_doc_links.py --offline
pre-commit run --files docs/supported-tools.md ci/scripts/check_doc_links.py
```

After the workflow exists, manually dispatch it from GitHub and verify that it neither reads
configuration files nor opens duplicate issues. Run the normal Dart format, analysis, and test
gates when Dart tests or source code change.

## Completion

When Phases 0–4 are complete, update the catalog date, record CI/workflow behavior in
`CHANGELOG.dev.md`, remove or narrow the associated `TO_DO.md` item, and archive this plan.

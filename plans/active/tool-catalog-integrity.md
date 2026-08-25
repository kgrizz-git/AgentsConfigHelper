# Plan: Tool Catalog Integrity

Last reviewed: 2026-08-25
Date: 2026-08-23
Author: maintainers
Status: in progress (Phase 0 complete: catalog boundary reconciled — registry enumeration
tests present, evidence-table coverage rows corrected to match registered targets; Phase 1
evidence complete; Phase 2 close-out: catalog marker + --catalog-strict wired into PR CI;
Phase 3 quarterly advisory and Phase 4 acceptance remain)
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
  tools and discovery targets. Phase 0 reconciliation confirmed: existing registry tests
  enumerate all 17 descriptors and their `ToolId`s, and the evidence-table "Discovery
  coverage" rows were corrected so they describe only registered targets (Claude Code's
  "local/managed" and Codex's "system/profiles" removed; LM Studio's "Markdown model docs"
  removed). The LM Studio `hub/presets/*.json` vs documented `config-presets/` discrepancy
  is retained as an explicit follow-up.
- `docs/supported-tools.md` covers each registered tool's paths and format summary. All 17
  registered tools now have a recorded evidence/status row (Claude Code, Codex, Cursor Agent,
  Cursor IDE, Opencode, Kiro, Devin, Kilo, Cline, Antigravity CLI, Antigravity IDE,
  Antigravity App, Paseo, Agy-ACP, GitHub Copilot, LM Studio, and AGENTS.md (shared)). Source
  links and token-free examples remain uneven across them — several are primary-docs-only or
  paths-recorded-needs-verification, and the LM Studio preset path has an open follow-up —
  but every registered tool now has an explicit evidence status rather than an implied schema
  guarantee. The `Catalog reviewed through: 2026-08-25` marker is now present in
  `docs/supported-tools.md`, and the strict `--catalog-strict` CI gate is wired into the offline
  docs PR CI job.
- `ci/scripts/check_doc_links.py` checks internal Markdown links, can probe external links,
  and recognizes `Catalog reviewed through:` markers. Its catalog scope now explicitly
  includes `docs/supported-tools.md` (not only `inventory/`), and an offline CI docs job
  invokes the deterministic internal-link check, the `--catalog-strict` catalog gate, and the
  checker's unittest suite. External network probing remains disabled.
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

- [x] Enumerate every `ToolId`/display name and target class from the registry in a focused
      unit test or deterministic validation input. Satisfied by existing
      `test/catalog/tool_descriptor_registry_test.dart` (17-descriptor order enumeration +
      `docs/supported-tools.md` display-name presence) and
      `test/catalog/registry_invariants_test.dart` (every `ToolId` represented +
      markdown/text-never-structured + no-duplicate-target invariants).
- [x] Compare the registry, quick-comparison table, per-tool sections, and evidence table.
      Resolve terminology differences (for example, Cursor Agent vs Cursor IDE) without
      changing discovery behavior. Fixed three evidence-table "Discovery coverage" rows that
      described non-registered targets as registered: Claude Code (removed "local/managed" —
      `.claude/settings.local.json` and managed-settings paths are not registered discovery
      targets), Codex (removed "system/profiles" — `/etc/codex/config.toml` and
      `~/.codex/<profile>.config.toml` are not registered), and LM Studio (removed "Markdown
      model docs" — the registry has no Markdown targets for LM Studio; all targets are
      JSON/YAML structured config). The LM Studio `hub/presets/*.json` path discrepancy is
      retained as an explicit follow-up, not silently corrected.
- [x] Add `Catalog reviewed through: YYYY-MM-DD` to `docs/supported-tools.md` only after
      completing the initial evidence review.
- [x] Update `docs/research/README.md` to explain that raw dated research supports the
      catalog, while `supported-tools.md` is the reviewed curated reference. Already
      satisfied: the file states research is "the input material, not the reviewed reference"
      and points to `supported-tools.md` as the "reviewed curated reference".

### Phase 1 — source and fixture evidence

- [x] Populate source/status rows for the first high-priority slice (Claude Code, Codex).
      Established the evidence-table pattern in `docs/supported-tools.md` with the contract
      fields (Tool, Discovery coverage, Primary evidence, Schema evidence, Fixture/reference,
      Reviewed). All remaining registered tools have since been recorded in subsequent slices —
      no schema/fixture claim is implied beyond what each row states.
- [x] Populate source/status rows for the remaining registered tools. Prefer vendor-owned
      docs and schemas; mark community/unpublished facts distinctly.
- [x] Populate source/status rows for the GitHub Copilot + LM Studio + AGENTS.md (shared)
      evidence slice against current vendor/convention sources. GitHub Copilot: primary evidence
      from docs.github.com (configuring CLI, CLI configuration directory, changing settings, custom
      instructions support); schema evidence "primary docs only" — `settings.json` full key table
      is published but the schema is source-defined (no standalone JSON-schema document); `config.json`
      is auto-managed state; `permissions-config.json` documents the saved-approval schema but is also
      auto-managed; no token-free fixture exists. LM Studio: primary evidence from the archived/legacy
      `lmstudio-ai/configs` `schema.json` (last updated pre-0.3, repository archived by LM Studio in 2024;
      documents the legacy preset `load_params`/`inference_params` structure) and lmstudio.ai/docs
      (model.yaml, presets); schema evidence "paths recorded; schema needs verification" — the published
      legacy preset schema exists but LM Studio documents current presets at `~/.lmstudio/config-presets/`,
      not `~/.lmstudio/hub/presets/*.json` as registered; the app `settings.json` schema is unpublished;
      follow-up: does the registry's `hub/presets/*.json` path need correction? AGENTS.md (shared): primary evidence from agents.md (Agentic AI Foundation /
      Linux Foundation); schema evidence "not published" — explicitly an open schema-free Markdown
      convention; the existing `test/fixtures/staging_home/.agents/AGENTS.md` and
      `test/fixtures/staging_home/workspace/AGENTS.md` are token-free synthetic fixtures that
      exercise discovery, so both are cited as fixture references.
- [x] Verify and record the first high-priority structured-schema pair: Claude Code and Codex
      (verified examples via token-free staging fixtures).
- [x] Populate source/status rows for the Cursor + Opencode evidence slice (Cursor Agent,
      Cursor IDE, Opencode) against current vendor sources. Cursor Agent and Cursor IDE are
      primary-docs-only / schema-needs-verification (no fixtures); Opencode is a verified
      example via the existing token-free staging fixture and the published opencode.ai
      JSON schema.
- [x] Verify and record the remaining high-priority structured-schema tools: Kiro and Devin.
      Both are **primary docs only** against current kiro.dev and docs.devin.ai sources. Kiro:
      `permissions.yaml` `rules:` array (`capability`/`match`/`effect`/`exclude`) documented
      with the full capability list and deny-overrides semantics; the existing
      `test/fixtures/staging_home/.kiro/settings/permissions.yaml` is a non-conforming
      placeholder shape and is **not** a verified example (no fixture claimed). Devin:
      `config.json` (JSON-with-comments) schema documented (`agent`, `permissions`
      `allow/deny/ask`, `sandbox`, `read_config_from`, `keymap`, `proxy`); permission syntax
      `Read/Write/Exec/Fetch(pattern)` plus tool-based and `mcp__*` matchers with deny-wins
      precedence; no fixture exercising the structured config.
- [x] Populate source/status rows for the Kilo + Cline evidence slice against current vendor
       sources. Kilo: primary evidence from kilo.ai/docs/contributing/architecture/config-schema
       (canonical Effect Schema source of truth), kilo.ai/docs/getting-started/settings,
       kilo.ai/docs/automate/mcp/using-in-kilo-code, kilo.ai/docs/customize/custom-rules, and
       the cloud editor schema at `https://app.kilo.ai/config.json`; schema evidence "primary
       docs only" — documented top-level keys (`model`, `provider`, `mcp`, `permission`,
       `instructions`, `agent`, `sandbox`, `formatter`, `lsp`, `experimental`) with the
       cross-repo runtime/schema contract described; the existing
       `test/fixtures/staging_home/.config/kilo/kilo.jsonc` is a **non-conforming placeholder**
       (`permissions.{filesystem,network}` is not a documented key — schema uses `permission`
       + `sandbox`), so no fixture is claimed. Cline: primary evidence from
       docs.cline.bot/getting-started/config, docs.cline.bot/customization/cline-rules,
       docs.cline.bot/mcp/adding-and-configuring-servers, docs.cline.bot/cli/configuration;
       schema evidence "primary docs only" — `cline_mcp_settings.json` `mcpServers` map (STDIO
       + streamableHttp/sse transports), `global-settings.json` `GlobalSettingsSchema`, and
       secret-bearing `providers.json` are documented via Cline's source Zod schemas; no
       single published JSON-schema document and no fixture exercising the structured config
       exists. Both rows annotate vendor-documented scopes that are **not** registered
       discovery targets (Kilo: `tui.jsonc`, `.kilocode/`, org/managed config; Cline: hooks,
       skills, agents, plugins, cron, workflows, `.clineignore`, CLI `mcp.json`, and the
       `~/Documents/Cline/{Hooks,Plugins,Workflows}` compat directories).
- [x] Populate source/status rows for the Antigravity CLI + IDE + App evidence slice against
        current vendor sources. Antigravity CLI: primary evidence from
        antigravity.google/docs/cli/using, antigravity.google/docs/cli/permissions,
        antigravity.google/docs/cli/settings, antigravity.google/docs/cli/reference
        (documents the full `settings.json` schema — top-level keys `colorScheme`,
        `altScreenMode`, `toolPermission`, `artifactReviewPolicy`, `notifications`, `showTips`,
        `showFeedbackSurvey`, `editor`, `editorMode`, `vimInsertFirst`, `allowNonWorkspaceAccess`,
        `enableTerminalSandbox`, `useG1Credits`, `enableTelemetry`, `verbosity`,
        `runningLightSpeed`; plus `permissions.{allow,deny,ask}` arrays of `action(target)`
        strings — `read_file`, `write_file`, `read_url`, `execute_url`, `command`, `unsandboxed`,
        `mcp` — with deny>ask>allow precedence and write-implies-read), and
        antigravity.google/docs/rules-workflows; the `~/.gemini/antigravity-cli/settings.json`
        path and `keybindings.json` are vendor-documented. Schema evidence "primary docs only" —
        no token-free fixture exercising the structured config exists. Antigravity IDE: antigravity
        IDE is a host-editor extension (VS Code, Visual Studio, JetBrains, Zed); its settings
        live in the host editor's settings and Antigravity does **not** publish a dedicated
        `~/.gemini/antigravity-ide/settings.json` path or schema — schema evidence "paths
        recorded; schema needs verification" with the follow-up question of whether the IDE writes
        a dedicated `settings.json` under `~/.gemini/antigravity-ide/` or all settings map to the
        host editor. Antigravity App (Antigravity 2.0): a standalone desktop app with in-app
        hierarchical settings (Global/Project/Conversation scopes via Cmd+,); Antigravity does
        **not** publish a `~/.gemini/antigravity-app/settings.json` path or JSON schema — schema
        evidence "paths recorded; schema needs verification" with the follow-up question of whether
        the App writes a dedicated `settings.json` under `~/.gemini/antigravity-app/` or all
        settings live in the app's internal state. Both the IDE and App rows retain their
        registered discovery targets but flag the undocumented paths. No fixtures exist for any of
        the three.
- [x] Populate source/status rows for the Paseo + Agy-ACP evidence slice against current vendor
        sources. Paseo: primary evidence from the published JSON Schema draft-07 at
        paseo.sh/schemas/paseo.config.v1.json and paseo.sh/docs; schema evidence "primary docs only"
        — the full schema is published (top-level keys `version`, `daemon`, `app`, `worktrees`,
        `providers`, `agents`, `features`, `log`) but no token-free fixture exercising the structured
        config exists in-repo, so no fixture is claimed. Agy-ACP: primary evidence from the
        kgrizz-git/agy-acp README (branch `main`); schema evidence "paths recorded; schema needs
        verification" — the README documents the `~/.openab/agy-acp/sessions.json` path but does not
        publish its JSON schema, which is defined only in the Rust source (`SessionStore` →
        `StoredSession` `{conversation_id, last_step_idx, model_id}` in `src/types.rs`). Follow-up:
        should the README publish the `sessions.json` JSON schema, or is the Rust `StoredSession`
        struct the authoritative schema? (The documented README example matches the source struct
        exactly, but no public JSON-schema document exists.) No fixture exercising the structured
        config exists.
- [x] Add or link token-free fixtures for the Claude Code and Codex rows. Existing
      synthetic staging fixtures used; no new fixtures required for this slice.
- [x] Add or link a token-free fixture for the Opencode row. Reused the existing synthetic
      `test/fixtures/staging_home/.config/opencode/opencode.json` staging fixture; no new
      fixture required.
- [x] For paths-only tools, record the reason and a follow-up research question instead of
      fabricating a partial schema example.
- [x] Add a fixture-intake checklist to the safe-testing documentation: source provenance,
      redaction/synthetic rewrite, secret scan, token-free/environment-independent content,
      validation/parsing expectations, and raw-editor fallback expectation. Added as the
      "Fixture-intake checklist" section in `docs/testing-strategies.md`.

### Phase 2 — deterministic pull-request checks

- [x] Refactor `ci/scripts/check_doc_links.py` so catalog paths are explicit and include
      `docs/supported-tools.md`, rather than relying only on the `inventory/` directory.
- [x] Keep `--internal-only --strict` as the routine PR command, and implement a narrow
      companion validation (`--catalog-strict`) that fails if `docs/supported-tools.md`
      lacks/misformats its required catalog review marker or omits an expected registry
      tool row.
- [x] Wire `--catalog-strict` into PR CI. The truthful `Catalog reviewed through:` marker
      and the strict catalog gate arrive together in this close-out change; see CI-wiring note below.
- [x] Add focused Python tests or shell fixtures for: ignored `tmp/`, supported-tool catalog
      inclusion, valid/stale/malformed dates, internal links, and non-fatal external outcomes.
- [x] Add a lightweight CI docs job that runs the deterministic command. It must not require
      external network access or new write permissions.

> **CI-wiring note:** `--catalog-strict` is now wired into the offline docs PR CI job
> (`ci.yml` "Docs integrity", `--internal-only --catalog-strict`). External network probing
> remains disabled; only a missing/malformed `Catalog reviewed through:` marker and a missing
> registry tool are strict failures. A stale review date stays advisory (Phase 3 quarterly), never
> a PR gate failure.

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

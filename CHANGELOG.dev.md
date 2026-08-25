# Developer Changelog

Internal / developer-facing changes that do not belong in the public
[`CHANGELOG.md`](CHANGELOG.md). See [`policies/changelog-conventions.md`](policies/changelog-conventions.md).

## Unreleased

### Added

- **Tool-catalog integrity Phase 3 (quarterly advisory/reminder):** Added
  `.github/workflows/catalog-advisory.yml`, a scheduled GitHub Actions workflow that runs the
  checker's existing offline/advisory capabilities quarterly (cron `0 6 1 */3 *`) plus on
  manual `workflow_dispatch`. It runs `python3 ci/scripts/check_doc_links.py --offline`
  (internal links + catalog staleness, **no network**) and the checker's unittest suite, and
  when the `Catalog reviewed through:` date is stale (120-day window) it writes an actionable
  reminder to the run summary and emits a `::warning` annotation on `docs/supported-tools.md`.
  **No-write by design:** the plan originally proposed `issues: write` plus an idempotent
  create/update of one `documentation-review` issue. Opening issues needs a write token and is
  over-broad for an automated schedule, so this uses a no-write alternative — the workflow
  runs with `permissions: contents: read` only, probes no external links, and never writes to
  the repo or the Issues API; the reminder is advisory and surfaces only in the Actions run
  summary. It never blocks PRs or releases (the PR gate stays the Phase 2 `--catalog-strict`
  job in `ci.yml`, where only a missing/malformed marker or a missing registry tool fails).
  Plan checkboxes/status, `prompts/maintenance-loop.md` §6, and `ci/README.md` updated to
  document the schedule, no-write mechanism, manual rerun, and review/refresh steps. No logic
  or test changes (reuses the checker's existing offline/advisory behavior).

### Changed

- **Tool-catalog integrity Phase 4 reconciliation:** The plan's Phase 4 acceptance section
  previously described creating/re-closing a `documentation-review` issue, which contradicts
  the no-write scheduled/manual workflow that Phase 3 actually shipped
  (`.github/workflows/catalog-advisory.yml` — run summary + `::warning` annotation,
  `contents: read` only, no Issues API interaction). Reconciled Phase 4 to the real workflow:
  local/offline acceptance checks verified here (all 17 registry tools have an evidence-table
  row + per-tool docs section; `--internal-only --strict` and `--offline` report 0 broken /
  0 advisory across 162 files; 34 checker unittests pass; `Catalog reviewed through:` marker
  present and fresh), with the single remaining item recorded as a post-merge GitHub Actions
  manual-dispatch confirmation that cannot be proven from a local checkout. Plan status and
  `TO_DO.md` narrowed accordingly. No code or workflow changes.
  evidence-table "Discovery coverage" rows in `docs/supported-tools.md` against the runtime
  registry (`lib/catalog/tool_descriptor_registry.dart`) so documentation describes only
  registered discovery targets. Corrected three rows: Claude Code (removed "local/managed"
  — `.claude/settings.local.json` and managed-settings paths are documented vendor scopes but
  are **not** registered discovery targets), Codex (removed "system/profiles" —
  `/etc/codex/config.toml` and `~/.codex/<profile>.config.toml` are not registered), and LM
  Studio (removed "Markdown model docs" — the registry has no Markdown targets for LM Studio;
  all four targets are JSON/YAML structured config). Confirmed the existing
  `test/catalog/tool_descriptor_registry_test.dart` (17-descriptor order enumeration +
  display-name presence in docs) and `test/catalog/registry_invariants_test.dart` (every
  `ToolId` represented + markdown/text-never-structured + no-duplicate-target invariants)
  already satisfy the Phase 0 "enumerate every ToolId/display name and target class" goal —
  no new tests added. The LM Studio `hub/presets/*.json` vs documented `config-presets/`
  path discrepancy is **retained as an explicit follow-up**, not silently corrected. Plan
  checkboxes/status and this changelog updated. No Dart discovery behavior changed.

### Added

- **Tool-catalog integrity Phase 2 close-out (catalog marker + strict-CI activation):** Added the
  truthful `Catalog reviewed through: 2026-08-25` marker to `docs/supported-tools.md` (all 17
  registered tools already had a recorded evidence/status row; none were pending) and wired the
  implemented `--catalog-strict` gate into the offline docs PR CI job (`ci.yml` "Docs integrity",
  now `--internal-only --catalog-strict`). External network probing remains disabled — only a
  missing/malformed marker and a missing registry tool are strict failures; a stale review date
  stays advisory (Phase 3 quarterly). Also applied three evidence clarity fixes: rephrased the
  GitHub Copilot precedence chain in words (removed the unescaped `>` that rendered as a nested
  blockquote); qualified the `lmstudio-ai/configs` schema as legacy/pre-0.3 (repository archived by
  LM Studio in 2024) in the evidence table, changelog, and plan prose; and added an evidence/follow-up
  note to the detailed LM Studio Config paths section flagging that the registered
  `~/.lmstudio/hub/presets/*.json` path conflicts with the current documented
  `~/.lmstudio/config-presets/` location (no runtime discovery change). Plan checkboxes/status and
  CI-wiring note updated.
  Substantively reviewed and recorded **GitHub Copilot**, **LM Studio**, and **AGENTS.md (shared)**
  rows in the `docs/supported-tools.md` evidence table against current vendor/convention sources.
  GitHub Copilot: primary evidence from docs.github.com — configuring Copilot CLI, CLI configuration
  directory, the `/settings` slash command, custom instructions support; schema evidence
  "primary docs only" — `settings.json` (user-editable JSONC) full key table is published in the CLI
  configuration directory reference, but the schema is source-defined in `github/copilot-cli` and there
  is no standalone JSON-schema document; `config.json` is auto-managed application state; repo
  `.github/copilot/settings.json` + `settings.local.json` are documented with MDM, then user, repo,
  local, environment, and flags precedence; `permissions-config.json` documents the saved-per-location approval schema
  (`tool_approvals[].kind`: `commands`/`read`/`write`/`mcp`/`mcp-sampling`/`memory`/`custom-tool`/
  `extension-management`/`extension-permission-access` + `allowed_directories`) but is auto-managed.
  No token-free fixture exercising the structured config exists. LM Studio: primary evidence from the
  archived/legacy `lmstudio-ai/configs` `schema.json` (last updated pre-0.3, repository archived by LM Studio
  in 2024; documents the legacy preset JSON structure — `load_params` with `n_ctx`/`n_gpu_layers`/
  `cache_type_k`/`cache_type_v` enums/etc., `inference_params` with `temp`/`top_k`/`top_p`/`repeat_penalty`/
  `grammar`/`logit_bias`/etc.) and lmstudio.ai/docs (model.yaml open spec, presets); schema evidence
  "paths recorded; schema needs verification" — the published legacy preset schema exists, but LM Studio
  documents current presets at `~/.lmstudio/config-presets/`, **not** `~/.lmstudio/hub/presets/*.json` as
  registered in the registry; the app-level `~/.lmstudio/settings.json` exists but LM Studio does **not**
  publish its JSON schema. Follow-up: does the registry's `.lmstudio/hub/presets/*.json` path reflect an
  older/alternate location, or should it be corrected to `~/.lmstudio/config-presets/*.json`? AGENTS.md (shared): primary evidence from
  [agents.md](https://agents.md/) (stewarded by the Agentic AI Foundation under the Linux Foundation);
  schema evidence "not published" — AGENTS.md is explicitly an open, schema-free Markdown convention
  (the standard states "AGENTS.md is just standard Markdown" with no required fields). The existing
  `test/fixtures/staging_home/.agents/AGENTS.md` and `test/fixtures/staging_home/workspace/AGENTS.md`
  are token-free synthetic fixtures that exercise discovery of the convention, so both are cited as
  fixture references. All three rows annotate vendor-documented scopes that are **not** registered
  discovery targets. Plan and this changelog updated for the partial slice.

- **Tool-catalog integrity Phase 1 (fixture-intake checklist):** Added a concise,
  operational fixture-intake checklist to `docs/testing-strategies.md` covering source
  provenance, synthetic rewrite/redaction, secret scanning (gitleaks), token-free and
  environment-independent content, validation/parsing expectations (Dart test coverage),
  and the raw-editor fallback expectation for unsupported structures. Linked from the
  checklist to `docs/macos-test-root.md` and `docs/supported-tools.md`. Plan checkbox
  and this changelog updated.

- **Tool-catalog integrity Phase 1 (partial evidence slice):** Established the
  evidence-table pattern in `docs/supported-tools.md` with the plan's contract fields
  (Tool, Discovery coverage, Primary evidence, Schema evidence, Fixture/reference, Reviewed).
  Added substantively reviewed rows for **Claude Code** (primary evidence: code.claude.com
  docs/settings, permissions, claude-md; verified example via existing token-free staging
  fixture) and **Codex** (primary evidence: developers.openai.com codex/config-basic,
  codex/permissions; verified example via existing token-free staging fixture). All other
  registered tools are recorded as **pending** review. `Catalog reviewed through:` is
  intentionally withheld until the full catalog is reviewed. Updated
  `docs/research/README.md` to clarify that raw dated research supports the catalog while
  `supported-tools.md` is the reviewed curated reference. Plan and this changelog updated
  for the partial slice.

- **Tool-catalog integrity Phase 1 (Cursor + Opencode evidence slice):** Substantively
  reviewed and recorded **Cursor Agent**, **Cursor IDE**, and **Opencode** rows in the
  `docs/supported-tools.md` evidence table against current vendor sources. Cursor Agent:
  primary evidence from cursor.com/docs/reference/permissions (published `permissions.json`
  schema), cursor.com/docs/rules, cursor.com/docs/cli/reference/configuration +
  permissions; schema evidence "primary docs only" (no fixture). Cursor IDE: paths recorded
  against cursor.com/docs; schema evidence "paths recorded; schema needs verification"
  (IDE `settings.json` is the inherited VS Code format — Cursor publishes no dedicated
  settings-schema reference). Opencode: primary evidence from opencode.ai/docs/config,
  opencode.ai/docs/permissions, and the published JSON schema at opencode.ai/config.json;
  verified example via the existing token-free
  `test/fixtures/staging_home/.config/opencode/opencode.json` fixture. Remaining registered
  tools stay pending; `Catalog reviewed through:` still withheld. Plan and this changelog
  updated for the partial slice.

- **Tool-catalog integrity Phase 1 (Kiro + Devin evidence slice):** Substantively reviewed
  and recorded **Kiro** and **Devin** rows in the `docs/supported-tools.md` evidence table
  against current vendor sources. Kiro: primary evidence from kiro.dev/docs/configuration,
  kiro.dev/docs/permissions, kiro.dev/docs/custom-agents, kiro.dev/docs/steering; schema
  evidence "primary docs only" — the `permissions.yaml` `rules:` array
  (`capability`/`match`/`effect`/`exclude`) is documented with the full capability list and
  deny-overrides semantics. The pre-existing
  `test/fixtures/staging_home/.kiro/settings/permissions.yaml` is a **non-conforming
  placeholder shape** and is not a verified example, so no fixture is claimed for Kiro.
  Devin: primary evidence from docs.devin.ai/cli/reference/configuration/config-file,
  docs.devin.ai/cli/reference/permissions, docs.devin.ai/cli/extensibility/rules; schema
  evidence "primary docs only" — the `config.json` (JSON-with-comments) schema and the
  `Read/Write/Exec/Fetch(pattern)` plus tool-based and `mcp__*` permission matchers
  (deny-wins precedence) are documented; no fixture exercising the structured config exists.
  Remaining registered tools stay pending; `Catalog reviewed through:` still withheld. Plan
  and this changelog updated for the partial slice.

- **Tool-catalog integrity Phase 1 (Kilo + Cline evidence slice):** Substantively reviewed
  and recorded **Kilo** and **Cline** rows in the `docs/supported-tools.md` evidence table
  against current vendor sources. Kilo: primary evidence from
  kilo.ai/docs/contributing/architecture/config-schema (canonical Effect Schema source of
  truth), kilo.ai/docs/getting-started/settings, kilo.ai/docs/automate/mcp/using-in-kilo-code,
  kilo.ai/docs/customize/custom-rules, and the cloud editor schema endpoint
  `https://app.kilo.ai/config.json`; schema evidence "primary docs only" — documented
  top-level keys (`model`, `provider`, `mcp`, `permission` per-tool allow/ask/deny,
  `instructions`, `agent`, `sandbox` with `enabled`/`network`/`writable_paths`/`allowed_hosts`,
  `formatter`, `lsp`, `experimental`) with the cross-repo runtime/schema contract. The
  pre-existing `test/fixtures/staging_home/.config/kilo/kilo.jsonc` is a **non-conforming
  placeholder** (`permissions.{filesystem,network}` is not a documented key — the schema uses
  `permission` + `sandbox`), so no fixture is claimed for Kilo. Cline: primary evidence from
  docs.cline.bot/getting-started/config, docs.cline.bot/customization/cline-rules,
  docs.cline.bot/mcp/adding-and-configuring-servers, docs.cline.bot/cli/configuration;
  schema evidence "primary docs only" — `cline_mcp_settings.json` `mcpServers` map (STDIO +
  streamableHttp/sse transports) and `global-settings.json` are documented; the
  `GlobalSettingsSchema` is a source-defined Zod surface and Cline does **not** publish a
  single JSON-schema document, so the full key list is not vendor-documented (one concrete
  confirmed key is `disabledTools`; `providers.json` is secret-bearing API-key config). No
  fixture exercising the structured config exists.
  Both rows annotate vendor-documented scopes that are **not** registered discovery targets:
  Kilo's `tui.jsonc`, `.kilocode/`, and org/managed config; Cline's hooks, skills, agents,
  plugins, cron, workflows, `.clineignore`, CLI-only `mcp.json`, and the
  `~/Documents/Cline/{Hooks,Plugins,Workflows}` compatibility directories. Remaining
  registered tools stay pending; `Catalog reviewed through:` still withheld. Plan and this
  changelog updated for the partial slice.

- **Tool-catalog integrity Phase 1 (Antigravity CLI + IDE + App evidence slice):** Substantively
  reviewed and recorded **Antigravity CLI**, **Antigravity IDE**, and **Antigravity App** rows
  in the `docs/supported-tools.md` evidence table against current vendor sources
  (antigravity.google). Antigravity CLI: primary evidence from
  antigravity.google/docs/cli/using, antigravity.google/docs/cli/permissions,
  antigravity.google/docs/cli/settings, and antigravity.google/docs/cli/reference, which
  documents the full `settings.json` schema (top-level keys `colorScheme`, `altScreenMode`,
  `toolPermission`, `artifactReviewPolicy`, `notifications`, `showTips`, `showFeedbackSurvey`,
  `editor`, `editorMode`, `vimInsertFirst`, `allowNonWorkspaceAccess`, `enableTerminalSandbox`,
  `useG1Credits`, `enableTelemetry`, `verbosity`, `runningLightSpeed`; plus
  `permissions.{allow,deny,ask}` arrays of `action(target)` strings — `read_file`, `write_file`,
  `read_url`, `execute_url`, `command`, `unsandboxed`, `mcp` — with deny>ask>allow precedence
  and write-implies-read); the `~/.gemini/antigravity-cli/settings.json` path and
  `keybindings.json` are vendor-documented. Schema evidence "primary docs only" — no token-free
  fixture exercising the structured config exists. Antigravity IDE: a host-editor extension (VS
  Code, Visual Studio, JetBrains, Zed) — its settings live in the host editor's settings and
  Antigravity does **not** publish a dedicated `~/.gemini/antigravity-ide/settings.json` path or
  schema; schema evidence "paths recorded; schema needs verification" with a follow-up question
  (does the IDE write a dedicated `settings.json` under `~/.gemini/antigravity-ide/`, or do all
  persisted settings map to the host editor's `settings.json`?). Antigravity App (Antigravity
  2.0): a standalone desktop app with in-app hierarchical settings (Global/Project/Conversation
  scopes via Cmd+,) — Antigravity does **not** publish a `~/.gemini/antigravity-app/settings.json`
  path or JSON schema; schema evidence "paths recorded; schema needs verification" with a
  follow-up question (does the App write a dedicated `settings.json` under
  `~/.gemini/antigravity-app/`, or are all settings persisted in the app's internal state?).
  Both the IDE and App rows retain their registered discovery targets but flag the undocumented
  paths. No fixtures exist for any of the three. Per-tool sections for IDE and App updated with
  evidence notes. Remaining registered tools stay pending; `Catalog reviewed through:` still
  withheld. Plan and this changelog updated for the partial slice.

- **Tool-catalog integrity Phase 1 (Paseo + Agy-ACP evidence slice):** Substantively reviewed
  and recorded **Paseo** and **Agy-ACP** rows in the `docs/supported-tools.md` evidence table
  against current vendor sources. Paseo: primary evidence from the published JSON Schema
  draft-07 at `paseo.sh/schemas/paseo.config.v1.json` and `paseo.sh/docs`; schema evidence
  "primary docs only" — the full schema is published (top-level keys `version`, `daemon`, `app`,
  `worktrees`, `providers`, `agents`, `features`, `log`) but no token-free fixture exercising the
  structured config exists in-repo, so no fixture is claimed. Agy-ACP: primary evidence from the
  `kgrizz-git/agy-acp` README (branch `main` — the `mine` branch referenced in docs does not exist
  on the fork); schema evidence "paths recorded; schema needs verification" — the README documents
  the `~/.openab/agy-acp/sessions.json` path but does not publish its JSON schema, which is defined
  only in the Rust source (`SessionStore` → `StoredSession` `{conversation_id, last_step_idx,
  model_id}` in `src/types.rs`). Follow-up: should the README publish the `sessions.json` JSON
  schema, or is the Rust `StoredSession` struct the authoritative schema? (The documented README
  example matches the source struct exactly, but no public JSON-schema document exists.) No fixture
  exercising the structured config exists. Remaining registered tools stay pending; `Catalog
  reviewed through:` still withheld. Plan and this changelog updated for the partial slice.

- **Flutter hook worktree portability:** Added `hooks/scripts/flutter_env.py`, a
  stdlib-Python wrapper that execs a Flutter command with `GIT_DIR`/`GIT_WORK_TREE`
  cleared from the child environment. In a linked git worktree, `git commit`
  exports those vars, which redirect Flutter's SDK git detection at the app
  checkout and break pub resolution (`Flutter SDK version 0.0.0-unknown`). Wired
  the `dart-code-linter`, `flutter-analyze`, and `flutter-test` pre-commit hooks
  through it via `language: python` (portable macOS/Linux/Windows; no `python3`
  PATH assumption). Added `tests/test_flutter_env.py` covering env filtering,
  argument/exit-code passthrough, and an end-to-end `flutter --version`
  regression guard under simulated hook env.

- **Tool-catalog integrity Phase 2 (foundation):** Refactored
  `ci/scripts/check_doc_links.py` so catalog scope is explicit —
  `docs/supported-tools.md` is always catalog-checked (not just `inventory/`).
  Added a `--catalog-strict` gate (deferred activation) that will require a valid
  `Catalog reviewed through: YYYY-MM-DD` marker plus presence of every registry
  tool display name once a Phase 0/1 evidence change truthfully adds the marker.
  Added stdlib-unittest tests (`ci/tests/test_check_doc_links.py`) covering tmp/
  exclusion, catalog inclusion, valid/stale/malformed dates, internal links,
  non-fatal external outcomes, and a registry-displayName drift check. Added a
  lightweight offline `docs` CI job running the deterministic internal-link
  check (`--internal-only --strict`) plus the unittest suite. External-link
  liveness remains advisory and is not part of PR CI; date staleness remains
  advisory (Phase 3 quarterly), not a strict failure.

- **Claude Code permission help coverage:** Added pure-Dart reviewed help metadata and widget
  coverage for its keyboard-accessible explanatory dialog; recorded the schema-help review
  convention in the structured-configuration roadmap and supported-tools reference.

- **Claude Code permissions acceptance:** Recorded the successful 2026-08-24 macOS test-root
  smoke for the read-only Claude policy card; its implementation plan is now archived.

- **Claude Code permissions coverage:** Added token-free recognized, malformed, unknown-key,
  missing-policy, and comment-bearing fixtures with adapter, card, and editor-integration
  tests for the new read-only Claude Code policy presentation.

- **Structured-configuration roadmap:** Added the staged architecture and safety plan for
  schema-aware cards, reviewed help, per-schema expansion, and regression coverage, plus a
  ready-to-implement read-only Claude Code `allow`/`ask`/`deny` permissions vertical slice.
- **Tool-catalog integrity plan:** Added a scoped plan for per-tool source/schema evidence,
  deterministic catalog checks in PR CI, and a quarterly advisory GitHub review issue.

- **macOS test-root containment (in progress):** Added a test-only,
  exact-marker-validated `--test-root=<absolute-path>` startup mode. It uses a native,
  descriptor-relative no-follow bridge for config I/O, backups, restores, and preferences;
  rejects symlink escapes; confines discovery paths; and shows a persistent test-mode
  banner. Native and Dart tests cover normal operations, symlink cases, startup validation,
  preferences, external `COPILOT_HOME`, and the banner. Added token-free fixtures plus
  macOS-only staging/validated-cleanup scripts. Linux and Windows reject the mode pending
  their own implementations; the initial macOS staging smoke passed on 2026-08-22. Added
  `docs/macos-test-root.md` and the interactive/flagged root `dev.sh` entrypoint for the
  documented local workflow. Test-root startup failures render an explicit error screen rather
  than a blank window. Restore buttons now explicitly use white foreground text for contrast.
- **Desktop usability coverage:** Added widget coverage for visible History & Backups restore
  actions and unit coverage for adaptive display sizing, saved-bounds validation, and contained
  test-root preference storage.
- **Test-root containment plan:** Recorded Phase 0 source evidence that a `HOME` override
  cannot prove backup or preference containment, and split the no-follow, cross-platform
  implementation decision into `plans/active/test-root-containment.md`.
- **`plans/active/safe-testing-foundation.md`:** Implementation plan for synthetic
  fixture coverage and a write-confined staging-home smoke workflow.
- **`plans/archive/dependency-upgrades.md`:** Separate staged package-upgrade
  plan with local and CI verification gates; Flutter SDK upgrades are kept out
  of package-only work.

### Changed

- **Product and testing research:** Added a staged, token-free testing workflow and
  an evidence-based direction for schema-aware configuration cards, then recorded the
  recommended delivery order in `TO_DO.md`.
- **Flutter 3.47.1 / Dart 3.13.1 toolchain:** Updated CI; upgraded the compatible
  Riverpod/analyzer family; regenerated providers; and aligned analyzer configuration
  with current Flutter tooling.
- **Dependencies (compatible lockfile update):** Ran `flutter pub upgrade`
  without touching `pubspec.yaml` constraints, bumping the transitive dev-only
  test package `vm_service` 15.2.0 → 15.3.0 (the sole `Upgradable` package at
  baseline). No runtime or security posture change for the shipped app: it is
  absent from the non-dev dependency tree. `plans/archive/dependency-upgrades.md`
  now records the Phase 0 baseline, the direct-package target inventory, and the
  Phase 1 outcome. The subsequent Flutter-enabled major migration is recorded above.
- **ADR-002 and macOS execution planning:** Accepted an unsandboxed,
  source-build-only macOS workflow to unblock local discovery and editing;
  deferred Developer ID, notarization, FFI home resolution, sandbox/bookmark
  infrastructure, and binary-distribution work. The focused implementation
  plan is now `plans/active/macos-local-execution.md`.
- **macOS local execution:** Removed App Sandbox from Debug/Profile and Release
  entitlements and Xcode capability metadata while retaining Flutter's Debug
  JIT/server allowances. Added a macOS CI job that validates both plist files
  and rejects a reintroduced sandbox key or Xcode capability declaration.

- **Removed mandatory phase-completion independent-review rule** from `AGENTS.md`
  (no longer requires spawning a fresh agent to review each finished phase).
- **Copilot discovery paths (CodeRabbit):** Discover `~/.copilot/settings.json` and
  `.github/copilot/settings.json` / `settings.local.json` as editable settings;
  also surface managed `config.json` when present (no hide/precedence rule).
  Honor `COPILOT_HOME` for CLI user files (absolute paths only; relative/`~`
  values are ignored with a shared warning helper). Discover Cline `~/Cline/Rules` only
  when `~/Documents/Cline/Rules` is absent. Document Copilot loading shared
  `AGENTS.md`. Canonicalize Windows separators in `RegistryPathMatching.isMatch`;
  make glob visit/match caps injectable on `DiscoveryService`; per-entry
  `handleError` on recursive listing (errors count toward the visit cap;
  stop at `maxGlobEntitiesVisited` without exceeding it;
  prefer `FileSystemException.path` in warnings when available).
- **Planning and release hygiene:** Archived completed implementation plans for Services &
  Discovery, JSONC, the design-system prototype, the Flutter SDK, dependency upgrades, and
  Phase 10 tool expansion after the merged CI matrix passed. Kept the macOS and test-root
  plans active for their remaining manual/default-startup and platform-specific verification.
  Replaced the vague semantic-versioning task with an explicit 0.2.0 release checklist; no
  version was bumped outside a release cut.
- **Documentation-link checker:** Exclude ignored `tmp/` scratch artifacts from both default
  and explicit scans, and isolate Markdown-file eligibility from scan control flow.

### Added

- **`docs/PRODUCT_IDEAS.md`:** Long-form product/exploration notes; markdownlint-ignored
  (same class as CHANGELOG — intentional long lines).
- **Phase 10 plan completion notes** in `plans/archive/phase_10_new_tools.md` and
  related `TO_DO.md` backlog for GitHub workflows / review-tool configs.
- **Registry invariant tests.** Added `test/catalog/registry_invariants_test.dart` to verify that `ConfigFormat.markdown` and `ConfigFormat.text` are never routed to the structured parser.
- **RecoveryHandler widget tests.** Added `test/screens/recovery_handler_test.dart`
  (12 cases) covering the corrupt-file recovery dialog via a harness mixin widget;
  filesystem setup and I/O flushes use `WidgetTester.runAsync` because `dart:io`
  futures do not complete in the widget test fake-async zone. Harness helpers
  live in `recovery_handler_test_harness.dart` so each file stays under the
  700-line pre-commit limit. The raw-editor
  read-failure case swaps the file for a directory after the dialog appears so
  `readAsString()` throws on Windows as well as POSIX (no `chmod 000`).
  Recovery action tests poll a harness completion flag (flush I/O + pump)
  instead of a fixed 250 ms delay, because awaiting the dialog Future inside
  `runAsync` deadlocks with fake-async.
- **Phase 5.5 docs-accuracy follow-ups.** Fixed broken relative doc links
  in `ci/README.md`, `hooks/README.md`, and `policies/commits-and-branches.md`;
  removed `inventory/medical-data-security.md`,
  `hooks/phi-security-approvals.json.example`,
  `prompts/strict-phi-agent-guidance.md`, and the strict sensitive-data scripts
  (`hooks/scripts/check_sensitive_data.py` and
  `hooks/scripts/check_commit_message_sensitive_data.py`); cleaned up all
  references across docs, prompts, policies, hooks, and tests; aligned
  `docs/supported-tools.md` display names with `ToolDescriptorRegistry`; added a
  test that asserts every catalog display name appears in
  `docs/supported-tools.md`; reconciled stale claims in
  `.context/project-profile.md`; and removed the resolved
  `changelog-conventions` item from `TO_DO.md`.
- **Semgrep SAST in CI (2026-08-16).** New non-blocking `semgrep` job runs
  `semgrep scan --config p/default --metrics off` (installed with
  `pip install --only-binary :all:` so no dependency setup scripts run —
  Sonar S8541) and uploads SARIF to the
  Security tab (category `semgrep`), covering Dart plus the Python/shell/YAML
  that CodeQL default setup (Python + Actions only) leaves uncovered. Actions
  pinned to commit SHAs; a `.semgrepignore` excludes vendored and generated
  platform code. Also hardened `ci/scripts/check_doc_links.py` to restrict the
  `urllib` scheme to http/https at the sink (Semgrep `dynamic-urllib-use`
  audit finding).
- **Code-scanning alert resolution (2026-08-18).** Shipped changes in PR #8 to
  address open GitHub code-scanning alerts #2, #3, and #5. Dependabot: added
  `cooldown` with `default-days: 7` to `pub` and `github-actions` ecosystems
  (alerts #2, #3). Semgrep: changed bare `# nosemgrep` to rule-specific
  `# nosemgrep: dynamic-urllib-use-detected` on the `urllib.request.urlopen`
  call in `check_doc_links.py` (alert #5); runtime http/https scheme guard
  remains as defense-in-depth. Closure of alerts #2, #3, #5 pending CI and
  Security-tab confirmation.
- **Phase 6A: parse-error recovery (2026-08-18).** Recovery dialog for corrupt
  config files (`RecoveryHandler` mixin in `lib/screens/recovery_handler.dart`).
  Line/column diagnostics on `ConfigParseException` (JSON from offset, YAML from
  `SourceSpan`, TOML from `TomlParserException`). JSONC fallback warning via
  `ToolConfig.parseWarnings`. Restore safety: backup-before-restore with
  exists-guard. `RawDiffView` extracted to `lib/widgets/raw_diff_view.dart`.
- **Nitpick resolution round (2026-08-16).** Tests: `discovered_config_test` drops the const-identical equality check for a real props
  comparison plus inequality and `fromPath` id/normalization coverage;
  `text_config_parser_test` covers the `originalContent` argument and
  uppercase `.MD` extension detection; `history_modal_test` captures
  `restoredPath` outside the callback and asserts it after the confirm flow;
  `discovery_preferences_store_test` asserts the atomic write leaves only the
  preferences file behind (no temp-file residue); `backup_service_test`
  covers per-path pruning past `maxBackupsPerPath`. Refactors:
  `DiscoveryPreferences` preserves unknown JSON keys in `extraFields`;
  `DiscoveryPreferencesStore` extracts a shared
  `_normalizeAndFilterPaths` helper; `ConfigService` uses `listEquals` from
  `foundation`; `BackupService` sorts backups by parsed filename timestamp
  and prunes per-path retention; `ConfigEditor`'s raw diff view truncates at
  20 lines with an expand toggle.
- **Bootstrap follow-through.** The checklist existed but nothing recorded progress, so a
  compacted or resumed session had no way to know where it stopped. Adds stable phase IDs
  (`P0`–`P8`, `PS`); `templates/bootstrap-state.md` → `.context/bootstrap-state.md` for
  per-phase status (`pending`/`in-progress`/`done`/`skipped — reason`) plus a `Next action`;
  and `scripts/check-bootstrap.sh`, which verifies phases by **repo evidence** rather than by
  claims (profile fields, remote repointed, root pre-commit config + installed hook, workflows,
  `.envrc.example`, `.env` not tracked, `.agent-state/` ignored, PS gates when the
  classification is `regulated`). Advisory by default; `--strict` exits non-zero.
  `new-agent-session.md` gained a step 1.5 that resumes an unfinished bootstrap or reads a
  pending handoff.
- **`prompts/bootstrap/` decision cards** — short scripts (ask → answer/action branch table →
  artifacts → done-when) for the five phases with a real branch: data classification, CI tier,
  environment, orchestration, agent tooling. Phases with one obvious path stay single lines in
  the checklist. The checklist previously linked only to reference policies, leaving the agent
  to invent the interview.
- **`inventory/agent-tooling-efficiency.md`** — token-efficient tooling menu distilled from the
  Notes_and_Ideas guide (Context7, Serena, code-review-graph, Graphify, TokenSave,
  chrome-devtools-mcp): role assignment, the overlap warning, CLI-vs-MCP table, adoption
  sequence, and an evidence standard that ranks local evaluation above vendor token claims.
  Default for a fresh scaffold is **install nothing**. Distilled here rather than only linked,
  so the guidance is actionable on its own; the private source is cited for agents with access.
- **`policies/agent-tooling-contract.md`** — the pastable `AGENTS.md` policy block, `.agent-state/`
  untracked, one code-intelligence tool per role, per-tool smoke test, native fallback. New
  bootstrap phase P5.5 and an "Agent tooling" section in the project profile record adopted
  **and rejected** tools, so rejections are not re-litigated.
- **`templates/handoff.md`** — cross-agent/cross-IDE handoff packet (goal, changed files,
  decisions, verified-vs-assumed, next action). Bootstrap §8 now *writes* `.context/handoff.md`
  instead of leaving the handoff in chat, where it evaporates.
- **`ci/scripts/check_doc_links.py`** — three staleness checks for a repo whose entire value is
  cross-linked guidance:
  1. *Internal links* — every relative markdown link resolves. Mechanical and offline, so it
     runs in `template-checks` as a gate (`--internal-only --strict`); `docs/**` and `scripts/**`
     were added to the workflow path filters so doc-only changes trigger it. This immediately
     found five long-standing broken links (`templates/adrs/`, `briefs/`, `plans/`, `designs/`
     in `docs/NAVIGATION.md`, and a wrong `../` depth in `.devin/skills/README.md`), all fixed.
  2. *Link liveness* — external links in `inventory/` still resolve; a GitHub redirect means the
     project was renamed or transferred. Network-dependent, so it stays out of CI.
  3. *Catalog review* — `Last reviewed` asserts the prose is accurate but cannot catch a tool
     whose project was archived while the text still reads fine. Adds an opt-in
     `Catalog reviewed through:` marker with a 120-day window, tighter than the 180-day prose
     window.

  Checks 2 and 3 are deliberately advisory: a rename or a quiet project is a prompt to
  re-evaluate an entry, not grounds to auto-delete it. Wired into `policies/doc-freshness.md`
  and the maintenance loop's inventory review.
- Structural sensitive-data gates: `hooks/scripts/check_gitignore_protected.py` (blocks
  removal of required `.gitignore` rules), `check_forbidden_paths.py` (blocks tracking
  files under never-commit paths), and `check_scan_contract.py` (a git-blob-hash ledger
  that blocks when a required heavy scanner — Presidio text/image, local OCR,
  dicom-phi-scan, phi-scan, HoundDog local, or a local SonarQube CE scan — has not been
  re-run since the files it covers changed). Each is inert until its root config exists.
  Ships `hooks/{gitignore-protected,forbidden-paths}.example` and
  `hooks/scan-contract.json.example`, `policies/sensitive-data-scan-gates.md`, commented
  `.pre-commit-config.yaml` blocks, and smoke tests. Wired into the bootstrap
  medical/regulated trigger, `strict-phi-agent-guidance.md`, `AGENTS.md`,
  `inventory/medical-data-security.md` (also adds a SonarQube CE row), and both READMEs.
- `prompts/bootstrap-checklist.md`: a phase-by-phase tick-list companion to
  `bootstrap-project.md`, including the conditional sensitive-data branch (Phase S).
- `inventory/medical-data-security.md`: added ExifTool (metadata detect/strip),
  Poppler (PDF text/page-image/attachment extraction backend), and pypdf (pure-Python
  text-layer extraction; the strict guard's optional PDF pass) as the extraction/
  sanitization backends feeding the OCR → Presidio redaction chain, plus an
  "extract before you scan" step and cross-references in `hooks/scan-contract.json.example`.
- `template-checks` GitHub Actions workflow: path-filtered validation for maintained
  Markdown, Actions examples, shell hooks, Python policy scripts, and committed secrets.
- `prompts/sensitive-data-leak-prevention.md`: runtime/dev leak-prevention guidance
  (logs, temp files, test/CI output, caches, telemetry, third-party/AI egress) with
  a leak-surface control table, awareness/easy-clearance practices, and verification
  steps. Wired into the bootstrap medical/regulated trigger, `AGENTS.md`,
  `strict-phi-agent-guidance.md`, and `inventory/medical-data-security.md`.
- `policies/sensitive-data-runtime-leaks.md`: registers the runtime-leak rule with
  tiered enforcement (gitignore artifact dirs + strict guard, `make clean-sensitive`,
  log-scanning tests, telemetry-egress review, HoundDog data-flow scan) and clear
  remediation; intentionally no false "redaction" hard gate. Listed in
  `policies/README.md`, `AGENTS.md`, and the bootstrap wiring step.
- `inventory/cloud-and-infra.md`: **Observability & error monitoring** section —
  self-hosted Sentry (`getsentry/self-hosted`), managed Sentry free tier, GlitchTip,
  and OpenTelemetry, with the keep-event-data-on-your-infra / no-BAA-on-free-tiers
  caveat cross-linked to the runtime-leak policy and prompt.

### Fixed

- **URL host checks parse the host instead of substring-matching (2026-08-16).**
  `ci/scripts/check_doc_links.py` now compares the parsed hostname (via
  `_host_matches`/`_url_host`) for both the skip-list and the GitHub-redirect
  check, so a domain can't match at an arbitrary position (e.g. `github.com`
  in a path, or a look-alike host `github.com.evil.example`). Clears the
  CodeQL `py/incomplete-url-substring-sanitization` alert, the matching
  Semgrep finding, and SonarCloud's New-Code Security Rating. The URL is
  parsed once inside a guard so a malformed netloc (`urlsplit` `ValueError`,
  e.g. bad IPv6 brackets) becomes a per-link result instead of crashing the
  whole run.
- **Narrower baseline-parse catch in `saveRawConfig` (2026-08-16).**
  `ConfigService` now catches `Exception` (not `Object`) around the baseline
  reparse, so genuine `Error`s (programming bugs) propagate instead of being
  swallowed as an unparseable baseline. Qodo finding.
- **Glob discovery cap now bounds work, not just results (2026-08-16).**
  `DiscoveryService`'s bounded glob enumeration increments its per-glob counter
  for every matching entry (not only newly-added ones), so the `maxEntries`
  cap bounds the scan even when many matches are duplicates already discovered
  via another target. Qodo/CodeRabbit review finding.
- **Windows path deduplication (2026-08-16).** `DiscoveryPreferencesStore` now dedups and
  matches manual paths / project roots via a platform-aware key (case-insensitive on Windows,
  case-sensitive elsewhere), and `DiscoveryService` keys `seenPaths` the same way, so
  differently-cased spellings of the same file no longer produce duplicate preference entries or
  sidebar rows on Windows. No-op on Linux/macOS-posix. Qodo review finding.
- **`saveRawConfig` baseline reparse guard (2026-08-16).** The internal reparse of the pre-edit
  baseline (`config.originalContent`) used to diff structured edits is now wrapped in try/catch;
  a stale/unparseable baseline no longer throws a `ConfigParseException` indistinguishable from a
  genuine invalid-raw-content error — a valid raw edit is written as-is instead. Qodo review finding.

### Changed

- **Collision-free backup filename encoding (2026-08-16).** `BackupService` now encodes the
  original path via a shared `_encodeOriginalPath` helper (percent-escape `%` first, then the OS
  separator → `%2F` and `:` → `%3A`), replacing the non-injective `sep → __` / `: → _drive_`
  substitution where a literal `__` in one path could alias a separator in another (e.g. `/x/y`
  vs `/x__y`), letting their backups list and prune together. `createBackup` and `listBackups`
  share the helper; a regression test covers the former collision. This changes the on-disk
  `.bak` filename format (no existing backups yet to migrate). CodeRabbit review finding.
- **TOML comment preservation: documented and deferred.** `TomlConfigParser.serialize` stays
  lossy (rebuilds from the parsed map, dropping comments/whitespace/order) because the Dart
  `toml` package has no source-preserving editor, unlike the JSON (`json_ast`) and YAML
  (`yaml_edit`) paths. Qodo finding #12. Options — surgical text-splice for the two edited keys,
  vendoring a TOML AST, or status quo — are captured in
  `docs/adr/ADR-001-toml-comment-preservation.md`, with a follow-up trigger. The parser doc
  comment now points at the ADR.
- Template CI pins Markdownlint and applies the repository's established style choices;
  gitleaks receives the read-only pull-request permission it needs for PR scans.
- **References to the private notes repo: cited, not hidden.** The repo stays private, so
  pointing at `kgrizz-git/Notes_and_Ideas` is encouraged rather than avoided — an agent with
  access should read it, since it is more current than any summary here. Convention is
  `repo → path` marked *(private)* rather than a `github.com` hyperlink, which 404s for anyone
  else and gave the false impression the content was reachable. Provenance added to
  `agent-tooling-efficiency.md`, and `source-repos-to-review.md` now lists useful entry points
  (`reference/tools/`, `reference/agents/`, `info/`, `agents_and_skills/`). AGENTS.md principle
  9 is "recommendations stand on their own" — each entry must be actionable without the source,
  which is a floor on quality, not a ban on citing. Principle 10: multi-phase progress is
  written to `.context/`, not remembered.
- Corrected the Modal entry, which credited the maintainer's notes repo for a `modal` skill
  that actually came from `K-Dense-AI/claude-scientific-skills`; now points at Modal's docs.
- `catalog-skills-agents.md`: the auto-chain rule no longer gets its own section. The per-IDE
  table it carried was really "how to install any always-on rule", so it now says that.
- **Python lint in CI.** `template-checks` now runs `ruff check .` (pinned to 0.11.13 to match
  `hooks/.pre-commit-config.yaml`; a version skew is why "it passed locally" stops being true).
  `compileall` only proved the files parse — proof that was insufficient: an F541 had been
  sitting in `hooks/scripts/check_cleanup_hygiene.sh` on main, now fixed. The pre-commit hook
  alone does not cover it either, since it only protects contributors who ran
  `pre-commit install`, and these scripts are policy gates other repos inherit. Adds `ruff.toml`
  so pre-commit and CI read one rule set. `ruff format` is deliberately **not** gated: 11 of 14
  files predate it and reformatting is a separate reviewable change.
- CI path filters gained `docs/**`, `scripts/**`, `tests/**`, `scaffolds/**`, and `ruff.toml`,
  so doc- and Python-only changes actually trigger the checks that cover them.
- **Secret scan no longer breaks on a repo's first push.** `gitleaks-action@v2` derives a range
  from the push event and runs `git log <before>^..<after>`, which fails with "ambiguous
  argument" whenever a push contains the root commit — i.e. the first push of every project
  bootstrapped from this template. Replaced with a pinned, checksum-verified `gitleaks detect`
  over full history: more thorough and immune to the edge case. Drops the now-unneeded
  `pull-requests: read` permission.
- **Removed the stale agent worktree** at `.claude/worktrees/naughty-payne-0208df` (45 MB,
  detached HEAD at an ancestor of `main`, holding the staged-but-reverted `notes_and_ideas/`
  tree). Nothing was tracked in the index, and it had no unique commits. `.gitignore` now
  covers `.claude/worktrees/`, `.worktrees/`, and `worktrees/` — previously this was only in
  `.git/info/exclude`, which is machine-local and would not survive a fresh clone.
- `.gitignore`: added `.agent-state/`, `.serena/`, `.aider*`, `.tokensave/` — rebuildable agent
  indexes and local state.
- `docs/NAVIGATION.md`: fixed five links to template directories that never existed
  (`templates/adrs/`, `briefs/`, `plans/`, `designs/` → the actual flat files).

### Fixed

- Unresolved-path recovery Skip now re-checks `mounted` and `loadGeneration`
  before clearing editor state. Restore-from-history writes through
  `BackupService.writeRestoredFile` so missing parent directories are created.

## [0.4.4] - 2026-07-09

### Added

- `ci/scripts/check_open_prs.py` — advisory `gh pr list` helper with `--branch`,
  `--once-per-day` stamp under `.context/`, and `--json`.
- `ci/examples/open-prs-advisory.yml` — optional daily/advisory Actions reminder
  (`continue-on-error`; never a required check).
- Agent wiring: `policies/commits-and-branches.md`, `prompts/new-agent-session.md`,
  `prompts/maintenance-loop.md`, `AGENTS.md`, `hooks/README.md`, `ci/README.md`.
- Smoke tests for `--help` and once-per-day stamp skip.

### Changed

- Daily open-PR guidance: agents must inspect `.context/open-prs-check.stamp`
  first and skip the script when fresh (token-cheaper than invoking Python/`gh`).

## [0.4.3] - 2026-07-09

### Added

- Archon (`coleam00/archon` / archon.diy) under harness + ai-agent-platforms.
- Pantheon (pantheon.k-dense.ai) under tools-index research + catalog K-Dense section.
- Cross-IDE handoff options (Passoff, handoff, ai-sync) with Reddit discussion seed.
- Sphinx/Pandoc expanded blurbs in `tools-index.md` documentation section.

## [0.4.2] - 2026-07-09

### Added

- `inventory/knowledge-graph-code-mapping.md`: section **AI-generated code wikis & repo
  documentation** — Google Code Wiki, DeepWiki SaaS, deepwiki-open, RepoWiki,
  FSoft CodeWiki, repowise (+ vs-DeepWiki comparison), Ry Walker survey link.

## [0.4.1] - 2026-07-09

### Added

- `policies/github-actions-usage.md` — estimate minutes/storage when changing CI;
  use GHA deliberately (not fearfully, not carelessly).
- `ci/scripts/check_gha_usage.py` — repo run timing + account billing usage summary
  via `gh` (consolidated billing API; legacy actions/shared-storage endpoints retired).

### Changed

- `inventory/search-apis.md`: Firecrawl listed as a crawl tool only (removed API-key
  dashboard / Notes_and_Ideas credential wording from that entry).
- `ci/README.md` / `AGENTS.md`: link usage policy and script.

## [0.4.0] - 2026-07-09

### Added

- Policies: `changelog-conventions.md`, `plans-and-todos.md`; `plans/README.md`.
- Hook: `check_todo_limits.py` (soft 150 / hard 300 lines); optional `prune_backups.sh`.
- Smoke tests: `tests/test_policy_hooks_smoke.py` (unittest) for TODO/file-size hooks.
- Inventory: Salesforce 7 patterns; Osmani harness/factory/long-running; Graphify+NetworkX;
  GraphRAG Workbench; Codex Security plugin; GitHub license compliance preview; Firecrawl
  (product only — no API keys in-repo).
- Agent stubs (`GEMINI.md`, `QWEN.md`, `CLAUDE.md`) clarified as pointers to `AGENTS.md`.

### Changed

- File-size soft/hard defaults: 600 / 1000 lines (was 400 / 800).
- `hooks/README.md` documents existing gitleaks + lint hooks alongside new policy checks.

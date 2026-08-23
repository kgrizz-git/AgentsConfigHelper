# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"
- [ ] Review [`docs/PRODUCT_IDEAS.md`](docs/PRODUCT_IDEAS.md) — a backlog of ideas to make the app more useful, full-featured, user-friendly, and intuitive. Later choose which to implement and write a plan in `plans/active/`.

## Product follow-ups (prioritized)

### Recommended delivery order

1. **Structured-content vertical slice:** write a focused plan for one well-documented,
   high-value permission schema. Build schema metadata and read-only cards first; add
   editing only after lossless/minimal-patch fixture coverage is proven.
2. **Plain-language help:** attach reviewed explanations and authoritative documentation
   links to the schema metadata introduced by the vertical slice.
3. **Window sizing:** implement as a small independent quality-of-life change whenever a
   short PR is useful; it should not delay the safety or structured-editing work.
4. **Broaden tool schemas incrementally:** use real-world, redacted staging fixtures and
   regression tests to select each next schema rather than treating every format alike.
5. **Finish testing regression coverage:** keep the proven macOS staging workflow maintained,
   add the default-startup harness and unsupported nested-structure raw-editor fixture, and
   defer Linux/Windows test-root work until their platform-native bridges are planned.

- [ ] **Project workspace labels:** Make project-scope sidebar entries distinguish their root
      (for example, `workspace — AGENTS.md`) instead of repeating only the tool/file name.
      Then consider user-editable project aliases stored in discovery preferences; preserve the
      canonical path for matching, handle duplicate names clearly, and add migration/widget
      coverage before exposing rename controls.

- [ ] **High priority — safe exploratory testing environment:** Research and document a
      repeatable way to exercise discovery and editing against realistic agent/IDE
      configurations without risking a developer's real files. Start with token-free
      fixture files plus the macOS-only `--test-root` mode to exercise automatic discovery,
      editing, backup, and restore without touching a real config. First add a script that
      creates a marked root and a manual smoke checklist; then compare isolated OS users
      and VMs for native-platform validation. Docker is supplementary for Linux, not the
      primary desktop/macOS answer. Define setup/teardown, backup/restore checks, and what
      can be automated in CI. (See
      [docs/testing-strategies.md](docs/testing-strategies.md) and the implementation
      [plan](plans/active/safe-testing-foundation.md), with test-root implementation
      details in [its focused plan](plans/active/test-root-containment.md)).
- [ ] **Structured configuration presentation:** Expand parsers and UI models so supported
      configuration formats can present discovered rules, permissions, and settings as
      focused widgets/cards rather than only raw syntax. Start with tool-schema metadata
      and a single high-value read-only card; preserve a faithful raw-editor fallback for
      unsupported or ambiguous content. Enable editing only after lossless/minimal-patch
      fixture coverage, then add parser/UI tests per schema. (See gap analysis in
      [docs/research/config-structured-editing-gap.md](docs/research/config-structured-editing-gap.md))
- [ ] **Plain-language configuration help:** For the structured rule/permission UI, add
      contextual hover help that explains each setting in plain language and links to the
      owning tool's authoritative documentation. Design a versioned metadata source,
      ensure links are tool-specific and reviewable, and keep unknown settings visibly
      unclassified rather than inventing explanations.
- [ ] **Desktop window sizing:** Open the app at a more useful default size (target about
      75% of available screen width and height) and/or persist the user's last valid
      window size and position. Research Flutter desktop APIs and platform constraints,
      including sensible minimums and bounds restoration when displays change; add
      cross-platform tests or manual verification guidance before implementation.

## Tool-support gaps (discovery expansion)

Track candidates that are not agent/IDE tools but still have useful project- or user-level
config files this app could discover and edit (raw-text / YAML / JSON / TOML as appropriate).
Research exact paths and formats before adding `ToolId`s; prefer files users actually edit
over generated CI caches.

### GitHub Actions, workflows, and repo automation

- [ ] **GitHub Actions workflows** — `.github/workflows/*.{yml,yaml}` (CI, release, PR
      checks). Decide whether to treat each workflow as its own sidebar entry or group under
      one “GitHub Actions” tool.
- [ ] **Dependabot** — `.github/dependabot.yml` / `.github/dependabot.yaml`.
- [ ] **Common `.github/` configs** — e.g. `CODEOWNERS`, `FUNDING.yml`,
      `ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE*`, `labeler.yml`, `actionlint` config if
      present. Pick a small high-value subset rather than every file under `.github/`.
- [ ] **Renovate** (adjacent to Dependabot) — `renovate.json`,
      `.github/renovate.json`, `renovate.json5` (if we want dependency-bot parity).

### Code quality, security, and docs platforms

Add first-class discovery only where there is a durable on-disk config (skip pure SaaS UI
settings with no repo/global file).

- [ ] **SonarQube / SonarCloud** — `sonar-project.properties`; also note scanner keys
      embedded in `build.gradle` / `pom.xml` / CI env (may stay docs-only).
- [ ] **CodeRabbit** — `.coderabbit.yaml` (repo root; org/UI layers are not files).
- [ ] **Qodo / PR-Agent** — `.pr_agent.toml` (and any successor Qodo config filenames).
- [ ] **DeepSource** — `.deepsource.toml`.
- [ ] **Semgrep** — `.semgrep.yml` / `.semgrep.yaml`, `.semgrep/` rule packs; CI workflow
      wrappers are covered under GitHub Actions if those are added.
- [ ] **CodeQL** — `.github/codeql/codeql-config.yml` (and related query-suite configs);
      workflow YAML may already be covered by Actions discovery.
- [ ] **Mintlify** — `docs.json` / `mint.json` (docs site config).
- [ ] **Other common adjacent configs (evaluate)** — `codecov.yml` / `.codecov.yml`,
      `.pre-commit-config.yaml` (if not already discoverable), `.mdlrc` /
      `.markdownlint.yaml`, `actionlint.yaml` — only add if they fit the product story.

## Follow-ups from Phase 5.5 (docs accuracy)

- [ ] Add a README screenshot or GIF to `assets/screenshots/` (blocked on user — an agent cannot capture a running Flutter desktop GUI). README currently shows a placeholder badge.

## Deferred from PR #5 review (Qodo / SonarCloud)

- [ ] Wire SonarCloud coverage reporting: switch from Automatic Analysis to a
      CI `sonar-scanner` step and set `sonar.dart.lcov.reportPaths=coverage/lcov.info`
      so coverage shows on all branches (currently 0.0% everywhere — Automatic
      Analysis cannot ingest lcov). The `test` job's 80% lcov gate already
      enforces coverage independently.
- [ ] Extract config persistence out of the widget layer: `MainShell` calls
      `ConfigService.saveConfig`/`saveRawConfig` directly, and `HistoryModal`
      reaches data via `backupListProvider`. Consider a dedicated save
      controller/notifier so widgets stay presentation-only (Qodo architecture
      findings — deferred, likely not worth doing). The current save callback
      in `MainShell` is already a clean 3-step orchestration (call service,
      invalidate provider, setState) that `AGENTS.md` explicitly permits.
      Extracting a full Riverpod controller would create split-brain state
      (controller updates via Riverpod while loading/error/dirty stays as
      setState) with no user-facing benefit. Only revisit if a concrete
      testability gap emerges that the existing `onSave` injection point on
      `ConfigEditor` cannot cover.
- [ ] Revisit TOML lossless round-trip: `ConfigService.saveRawConfig` re-serializes
      through `parser.serialize` when structured edits diverge from the raw
      baseline, which drops comments/whitespace for TOML (serializer is not
      AST-preserving). See ADR referenced in `toml_config_parser.dart`.
- [ ] Adjust the Qodo dashboard settings for Python false positives — **only if the
      noise persists**. The repo-side fix already shipped (Dart-vs-Python note in
      `AGENTS.md`, `.pr_agent.toml` with scoped `extra_instructions`, no checks
      disabled), so what remains is the Python-3.8-baseline assumption and any
      org-level Compliance-tool toggle. Both live at qodo.ai, not in this repo —
      nothing to change here unless the dashboard is the cause.

## Deferred from Phase 10 / CodeRabbit Hy3 review

- [ ] **Discovery `handleError` stack traces** — per-entry glob listing warnings
      now prefer `FileSystemException.path` when present; still record `$error`
      only (no stack). Consider logging `StackTrace` via the app logger
      (if/when one exists) for harder permission/IO failures.
- [ ] **Windows case-insensitivity tests** — non-glob matching uses `path.equals`
      (platform-aware); globs use `caseSensitive: !Platform.isWindows`. Add an
      injectable `caseInsensitive` override (like discovery caps) so CI on
      ubuntu can exercise both Windows behaviors without a Windows runner.
- [ ] **Copilot `config.json` write policy** — file is labeled managed CLI state
      (auth/plugins) but remains a writable `structuredConfig` target. Decide
      whether to warn, mark read-only in UI, or leave editable; track as a
      follow-up (pre-existing risk, not introduced by Phase 10).

## AI Agent Integration

- [ ] If we ever integrate AI agent calls directly into the app (e.g., for automated config fixes), ensure that any secret-bearing configuration files (like `models.json` or `kilo.jsonc`) have their API keys and sensitive environment variables redacted *before* the context is sent to the agents.

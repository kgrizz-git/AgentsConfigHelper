# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"
- [ ] Review [`docs/PRODUCT_IDEAS.md`](docs/PRODUCT_IDEAS.md) — a backlog of ideas to make the app more useful, full-featured, user-friendly, and intuitive. Later choose which to implement and write a plan in `plans/active/`.

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

## AI Agent Integration

- [ ] If we ever integrate AI agent calls directly into the app (e.g., for automated config fixes), ensure that any secret-bearing configuration files (like `models.json` or `kilo.jsonc`) have their API keys and sensitive environment variables redacted *before* the context is sent to the agents.

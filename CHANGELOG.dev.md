# Developer Changelog

Internal / developer-facing changes that do not belong in the public
[`CHANGELOG.md`](CHANGELOG.md). See [`policies/changelog-conventions.md`](policies/changelog-conventions.md).

## Unreleased

### Changed

- **Removed mandatory phase-completion independent-review rule** from `AGENTS.md`
  (no longer requires spawning a fresh agent to review each finished phase).
- **Copilot discovery paths (CodeRabbit):** Discover `~/.copilot/settings.json` and
  `.github/copilot/settings.json` / `settings.local.json` as editable settings;
  also surface managed `config.json` when present (no hide/precedence rule).
  Honor `COPILOT_HOME` for CLI user files (absolute paths only; relative/`~`
  values are ignored with a warning). Discover Cline `~/Cline/Rules` only
  when `~/Documents/Cline/Rules` is absent. Document Copilot loading shared
  `AGENTS.md`. Canonicalize Windows separators in `RegistryPathMatching.isMatch`;
  make glob visit/match caps injectable on `DiscoveryService`; per-entry
  `handleError` on recursive listing (errors count toward the visit cap;
  prefer `FileSystemException.path` in warnings when available).

### Added

- **`docs/PRODUCT_IDEAS.md`:** Long-form product/exploration notes; markdownlint-ignored
  (same class as CHANGELOG — intentional long lines).
- **Phase 10 plan completion notes** in `plans/active/phase_10_new_tools.md` and
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

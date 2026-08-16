# Phase 5.5: Documentation Accuracy & Polish

**Status:** active
**Created:** 2026-08-15
**Source audit:** `tmp/docs-accuracy-assessment-2026-08-15T1335.md`
**Master plan anchor:** `plans/active/initial_master_plan.md` → "Phase 5.5: Documentation Accuracy & Polish"
**Profile:** `.context/project-profile.md`

> **Verification note:** Every finding below was re-confirmed against the current working tree on
> 2026-08-15 (after commits `6bfcc2f`, `a9052f9`, `29020c7`, `ca2b7d9`, `f43ab9f`). All code
> references were grepped live; the doc claims are still inaccurate as described. No code changes
> from those commits affected the findings.

---

## Goal

Bring the user-facing and contributor docs in line with the shipped codebase and raise the
README's professionalism, so the project reads like a credible OSS desktop app. This phase is
**docs-only** (plus one cheap test and one vendoring note); it introduces no app behavior changes
other than correcting prose and adding a license/screenshot.

---

## Scope

### In scope (docs to reconcile)

- `README.md`, `ARCHITECTURE.md`, `docs/NAVIGATION.md`, `CHANGELOG.md`, `CHANGELOG.dev.md`, `DESIGN.md`.
- **`AGENTS.md` (committed — the agent contract):** it repeats the same stale claims this phase fixes
  elsewhere (`AGENTS.md:11` 8-tool/"Claude" list; `AGENTS.md:38` "diff/undo"), so it MUST be
  reconciled or the phase leaves the repo's most-read entrypoint contradicting its own docs.
- `docs/supported-tools.md` (source of truth for tool list; not hand-edited, just linked).
- Add missing project artifacts (LICENSE, README screenshot, badges, status line).
- Document vendored dependency provenance.
- Add a cross-doc consistency test (see M3 — **no inline HTML marker**).

### Out of scope / explicitly excluded

- `.context/project-profile.md`: gitignored, local/generated "fast-load" artifact (per
  `docs/NAVIGATION.md:62`), NOT shipped docs. It does repeat stale claims ("sync", "call external
  CLIs", "diff/undo", and an *unresolved* backup-location question at `:72`). Because `AGENTS.md:21`
  tells agents to read it first, it is recorded here as a **tracked follow-up** (append to
  `TO_DO.md`): reconcile or regenerate it so it matches the shipped code. Not edited in this phase.
- Backup retention / pruning (tracked in `TO_DO.md`; H2 in the audit).
- CLI Integration Service (only mark it `(planned)`; not building it).
- "Sync" feature (deferred; belongs to Phase 7 Templates & Syncing, not V1).

> **Review history:** This plan was reviewed twice after drafting. (1)
> `tmp/assessment_20260815_234941.md` flagged gaps vs `AGENTS.md` governance rules (all applied).
> (2) `tmp/docs-phase-5.5-plan-assessment-2026-08-16T0005.md` confirmed the core findings, then added
> the B1 scope gap (`AGENTS.md`/`.context/` not in scope), the B2 redundant-drift-test finding, and a
> set of citation-accuracy nits (A1–A6, C1). Those are incorporated below.

- Real "sync" / multi-file propagation (Phase 7 already covers template syncing).

---

## Findings → Work items (prioritized)

Severity: **H** = materially misleading / security-relevant · **M** = inaccurate, low-risk ·
**L** = polish.

### H1. Remove the "sync" capability claim from README (and Master Plan)

- **Where:** `README.md:3` ("visualize, edit, **sync**, and manage"); `initial_master_plan.md:9` (Goal); `initial_master_plan.md:28` ("Integrate CLI hooks for agents that expose configuration commands"); `initial_master_plan.md:27` (".bak creation" predates the centralized-store decision).
- **Evidence:** No sync / cross-target write / reconciliation code exists in `lib/`. `ARCHITECTURE.md:35` already says "No Cloud Sync: Version 1 has no networking component." (Cross-file "reconciled" wording in `config_service.dart:123` refers to text re-serialization, not a sync mechanism.) A literal `sync` grep returns only `async`/`AsyncValue` substring matches plus one comment (`discovered_config.dart:86` "Keep id synchronized"); no sync feature exists.
- **Action:** Drop "sync" from the README tagline. If a sync narrative is wanted, move it to a clearly-labeled "Roadmap" section mirroring Phase 7 (Templates & Syncing).
- **Master Plan reconciliation (do NOT erase history):** Per `AGENTS.md:80-81` plan files must reflect what shipped while preserving original goals as history. Do **not** delete the Master Plan's stale "sync"/"CLI hooks" wording — instead annotate it inline, e.g. append ← `(deferred: moved to Phase 7 Templates & Syncing; V1 is local-only, no networking)`, and for the Phase 2 "`.bak` creation" note append ← `(implemented as app-support-dir backups via BackupService, not alongside originals)`. Keep the original goal text intact.

### H2. Correct the backup-location note (security-relevant)

- **Where:** `README.md:49` ("these backups are stored **alongside the original files**"). (Line 48 opens the "Note on Backups and Secrets" block; the claim is on 49.)
- **Evidence:** `lib/main.dart:14-15` creates `<appSupport>/backups`; `BackupService` (`lib/services/backup_service.dart:43-53`) encodes the original absolute path into the `.bak` filename and writes to that dir. No `.bak` is ever placed next to the original.
- **Action:** Rewrite the note to state the true per-OS location (resolved by code, not an open question):
  - macOS: `~/Library/Application Support/<reverse-DNS bundle id, e.g. com.example.agentsconfighelper>/backups`
  - Linux: `~/.local/share/<app>/backups` (or `$XDG_DATA_HOME`)
  - Windows: `%APPDATA%\<app>\backups`
  Disclose that (a) backups accumulate without automatic pruning, (b) filenames encode original absolute paths (usernames/project names), (c) they are outside the user's `~/.claude/` etc. protections, and (d) how to purge them. Also reconcile `ARCHITECTURE.md:19` ("`.bak` or app-data folder") — only the app-data branch is implemented. Also **close the same open question** in `DESIGN.md:56` ("Should backups live next to the original file … or in a centralized app data directory?") with one line: "Resolved: centralized `<appSupport>/backups`."
- **Follow-up (track in `TO_DO.md`, do NOT implement here):** backup retention/pruning and a "Reveal backups folder" action. Per `AGENTS.md:78` deferred work is tracked in `TO_DO.md`; append an entry there (and mark it done per `AGENTS.md:87` when shipped). Do not open a separate GitHub issue unless the user requests one.

### H3. Mark the ARCHITECTURE "CLI Integration Service" as planned

- **Where:** `ARCHITECTURE.md:20`.
- **Evidence:** `lib/services/` has exactly five files (`backup_service`, `config_service`, `discovery_preferences_store`, `discovery_service`, `home_directory_resolver`). No `Process.run`/`Process.start` anywhere in `lib/`. The adjacent Config Validation Service is already correctly marked `(planned)`.
- **Action:** Append `(planned)` and add a one-line note that the V1 design is deliberately local-file-only (no agent-CLI subprocesses), so this is a deliberate future decision, not an omission. This also resolves the ARCHITECTURE/README "local-only" consistency.

### M1. Split structured formats from instruction documents in README

- **Where:** `README.md:10` ("JSON, YAML, TOML, and **Markdown** config formats natively").
- **Evidence:** `lib/parsers/text_config_parser.dart` is pure passthrough (`serialize` returns `originalContent` unchanged; doc says "never reformatted or rewritten"). The codebase models this via `ConfigSourceKind.structuredConfig` vs `ConfigSourceKind.instructionDocument`.
- **Action:** Group features into "Structured configs (JSON/JSONC, YAML, TOML) — comment-preserving edits" and "Instruction docs (Markdown/text such as CLAUDE.md, AGENTS.md, .mdc) — raw text editing." Mirror the existing `ConfigSourceKind` vocabulary.

### M2. Reword "undo mechanisms" → backup restore

- **Where:** `README.md:11` ("Includes diff previews and **undo mechanisms**").
- **Evidence:** Diff preview is real (`config_editor.dart:163` `_showDiffModal`; line 162 is its doc comment), tested via `test/widgets/config_editor_test.dart:166` and `history_modal_test.dart:23`. "Undo" does not exist as an in-session undo stack; the only revert path is timestamped backup restore (`history_modal.dart`, `BackupService.restoreBackup`, wired at `main_shell.dart:118-131`).
- **Action:** "Diff preview before every write, plus timestamped backups with one-click restore." Keep "Local-only file operations with a strict backup-before-write policy" (accurate).

### M3. Sync supported-tool list to the registry

- **Where:** `README.md:5` lists 8 tools (Claude, Codex, Opencode, Paseo, Cursor, Kiro, Devin, Antigravity). `lib/catalog/tool_descriptor_registry.dart` has **9** (`ToolId` enum incl. `agyAcp` / "Agy-ACP", `~/.openab/agy-acp/sessions.json`). Also rename "Claude" → "Claude Code" to match `displayName`.
- **Action:** Replace the prose list in README with a link/table to `docs/supported-tools.md`, which `AGENTS.md:27,49,74` already mandates as the single source of truth for supported tools. Do **not** maintain a separate inline 9-item list — manual duplication is exactly the drift this phase is fixing. If a short inline summary is desired, generate it from `ToolDescriptorRegistry` (e.g., a build step or a code comment), not by hand.
- **AGENTS.md reconciliation (committed agent contract):** `AGENTS.md:11` repeats the same 8-tool/"Claude" list and `AGENTS.md:38` repeats the "diff/undo" overstatement — fix both to match the registry ("Claude Code" + 9 tools incl. `agy-acp`) and "backup-before-write with diff + restore" wording.
- **Guardrail (optional, low-risk, no HTML marker):** `test/catalog/tool_descriptor_registry_test.dart:9-19` already locks `catalog.length == 9`, so do NOT add a redundant count assertion. If a genuine cross-doc guardrail is wanted, assert that `docs/supported-tools.md` names every `catalog[i].displayName` (a real consistency check with no manual count to maintain, and no `<!-- TOOL_COUNT -->` marker). Note markdownlint currently leaves MD033 enabled, so an inline-HTML marker could trip the pre-commit hook — another reason to avoid it.

### M4. Resolve CHANGELOG version conflict

- **Where:** `CHANGELOG.md:10` newest entry `## [0.4.4] - 2026-07-09`; header says "user-facing / **template-consumer** changes." `VERSION` = `0.1.0`; `pubspec.yaml:19` = `0.1.0+1`.
- **Evidence:** The changelog is the upstream template's history, not the app's.
- **Action:** Reset `CHANGELOG.md` to an app changelog with a top entry `## [0.1.0] - <today>` describing the initial shipped feature set. Keep the Keep-a-Changelog / SemVer framing.
- **Template history disposal:** Do **not** move the inherited scaffold history into `CHANGELOG.dev.md` — `AGENTS.md:84-86` strictly scopes that file to the app's developer-only changes (hooks internals, inventory menus, tests/CI), and mixing in template history violates that separation. Instead either (a) drop it, or (b) move it to a dedicated `CHANGELOG.template.md` archiving the upstream scaffold's history, clearly labeled as inherited. Prefer (a) unless the user wants the history retained.
- **`CHANGELOG.dev.md` audit (verification sub-step):** Confirm its existing entries describe *app* developer-only changes (hooks, tests/CI, models), per `AGENTS.md:84-86`. If any inherited scaffold/bootstrap entries remain, clear or archive them so the dev changelog reflects the app, not the template.

### M5. De-template `docs/NAVIGATION.md`

- **Where:** `docs/NAVIGATION.md:5,22` ("this template", "I want to understand this template"); "Last reviewed: 2026-07-27" (oldest in repo).
- **Evidence:** The file still frames the repo as a scaffold and routes readers to bootstrap prompts; AGENTS.md:15 points agents here as primary navigation.
- **Action:** Rewrite for the app's actual docs, or narrow its scope to "meta/tooling docs inherited from the scaffold." Update `Last reviewed:`.

### L1. Surface the real CI quality gates + badges

- **Where:** `README.md:31` (mentions line limits, `very_good_analysis`, `gitleaks` but undersells).
- **Evidence (`.github/workflows/ci.yml`):** `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`, `dart_code_linter` metrics at warning level, **80% min coverage** (vendor excluded), `gitleaks` full-history, and a real **3-OS release build matrix** (macOS/Linux/Windows). CI pins GitHub Actions to commit SHAs; pre-commit pins its hook repos by version tag (`.pre-commit-config.yaml` uses `gitleaks v8.21.2`, `pre-commit-hooks v5.0.0`, `markdownlint-cli v0.44.0`, `shellcheck-py v0.10.0.1`).
- **Action:** State the coverage floor and 3-OS matrix explicitly; add status/license/platform badges near the top. These are the strongest trust signals.

### L2. Add LICENSE + License section

- **Where:** repo root has no LICENSE; `README.md` has no licensing section; `plans/active/initial_master_plan.md` invites contributions.
- **Evidence:** Repo is public (`github.com/kgrizz-git/AgentsConfigHelper`); absence of a license means default copyright and no legal basis to contribute/reuse.
- **Action:** Add `LICENSE` (MIT recommended; Apache-2.0 acceptable), add a short License section. Compatibility gate: `lib/vendor/json_ast/` is MIT-licensed (confirmed `lib/vendor/json_ast/LICENSE`, © 2019 json_ast authors). MIT and Apache-2.0 are both compatible with it. If the top-level license is **Apache-2.0**, you MUST reproduce the `json_ast` MIT copyright notice and permission text in the repo (e.g., a `THIRD_PARTY_LICENSES` / `/licenses` file) — do not ship Apache-2.0 alone and drop the vendored MIT notice. If MIT is chosen, the MIT notice is already satisfied by the vendored file. **Decision owner:** the maintainer. **Recording location:** a `## License` section in `README.md` + close/resolve `TO_DO.md:6` ("add a third party license file") — use the consistent name `THIRD_PARTY_LICENSES` for the vendored-notice file so the plan and TO_DO agree.

### L3. Document vendored `lib/vendor/json_ast/`

- **Where:** `ARCHITECTURE.md:25` lists `json_ast` alongside `yaml_edit` as if both are deps; `yaml_edit` is a pub dep (`pubspec.yaml:44`), `json_ast` is **vendored** into `lib/vendor/json_ast/`.
- **Evidence:** `pubspec.yaml` has no `json_ast`; `lib/vendor/json_ast/` ships 7 source `.dart` files (`error`, `json_ast`, `location`, `parse`, `parse_error_types`, `tokenize`, `tokenize_error_types`) plus a `utils/substring.dart` and its own `LICENSE`. CI coverage deliberately excludes `/vendor/`.
- **Action:** Add `lib/vendor/json_ast/README.md` recording upstream source, version/commit, license, and rationale for vendoring + any local edits. Clarify in ARCHITECTURE that it is vendored, not a dependency.

### L4. README prose + prerequisites polish

- README: one-line description, "Project status: early development (0.1.0)" line, "Last reviewed:" line (matches AGENTS.md/ARCHITECTURE.md/`docs/supported-tools.md`), fix `e.g.` punctuation (file uses `e.g.` without a comma, at `README.md:9`), drop "etc." after `e.g.`, relabel `docs/supported-tools.md` from "Internal research" to "configuration reference".
- **Screenshot / GIF (requires user, do NOT attempt as an agent):** An AI agent cannot capture a running Flutter desktop GUI. Add a placeholder section in the README referencing `assets/screenshots/` and **ask the user to provide** a screenshot/GIF (or run `flutter run -d macos` and capture one). Do not invent an image path or fabricate a screenshot. Mark this item explicitly blocked-on-user in the phase's status until provided.
- Getting Started: pin a minimum Flutter version (CI uses `3.44.9`; `pubspec.yaml` requires Dart `^3.12.2`); add per-OS prerequisites — especially Linux `ninja-build` + `libgtk-3-dev` (installed at `ci.yml:110`, not `:107-108`), without which a Linux contributor hits a build failure.

---

## Recommended README structure (target)

1. Title + one-liner + badges (CI, license, platforms, Flutter).
2. Screenshot / short GIF.
3. Project status ("Early development (0.1.0)") + one-line scope.
4. Why (the real problem: agent config scattered across `~/.claude/`, `~/.codex/`, `.cursor/`, in four formats with divergent permission models).
5. Features — split **Available now** vs **Planned**; use the structured vs instruction-document split.
6. Supported tools — table synced to `ToolDescriptorRegistry`, linking to `docs/supported-tools.md`.
7. Getting Started — pin Flutter version; per-OS prerequisites; Run-from-source vs Build release.
8. How it works / Safety model — corrected backup location + retention caveat, diff-before-write, comment preservation, restore flow; fold the corrected Data Privacy note in here.
9. Development — commands + enforced quality gates (coverage floor, 3-OS matrix, secret scan) + pre-commit setup.
10. Contributing + License + links to `ARCHITECTURE.md` / `AGENTS.md` / `docs/supported-tools.md`.

---

## Execution order

1. **H1, H2, H3** — correctness/trust fixes (README tagline, backup note, ARCHITECTURE CLI service). Include Master Plan reconciliation from H1.
2. **M1, M2, M3, M4, M5** — wording accuracy (Markdown, undo, tool list + drift test, changelog, NAVIGATION).
3. **L2** — LICENSE (unblocks the Contributing section).
4. **L1, L3, L4** — CI gates + badges, vendor provenance, prerequisites/prose/screenshot/status line.

---

## Verification (don't close the phase until green)

- [ ] `flutter analyze --fatal-infos` still passes (no app code changed; only if the cross-doc consistency test is added).
- [ ] `flutter test` passes (incl. the optional `docs/supported-tools.md` ↔ `catalog` consistency test, if added).
- [ ] `dart format --output=none --set-exit-if-changed .` clean.
- [ ] `markdownlint` clean on edited docs (markdownlint runs in **pre-commit**; CI runs `dart format`, `flutter analyze`, `dart_code_linter:metrics`, `flutter test --coverage`, `gitleaks`, and the 3-OS build matrix — keep both gates green per `.markdownlint.yaml`).
- [ ] Manual check: each README/ARCHITECTURE/AGENTS.md claim maps to a live `lib/` fact from this plan's Evidence fields.
- [ ] `CHANGELOG.md` top entry is `0.1.0` and header no longer says "template-consumer".
- [ ] `docs/NAVIGATION.md` has no "this template" phrasing; `Last reviewed:` updated.
- [ ] `AGENTS.md:11` (tool list) and `AGENTS.md:38` (undo) reconciled to match registry/restore wording.

## Done criteria

All H/M/L items either completed or explicitly deferred with a tracked follow-up (backup pruning
tracked in `TO_DO.md`; CLI service stays `(planned)`; sync annotated as deferred/moved to Phase 7 in
the Master Plan). README, ARCHITECTURE, and **AGENTS.md** are internally consistent with each other
and with the code, and the Master Plan's original goals are preserved (annotated as deferred, not
erased).

> **Severity note:** H3 (CLI Integration Service) is prose inaccuracy, not security — arguably M;
> H1's "security-relevant" tag is better read as "materially misleading" (credibility/messaging
> mismatch, no actual exposure). Both stay H for triage emphasis; the distinction is recorded here.

- [ ] **`.context/project-profile.md` follow-up:** append a `TO_DO.md` entry to reconcile (or
      regenerate) `.context/project-profile.md` so it matches shipped code — its `:9` "sync", `:25`
      "call external CLIs", `:65` "diff/undo", and `:72` open backup-location question are stale.
      It is gitignored (not shipped), so it is explicitly out of scope for this phase but tracked.
- [ ] **Archive this plan:** Per `AGENTS.md:82-83`, when the phase is fully complete, move this
      file from `plans/active/phase_5.5_docs.md` to `plans/archive/phase_5.5_docs.md` (do not
      delete). Keep the deferred-item annotations in the archived copy as history.
- [ ] **Update `TO_DO.md`:** Remove any items this phase closes (per `AGENTS.md:87`); leave deferred
      items (backup pruning, `.context/` profile reconciliation) tracked there.

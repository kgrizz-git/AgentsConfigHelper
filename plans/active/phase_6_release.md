# Plan: Phase 6 — Polish, Error Handling & Build Readiness

**Status:** DRAFT — **NEEDS REVIEW**
**Last drafted:** 2026-08-18
**Owner:** (unassigned)
**Depends on:** Phase 5.5 complete (archived 2026-08-17); master plan §Phase 6 stub
(`plans/active/initial_master_plan.md:108`). This plan supersedes that stub and should
replace its `*[Link to be created]*` placeholder once reviewed.

> **Review note:** This is a first draft for review, not an approved plan. Open questions and
> explicit reviewer checkpoints are called out inline as **[REVIEW]**. Do not start
> implementation until the placeholder in the master plan is updated to point here and the
> review items are resolved.

## Goal

Get the app ready for a **local build**: robust error handling for corrupted configs,
clean build settings across macOS/Windows/Linux, and user-facing release notes. Also
folds in one deferred correctness bug fix from `TO_DO.md` (manual-path removal, Qodo #10)
because it is release-relevant and low-risk to land now.

**Scope boundary:** "Build readiness" = `flutter build` succeeds per platform + release
notes drafted. **Not** a GitHub release, code-signing, notarization, store distribution,
or auto-update — all excluded unless explicitly added later. **[REVIEW]** confirm with owner.

**Implementation order:** A (safety) → B (correctness) → D (build) → E (docs). Workstream
C (widget-layer refactor) is deferred — see below.

---

## Workstream A — Corrupted-config & parse-error handling

**Why:** The master plan names this the headline Phase 6 goal. Current state (verified
2026-08-18): `lib/screens/main_shell.dart` already surfaces errors via `on Object catch`
in 3 places (lines 72, 169, 192) rendering an "Error loading config" dialog and
inline `'Error: ...'` UI. So the bare premise ("single generic error string") is stale — the
real gap is **per-format recovery** and **position-accurate diagnostics**, exactly as the
master plan's 2026-08-13 suggestion anticipated.

### A1. Per-format recovery UX

- For each supported format (JSON, JSONC, YAML, TOML), define recovery when a file fails to
  parse:
  - Offer **"Open raw editor"** so the user can fix the file in place (the app must never
    auto-overwrite a corrupted on-disk file).
  - Never silently discard or re-serialize a corrupt file. The save path must preserve the
    user's raw bytes unless they explicitly choose to apply a structured edit.
- **Safety invariant (must be tested):** a corrupt in-memory edit is never written over a
  good on-disk file without explicit user action. Audit `ConfigEditor` + `ConfigService`
  (`saveConfig` @ `lib/services/config_service.dart:78`, `saveRawConfig` @ `:126`) to
  confirm this holds, and add a regression test.
- **Structured-merge write path (already safe by construction):** `saveRawConfig` merges
  structured edits on top of raw text at lines 167–187, but only when the baseline parses
  AND the structured editor was touched (lines 150–163). For corrupt files, the baseline
  parse fails and the merge is skipped entirely — the raw text is written verbatim. Add a
  regression test asserting this: `saveRawConfig` with an unparseable baseline writes the
  raw content without merging. No gate or disable logic is needed — the merge is structurally
  unreachable for corrupt files.
- **Recovery dialog (replaces SnackBar):** When `_loadConfig` fails (`main_shell.dart:72`),
  the current SnackBar + inline error text has no affordances. Replace the SnackBar with a
  recovery dialog offering:
  - **"Open raw editor"** — opens the file in a raw-text-only mode. Implementation:
    1. Re-read the file (`File(path).readAsString()`) — the failed `loadDiscoveredConfig`
       discards the bytes, so the placeholder's `originalContent` cannot come from the load
       attempt. Handle the file having been deleted since the failed load (show an error and
       skip).
    2. Construct a placeholder `ToolConfig(toolName: ..., filePath: ..., format: ...,
       originalContent: rawFileContent)` with empty rules/permissions.
    3. `setState { _error = null; _activeConfig = placeholder; _hasUnsavedChanges = false; }`.
       Clearing `_error` is required because the editor area renders `'Error: $_error'`
       *before* the `_activeConfig` check (`main_shell.dart:420–428`); without clearing it,
       the raw editor never renders.
    4. The raw-only mode must hide structured sections (rules/permissions editor) and the
       History button. After a successful save, flip back to the full editor — the saved
       content is parseable by construction.
  - **"View backups"** — opens `HistoryModal` with the placeholder `ToolConfig` (it only
    needs `config.filePath` and `config.toolName` — `history_modal.dart:105–107`). This
    lets the user browse and pick from all available backups, not just the latest.
    `restoreBackup` (`backup_service.dart:84–105`) overwrites the target without first
    backing it up — the HistoryModal's restore path at `main_shell.dart:126–151` already
    handles the backup-before-restore correctly. When no backups exist, hide this action
    (check via `configService.backupService.listBackups`).
  - **"Skip"** — dismisses the dialog and deselects the file.
  - **"Remove"** — only for files whose path is present in the manual preferences list
    (order-independent check — not `configItem.isManual`, which is false for catalog-first
    dual-provenance files). This pre-B implementation remains correct post-B; the gate
    becomes `fromManual` once B lands. For catalog-discovered files with no manual
    preference entry, omit "remove" (no mechanism to hide a catalog entry).
- **Sidebar polish:** `_activeConfigId` is set before load (`main_shell.dart:59`) and never
  cleared on failure, so the sidebar keeps the corrupt file highlighted as "active" while
  the editor shows an error. Clear `_activeConfigId` on load failure.

### A2. Line/column error reporting

- JSON/JSONC: `FormatException` from `jsonDecode` has an `offset` property. Surface
  line/col in the error UI where the parser provides it. `JsoncCleaner.clean` is
  length-preserving (replaces characters in-place with spaces, never inserts or removes), so
  the offset from the cleaned decode is the same offset into the user's raw file. Compute
  line/col from that offset against the original content — no mapping or "approximate"
  labeling needed.
- YAML: `loadYaml` throws `YamlException` (which extends `SourceSpanFormatException`)
  carrying a nullable `span` (line/col/watermark), but `yaml_config_parser.dart:33`
  currently wraps it in a generic `ConfigParseException`, discarding position. Fix: extract
  `span?.start.offset` from the caught exception before wrapping. `span` is nullable, so the
  message-only fallback (below) covers cases where it's null.
- TOML: `TomlDocument.parse` throws `TomlParserException` with `line`/`column`/`offset`/
  `source`, but `toml_config_parser.dart:32` wraps it generically. Fix: same pattern —
  extract position before wrapping. Note: the TOML getter is `column` (not `col`).
- Fallback (all formats): when the underlying exception has no position info, show message
  only. This is the common case for non-syntax errors (e.g. "YAML root must be a map").
- The recovery dialog (A1) replaces the SnackBar; the inline `'Error: ...'` text
  (`main_shell.dart:420–427`) stays as fallback for non-parse errors (e.g. network, perms).

### A3. Formalize the JSONC fallback-warning path

- When a `.json` file contains comments or trailing commas, `JsonConfigParser.parse`
  (`json_config_parser.dart:45–56`) silently falls back to `JsoncCleaner.clean()` — the
  user is never told their file was treated as JSONC. The gap is not "inconsistent warning
  spread across files" (the fallback is entirely self-contained in the parser); the gap is
  that **no warning exists at all**.
- **Model change:** Add a `parseWarnings` field to `ToolConfig` (`lib/models/tool_config.dart`).
  This is an `Equatable` model (lines 30–93) with `copyWith` and `props`. The field must:
  - Default to `const []` so all existing `ToolConfig(...)` literals compile without change.
  - Be added to `copyWith` (append-only, does not break existing callers).
  - Be added to `props` for `Equatable` comparison.
  - Be populated by `JsonConfigParser.parse` when the JSONC fallback activates.
- **Trigger condition:** the warning fires when strict `jsonDecode` fails AND the cleaned
  re-decode succeeds — regardless of file extension. Do NOT warn for `.jsonc` files that
  happen to be valid strict JSON (no fallback needed, no warning needed). Do NOT warn when
  `isContentEmpty` returns true.
- The UI consumes `parseWarnings` to show a non-blocking banner (e.g. "Parsed as JSONC —
  comments preserved") in the main shell editor area. The warning is informational; it does
  not block the save path. The banner also appears after save: `saveRawConfig` returns a
  re-parsed `ToolConfig` that carries the warning if the saved content triggered the JSONC
  fallback. Note that adding `parseWarnings` to `ToolConfig.props` changes `Equatable`
  equality, which feeds `ConfigEditor.didUpdateWidget` (`config_editor.dart:69`) — harmless
  but worth one sentence in the implementation so the implementer isn't surprised.

### A4. Tests

- Unit tests per parser for corrupted-input recovery (assert no overwrite + correct error
  surfaced).
- Widget test for the corrupted-file dialog (offer raw-editor-open; remove/skip actions).
- Edge case: empty file recovery. Parsers already handle empty content via `isContentEmpty`
  (returns an empty `ToolConfig`), and the normal editor already renders for this case. The
  A4 test should assert this **existing** behavior (empty file → normal editor, not corrupt
  dialog) rather than framing it as new work. The widget test only needs to cover the
  corrupt-file dialog for non-empty unparseable content.

---

## Workstream B — Manual-path removal bug fix (from `TO_DO.md`, Qodo #10)

**Problem (verified in code 2026-08-18):** `DiscoveryService.addIfValid`
(`lib/services/discovery_service.dart:20`) already contains a dedup guard (lines 27–37) that
correctly refuses to flip a catalog-discovered item to `isManual`. **However**, the
provenance model itself is incomplete: `DiscoveredConfig.isManual`
(`lib/models/discovered_config.dart:69`) is a single boolean, so a file with *dual*
provenance (manual **and** catalog) cannot be represented.

The actual failure mode depends on discovery order (user/project targets run before manual
paths — `discovery_service.dart:150–227`):

- **Catalog-first** (the dominant, real bug — this is the only order within a single
  `discoverConfigs` run): the file is discovered via its catalog target with
  `isManual: false`. When the same path appears in the manual list, the dedup guard at
  line 37 returns `false` without setting `isManual`. Result: **the sidebar "remove" button
  never appears** — the user has no affordance to remove the manual entry from their
  preferences.
- **Manual-first** (only reachable via unit-level call ordering, transient catalog-pass
  failure, or glob truncation — not a realistic end-to-end scenario): `isManual` is `true`,
  the remove button appears, `removeManualPath` deletes the preference entry, but the file
  is rediscovered via its catalog target on the next refresh with `isManual: false`. Result:
  **the file silently reappears**. Keep order-independence tests at the unit level (calling
  `addIfValid` in both orders) as a valid design property, but don't imply this is a common
  repro.

`removeManualPath` (`lib/state/providers.dart:141` → `DiscoveryPreferencesStore.removeManualPath`
`lib/services/discovery_preferences_store.dart:282`) only deletes the preference entry in
both cases.

**Fix approach:**

1. **Track provenance separately from `isManual`.** Add explicit provenance flags to
   `DiscoveredConfig` (`lib/models/discovered_config.dart`). **Preferred form: two bools
   (`fromCatalog` / `fromManual`)** rather than `Set<Provenance>` — simpler `Equatable`
   equality, no `Set` implementation ambiguity, and `isManual` can be derived as a getter
   (`isManual = fromManual`) rather than a stored field, which eliminates the exact
   dual-source ambiguity the plan is fixing. `isManual` should mean "manual is *one* of its
   provenance sources," not the sole determinant of removability.
2. **Discovery-order independence.** The current code processes user targets → project
   targets → manual paths (`discovery_service.dart:150-227`). The provenance fix must not
   depend on this order — a file's provenance set should be the union of all sources that
   matched it, regardless of which was processed first. When `addIfValid` encounters a
   duplicate `pathKey`, it should update the existing entry's provenance rather than
   silently returning `false`.
3. **Disambiguate removal.** `removeManualPath` should strip only the manual provenance. A
   file that is *also* catalog-backed remains (correct), but a file whose *sole* provenance
   is manual is fully removed (currently broken). The sidebar "remove" should be enabled iff
   manual provenance is present, and should only no-op when the file is catalog-backed *and*
   the user understands why (show a tooltip/inline note rather than a silent no-op).
4. **Scope interaction.** When manual provenance is stripped from a dual-provenance item,
   `scope` (which was set from the catalog match at `discovery_service.dart:200`) stays
   as-is — this is correct because the catalog target's scope is the item's true scope.
   When a manual-only item is removed, the entire `DiscoveredConfig` is dropped, so `scope`
   is irrelevant. Document this explicitly in the implementation.
5. **Touch points (per TO_DO.md):** `lib/services/discovery_service.dart`,
   `lib/state/providers.dart`, `lib/models/discovered_config.dart`. Re-verify
   `DiscoveryRequest.manualPaths` handling (`discovery_service.dart:189`) and the
   `Equatable` props list (`discovered_config.dart:116`) after adding fields.
6. **Out of scope:** symlink aliases produce different normalized paths, so they bypass the
   dedup key and create duplicate sidebar rows with independent provenance. This is a
   pre-existing issue, not a regression from the provenance fix — explicitly out of scope
   for this workstream.
7. **Tests:** a unit test asserting that removing a dual-provenance file keeps the
   catalog entry, and that removing a manual-only file drops it entirely; a regression test
   for the original silent-no-op; a test that provenance is correct regardless of discovery
   order (manual-first vs catalog-first — unit-level, calling `addIfValid` in both orders);
   a test that the sidebar "remove" button appears for catalog-first dual-provenance files
   (currently missing — the dedup guard prevents `isManual` from being set, so the button
   never shows).

---

## ~~Workstream C — Extract config persistence out of the widget layer~~ DEFERRED

**Deferred.** The save callback in `MainShell` (`main_shell.dart:464-481`) is already a
clean 3-step orchestration: call `ConfigService`, invalidate `backupListProvider`, update
`_activeConfig` via `setState`. `AGENTS.md` explicitly permits this pattern: "Widgets may
still invoke services from callbacks — that orchestration is not 'business logic in the
widget'." `HistoryModal`'s use of `ref.watch(backupListProvider(...))` at
`history_modal.dart:105` is standard Riverpod — the widget is already presentation-only.

Extracting a full `configSaveControllerProvider` would create a split-brain problem: the
save controller updates via Riverpod while loading/error/dirty state remains as
`setState` on the `StatefulWidget`. Moving *all* active-config state into Riverpod is a
large refactor with high regression risk for no user-facing benefit. A thin async helper
(not a provider) is possible but gains little — the current callback is already testable
via the `onSave` injection point on `ConfigEditor`.

Tracked in `TO_DO.md` as "Extract config persistence out of the widget layer." Not
release-blocking; likely not worth doing at all unless a concrete testability gap emerges.

---

## Workstream D — Build settings finalization

- **Build verification:** Run `flutter build macos --release`, `flutter build linux --release`,
  and `flutter build windows --release` and confirm all three succeed. This is the primary
  acceptance test for this workstream. **Cross-OS note:** Flutter does not support
  cross-compilation — Windows/Linux builds require their respective host OSes. This step
  must run in CI (the `build` matrix in `.github/workflows/ci.yml` already runs all three)
  or on multiple developer machines. A single macOS developer cannot produce all three
  artifacts locally.
- **macOS:** verify `macos/Runner/Configs/` (AppInfo/Debug/Release/Warnings `.xcconfig`),
  app icon, and entitlements. Check whether a "no networking in `lib/`" privacy claim exists
  in project docs; if so, confirm entitlements don't contradict it. If the claim doesn't
  exist in any doc, skip the cross-check.
- **Windows:** verify `windows/CMakeLists.txt` + runner icon/metadata.
- **Linux:** verify `linux/CMakeLists.txt` + runner icon/metadata.
- **[REVIEW]** Decide icon assets: are final icons available, or do we ship placeholder
  icons for this build? Default to the Flutter template icons if final art is not ready;
  mark the acceptance criterion "placeholder icons verified present; final art deferred."
  README screenshot is still user-blocked per TO_DO.md — release notes should not claim a
  screenshot that doesn't exist.

---

## Workstream E — Release notes

- Draft user release notes sourced from `CHANGELOG.md` (post the 0.1.0 reset from Phase 5.5)
  and the drift-guarded supported-tool list — **not** hand-written ad hoc.
- State explicitly: local-build scope, backup-before-write safety, supported tools
  (currently 9 in `ToolDescriptorRegistry`), and known limitations (e.g. TOML comment
  loss on raw re-serialize — deferred per TO_DO.md "Revisit TOML lossless round-trip";
  ADR exists in `lib/parsers/toml_config_parser.dart`).
- **[REVIEW]** Confirm whether release notes ship with or without the user-captured README
  screenshot (still blocked on user).

---

## Explicitly deferred (NOT in this phase)

- Code-signing / notarization / store distribution / auto-update.
- Widget-layer save refactor (Workstream C). The current save callback pattern is correct
  per `AGENTS.md` conventions; extracting a provider creates split-brain state with no
  user-facing benefit. Likely not worth doing unless a concrete testability gap emerges.
  Tracked in `TO_DO.md`.
- SonarCloud coverage wiring (`test` job's 80% lcov gate already enforces coverage; the
  SonarCloud reporting switch is a separate TO_DO item).
- TOML lossless round-trip (separate TO_DO item; ADR exists in `toml_config_parser.dart`).
- Phase 9 tool-support expansion (Kilo, Cline, Cursor split, etc.) — tracked in TO_DO.md.
- Semver institutionalization, SonarCloud issue triage, changelog-policy clarification —
  adjacent TO_DO items; **[REVIEW]** confirm none are release-blocking.

---

## Acceptance criteria (proposed)

- [ ] Corrupt configs never auto-overwrite on-disk originals; recovery dialog offers raw
      editor, view-backups (when backups exist), and skip; per-format line/col (or
      documented fallback) shown. (A1–A3)
- [ ] Unit + widget tests for parse-error recovery pass, including empty-file edge case. (A4)
- [ ] Removing a manual path removes manual-only files and keeps catalog-backed files;
      remove button appears for dual-provenance files (catalog-first case); no silent
      reappearance after refresh; provenance correct regardless of discovery order. (B)
- [ ] `flutter build` succeeds for macOS, Windows, Linux with placeholder icons/metadata
      in place; final icon art deferred. (D)
- [ ] Release notes drafted from CHANGELOG + supported-tool list, reviewed. (E)
- [ ] All new behavior covered by tests; `flutter analyze --fatal-infos` and
      `flutter test` green.

## Test plan

- Parser-level corrupted-input tests (JSON/JSONC/YAML/TOML) — no-overwrite + correct error.
- Widget test: corrupt-file recovery dialog (raw-editor-open / view-backups / skip).
- Widget test: empty file loads into normal editor (existing behavior — assert it stays).
- Discovery unit tests: dual-provenance removal (B); manual-only removal; order-independence.

## Files touched (anticipated)

- `lib/models/discovered_config.dart` (B)
- `lib/models/tool_config.dart` (A3 — `parseWarnings` field)
- `lib/parsers/config_parser.dart` (A2 — add nullable `line`/`column` to `ConfigParseException`)
- `lib/services/discovery_service.dart` (B)
- `lib/state/providers.dart` (B)
- `lib/services/discovery_preferences_store.dart` (B)
- `lib/screens/main_shell.dart` (A — recovery dialog, sidebar polish)
- `lib/widgets/config_editor.dart` (A — raw-only mode for corrupt files)
- `lib/parsers/json_config_parser.dart` (A3)
- `lib/parsers/yaml_config_parser.dart` (A2)
- `lib/parsers/toml_config_parser.dart` (A2 — note: TOML getter is `column`, not `col`)
- `macos/`, `windows/`, `linux/` build metadata (D)
- `docs/`, `CHANGELOG.md`, release notes (E)
- `TO_DO.md` (B — update stale Qodo #10 wording)

## Reviewer checklist (NEEDS REVIEW)

- [ ] Is "build readiness" scoped to local build artifacts only? (Scope boundary)
- [ ] YAML/TOML position extraction approach agreed? (A2)
- [ ] Provenance model shape (`fromCatalog`/`fromManual` vs `Set<Provenance>`)? (B)
- [ ] Icons/assets availability for D; README screenshot decision for E.
- [ ] Confirm deferred TO_DO items are not release-blocking.
- [ ] Update `initial_master_plan.md` §Phase 6 placeholder to link this file once approved.

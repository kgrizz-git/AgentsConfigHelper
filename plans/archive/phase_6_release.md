# Plan: Phase 6 — Polish, Error Handling & Build Readiness

**Status:** Complete — All workstreams (A, B, D, E) implemented and verified. Pending owner review of release notes.
**Last updated:** 2026-08-19
**Owner:** (unassigned)
**Depends on:** Phase 5.5 complete (archived 2026-08-17); master plan §Phase 6 stub
(`plans/active/initial_master_plan.md:108`).

Open questions and reviewer checkpoints are called out inline as **[REVIEW]**.

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

## Workstream A — Corrupted-config & parse-error handling ✓ SHIPPED 2026-08-18

**Why:** The master plan names this the headline Phase 6 goal. Current state (verified
2026-08-18): `lib/screens/main_shell.dart` already surfaces errors via `on Object catch`
in 3 places (lines 72, 169, 192) rendering a SnackBar and inline `'Error: ...'` text. So the bare premise ("single generic error string") is stale — the
real gap is **per-format recovery** and **position-accurate diagnostics**, exactly as the
master plan's 2026-08-13 suggestion anticipated.

### A1. Per-format recovery UX ✓

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
  the current SnackBar + inline error text has no affordances. The `on Object` catch fires
  for parse errors, missing files, and permission/IO errors alike. Show the recovery dialog
  for `ConfigParseException` and `FileSystemException` (both missing-file and permission
  cases degrade gracefully in the dialog: raw re-read fails → error, View-backups may list
  nothing, Remove gated on manual prefs). Keep the SnackBar for all other exceptions
  (`UnsupportedError`, unexpected `Error`s). The dialog offers:
  - **"Open raw editor"** — pop the recovery dialog first, then open the file in a
    raw-text-only mode. Hide this action when the file no longer exists (step 1 would fail).
    Implementation:
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
  - **"View backups"** — pop the recovery dialog first, then `setState { _error = null;
    _activeConfig = placeholder; _hasUnsavedChanges = false; }` (same as the raw-editor
    transition — `_activeConfig` must be non-null to pass `_showHistoryModal`'s guard at
    `main_shell.dart:117`), then open `HistoryModal` with the placeholder `ToolConfig` (it
    only needs `config.filePath` and `config.toolName` — `history_modal.dart:105–107`). This
    lets the user browse and pick from all available backups, not just the latest. When no
    backups exist, hide this action (check via `configService.backupService.listBackups`).
    **Restore safety:** the existing restore path at `main_shell.dart:140–146` calls
    `restoreBackup` (`backup_service.dart:84–105`) which is `backupFile.copy(targetPath)`
    with no preceding `createBackup` — it overwrites the target without preserving the
    current file. Add `createBackup(targetPath)` before `restoreBackup` in the restore flow,
    guarded by an exists-check (the target file may have been deleted):
    `if (await File(targetPath).exists()) { await backupService.createBackup(targetPath); }`
    — matches the pattern in `config_service.dart:85–88` and `:194–196`. This fix applies to
    all restore paths, not just the recovery dialog.
  - **"Skip"** — dismisses the dialog and deselects the file.
  - **"Remove"** — only for files whose path is present in the manual preferences list
    (order-independent check — not `configItem.isManual`, which is false for catalog-first
    dual-provenance files). This pre-B implementation remains correct post-B; the gate
    becomes `fromManual` once B lands. For catalog-discovered files with no manual
    preference entry, omit "remove" (no mechanism to hide a catalog entry).
- **Sidebar polish:** `_activeConfigId` is set before load (`main_shell.dart:59`) and never
  cleared on failure, so the sidebar keeps the corrupt file highlighted as "active" while
  the editor shows an error. Clear `_activeConfigId` on load failure.

### A2. Line/column error reporting ✓

- JSON/JSONC: `FormatException` from `jsonDecode` has an `offset` property (not line/col).
  Derive line/col from the offset against the original content. `JsoncCleaner.clean` is
  length-preserving (replaces characters in-place with spaces, never inserts or removes), so
  the offset from the cleaned decode is the same offset into the user's raw file — no mapping
  or "approximate" labeling needed.
- YAML: `loadYaml` throws `YamlException` (which extends `SourceSpanFormatException`)
  carrying a nullable `span` (line/col/watermark), but `yaml_config_parser.dart:33`
  currently wraps it in a generic `ConfigParseException`, discarding position. Fix: extract
  `span?.start.line` and `span?.start.column` from the caught exception before wrapping.
  `span` is nullable, so the message-only fallback (below) covers cases where it's null.
- TOML: `TomlDocument.parse` throws `TomlParserException` with `line`/`column`/`offset`/
  `source`, but `toml_config_parser.dart:32` wraps it generically. Fix: same pattern —
  extract position before wrapping. Note: the TOML getter is `column` (not `col`).
- Fallback (all formats): when the underlying exception has no position info, show message
  only. This is the common case for non-syntax errors (e.g. "YAML root must be a map").
- The recovery dialog (A1) replaces the SnackBar for `ConfigParseException` and
  `FileSystemException` (including permission errors — `dart:io` models them as
  `FileSystemException` with osError 13). Permission errors degrade safely: the dialog
  offers "Open raw editor" which re-reads the file, that read throws, and a SnackBar
  surfaces the error. The only useful button for permission errors is "Skip." The inline
  `'Error: ...'` text (`main_shell.dart:420–427`) stays as fallback for `UnsupportedError`
  and other unexpected failures.

### A3. Formalize the JSONC fallback-warning path ✓

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

### A4. Tests ✓

- [x] Unit tests per parser for corrupted-input recovery (assert no overwrite + correct error
      surfaced). — 6 new tests (JSON position, JSONC warning, YAML position, TOML position)
- [x] Widget test for the corrupt-file recovery dialog (raw-editor-open / view-backups / skip /
      conditional remove). — 12 tests in `test/screens/recovery_handler_test.dart`
      (harness mixin + `WidgetTester.runAsync` for real `dart:io` I/O).
- [x] Unit test for restore-path safety: restoring over an existing file preserves it as a
      backup first; restoring a deleted file skips `createBackup` and succeeds. — 2 new tests
- [x] Edge case: empty file recovery. — 1 new widget test (empty file → normal editor)

---

## Workstream B — Manual-path removal bug fix (from `TO_DO.md`, Qodo #10) ✓ SHIPPED 2026-08-18

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
7. **Tests:** ✓ Complete — unit tests asserting that removing a dual-provenance file keeps the
   catalog entry, removing a manual-only file drops it entirely, regression test for the original
   silent-no-op, provenance correctness regardless of discovery order, and sidebar "remove" button
   appears for catalog-first dual-provenance files. All tests in `test/services/discovery_service_test.dart`
   (lines 85-514).

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

## Workstream D — Build settings finalization ✓ (metadata verified 2026-08-18; macOS/Windows/Linux build pending CI)

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

### D status — 2026-08-18

**macOS build:** Could not run `flutter build macos --release` — this host has only
Command Line Tools installed, not full Xcode.app (`xcrun: error: unable to find utility
"xcodebuild"`). This is an environment limitation, not a code issue. The macOS build will
be verified in CI (build matrix) or on a machine with Xcode.app.

**Fix applied:** `discovery_service.dart:208` — changed `isManual: true` to `fromManual: true`
in the `DiscoveredConfig.fromPath` call to match the updated provenance model. This was a
compile error (analyze failure) from Workstream B's model refactor.

**Platform metadata verified (placeholder icons/metadata confirmed present):**

- **macOS:** `Configs/` — AppInfo.xcconfig (PRODUCT_NAME, BUNDLE_IDENTIFIER, COPYRIGHT),
  Debug.xcconfig, Release.xcconfig, Warnings.xcconfig all present and standard.
  `Info.plist` — standard Flutter template, uses `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`.
  `AppIcon.appiconset` — all 7 placeholder PNGs present (16/32/64/128/256/512/1024),
  Contents.json references all correctly. Entitlements: DebugProfile has sandbox + JIT +
  network.server (Flutter template default for hot reload); Release has sandbox only.
- **Windows:** `CMakeLists.txt` standard. `Runner.rc` references `resources\app_icon.ico` —
  file exists (256x256 multi-size ICO, 10 icons). `resource.h` defines `IDI_APP_ICON`.
  Version metadata uses `FLUTTER_VERSION` macros; CompanyName/FileDescription use
  `com.example`/`agents_config_helper` (placeholder).
- **Linux:** `CMakeLists.txt` standard. `APPLICATION_ID` = `com.example.agents_config_helper`
  (placeholder). No icon file in runner — standard Flutter Linux template (icons are
  delivered via `.desktop` file at system install, not embedded in binary). No `.desktop`
  file present (not required for local `flutter run`; needed only for system integration).

**Privacy cross-check:** `ARCHITECTURE.md:35` claims "No Cloud Sync: Version 1 has no
networking component for config data." `Release.entitlements` has only `com.apple.security.app-sandbox`
— no outgoing-network entitlement. No contradiction. `DebugProfile.entitlements` has
`com.apple.security.network.server` (Flutter template default for debug/hot reload) — also
no contradiction (debug-only, not release).

---

## Workstream E — Release notes ✓ DRAFTED 2026-08-18 (needs owner review)

- Draft user release notes sourced from `CHANGELOG.md` (post the 0.1.0 reset from Phase 5.5)
  and the drift-guarded supported-tool list — **not** hand-written ad hoc.
- State explicitly: local-build scope, backup-before-write safety, supported tools
  (currently 9 in `ToolDescriptorRegistry`), and known limitations (e.g. TOML comment
  loss on raw re-serialize — deferred per TO_DO.md "Revisit TOML lossless round-trip";
  ADR exists in `lib/parsers/toml_config_parser.dart`).
- **[REVIEW]** Confirm whether release notes ship with or without the user-captured README
  screenshot (still blocked on user). → Screenshot marked as pending in release notes;
  README placeholder badge confirmed (no actual screenshot image exists).

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

- [x] Corrupt configs never auto-overwrite on-disk originals; recovery dialog offers raw
      editor, view-backups (when backups exist), and skip; per-format line/col (or
      documented fallback) shown. (A1–A3) — **shipped 2026-08-18**
- [x] Unit + widget tests for parse-error recovery pass, including empty-file edge case. (A4)
      — **shipped 2026-08-18** (parser position tests, restore-path safety, empty-file widget
      test, recovery-dialog widget tests in `test/screens/recovery_handler_test.dart`)
- [x] Removing a manual path removes manual-only files and keeps catalog-backed files;
       remove button appears for dual-provenance files (catalog-first case); no silent
       reappearance after refresh; provenance correct regardless of discovery order. (B) —
       **shipped 2026-08-18** (provenance model `fromCatalog`/`fromManual` + derived `isManual`;
       `addIfValid` unions provenance on duplicate; comprehensive unit tests in `discovery_service_test.dart`)
- [x] `flutter build` succeeds for macOS, Windows, Linux with placeholder icons/metadata
      in place; final icon art deferred. (D) — **CI builds verified 2026-08-19: macOS (2m14s),
      Windows (3m36s), Linux (3m16s) all succeeded. Analyze + format green.**
- [x] Release notes drafted from CHANGELOG + supported-tool list. (E) — **drafted
      2026-08-18; needs owner review.** `docs/release-notes-0.1.1.md`
- [x] All new parser, model, and service behavior covered by tests; `flutter analyze
      --fatal-infos` and `flutter test` green. Recovery dialog logic (action gating,
      generation guards) covered by `test/screens/recovery_handler_test.dart`.
      — **154 tests pass, analyze clean (2026-08-18)**

## Test plan

- [x] Parser-level corrupted-input tests (JSON/JSONC/YAML/TOML) — position info on error +
      JSONC fallback warning. (4 JSON + 1 YAML + 1 TOML = 6 new tests)
- [x] Widget test: corrupt-file recovery dialog (raw-editor-open / view-backups / skip /
      conditional remove). — 12 tests in `test/screens/recovery_handler_test.dart`.
- [x] Unit test: restore-path safety (backup-before-restore + exists-guard for deleted files).
      (2 new tests in `backup_service_test.dart`)
- [x] Widget test: empty file loads into normal editor (existing behavior — assert it stays).
      (1 new test in `widget_test.dart`)
- [x] Discovery unit tests: dual-provenance removal (B); manual-only removal; order-independence. — **complete**

## Files touched

**Shipped (A — 2026-08-18):**

- `lib/models/tool_config.dart` — `parseWarnings` field
- `lib/parsers/config_parser.dart` — nullable `line`/`column` on `ConfigParseException`
- `lib/parsers/json_config_parser.dart` — position extraction + JSONC warning
- `lib/parsers/yaml_config_parser.dart` — span extraction
- `lib/parsers/toml_config_parser.dart` — line/column extraction (getter is `column`, not `col`)
- `lib/screens/main_shell.dart` — recovery dialog integration, sidebar polish
- `lib/screens/recovery_handler.dart` — recovery mixin (new file)
- `lib/widgets/config_editor.dart` — raw-only mode, parseWarnings banner
- `lib/widgets/raw_diff_view.dart` — diff viewer widget (new file, extracted)
- `TO_DO.md` — updated Qodo #10 wording

**Pending (B, D, E):**

- `lib/models/discovered_config.dart` (B — provenance model)
- `lib/services/discovery_service.dart` (B — discovery-order independence)
- `lib/state/providers.dart` (B — remove flow)
- `lib/services/discovery_preferences_store.dart` (B)
- `macos/`, `windows/`, `linux/` build metadata (D)
- `docs/`, `CHANGELOG.md`, release notes (E)
- `docs/release-notes-0.1.1.md` (E — new file)

## Reviewer checklist

- [ ] Is "build readiness" scoped to local build artifacts only? (Scope boundary)
- [ ] YAML/TOML position extraction approach agreed? (A2)
- [ ] Provenance model shape (`fromCatalog`/`fromManual` vs `Set<Provenance>`)? (B)
- [ ] Icons/assets availability for D; README screenshot decision for E.
- [ ] Confirm deferred TO_DO items are not release-blocking.
- [ ] Update `initial_master_plan.md` §Phase 6 placeholder to link this file once approved.

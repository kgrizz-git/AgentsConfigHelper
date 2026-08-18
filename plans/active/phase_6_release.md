# Plan: Phase 6 — Polish, Error Handling & Release

**Status:** DRAFT — **NEEDS REVIEW**
**Last drafted:** 2026-08-18T13:15:57-04:00
**Owner:** (unassigned)
**Depends on:** Phase 5.5 complete (archived 2026-08-17); master plan §Phase 6 stub
(`plans/active/initial_master_plan.md:108`). This plan supersedes that stub and should
replace its `*[Link to be created]*` placeholder once reviewed.

> **Review note:** This is a first draft for review, not an approved plan. Open questions and
> explicit reviewer checkpoints are called out inline as **[REVIEW]**. Do not start
> implementation until the placeholder in the master plan is updated to point here and the
> review items are resolved.

## Goal

Get the app ready for a **local-machine release**: robust error handling for corrupted
configs, clean build settings across macOS/Windows/Linux, and user-facing release notes.
As part of "polish," this phase also folds in two deferred correctness/architecture bug
fixes pulled from `TO_DO.md` (Qodo / SonarCloud follow-ups) because they are release-relevant
and low-risk to land now.

**Scope boundary (proposed):** "Release" = build-verified local artifacts (`flutter build`
per platform) + release notes. **Excluded** unless explicitly added later: code-signing /
notarization / store distribution / auto-update. **[REVIEW]** confirm with owner.

---

## Workstream A — Corrupted-config & parse-error handling

**Why:** The master plan names this the headline Phase 6 goal. Current state (verified
2026-08-18): `lib/screens/main_shell.dart` already surfaces errors via `on Object catch`
in 3 places (lines ~72–79, ~169, ~192) rendering an "Error loading config" dialog and
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

### A2. Line/column error reporting

- JSON/JSONC can surface `FormatException` offsets; surface line/col in the error UI where
  the parser provides it.
- **[REVIEW]** YAML/TOML position reporting varies by parser. Define the fallback (message
  only) when a position is unavailable, per format. Produce a short capability matrix in the
  plan's implementation notes.
- Reuse the existing error UI hooks in `main_shell.dart` rather than rebuilding them.

### A3. Formalize the JSONC fallback-warning path

- The JSONC fallback path is spread across `lib/parsers/jsonc_cleaner.dart`,
  `lib/parsers/json_config_parser.dart`, `lib/services/config_service.dart`, and
  `lib/widgets/config_editor.dart`. Document (and, if inconsistent, unify) the warning shown
  when a JSONC file is treated as plain JSON. Make the warning explicit and testable.

### A4. Tests

- Unit tests per parser for corrupted-input recovery (assert no overwrite + correct error
  surfaced).
- Widget test for the corrupted-file dialog (offer raw-editor-open; remove/skip actions).

---

## Workstream B — Manual-path removal bug fix (from `TO_DO.md`, Qodo #10)

**Problem (verified in code 2026-08-18):** `DiscoveryService.addIfValid`
(`lib/services/discovery_service.dart:20`) already contains a dedup guard (lines 30–37) that
correctly refuses to flip a catalog-discovered item to `isManual`. **However**, the
provenance model itself is incomplete: `DiscoveredConfig.isManual`
(`lib/models/discovered_config.dart:69`) is a single boolean, so a file with *dual*
provenance (manual **and** catalog) cannot be represented. `removeManualPath`
(`lib/state/providers.dart:141` → `DiscoveryPreferencesStore.removeManualPath`
`lib/services/discovery_preferences_store.dart:282`) only deletes the preference entry; the
file is then rediscovered via its catalog target on the next refresh, so the sidebar
"remove" silently no-ops for that file.

**Fix approach:**

1. **Track provenance separately from `isManual`.** Add explicit provenance flags (e.g.
   `fromCatalog` / `fromManual`, or a `Set<Provenance>`) to `DiscoveredConfig`
   (`lib/models/discovered_config.dart`). `isManual` should mean "manual is *one* of its
   provenance sources," not the sole determinant of removability.
2. **Disambiguate removal.** `removeManualPath` should strip only the manual provenance. A
   file that is *also* catalog-backed remains (correct), but a file whose *sole* provenance
   is manual is fully removed (currently broken). The sidebar "remove" should be enabled iff
   manual provenance is present, and should only no-op when the file is catalog-backed *and*
   the user understands why (show a tooltip/inline note rather than a silent no-op).
3. **Touch points (per TO_DO.md):** `lib/services/discovery_service.dart`,
   `lib/state/providers.dart`, `lib/models/discovered_config.dart`. Re-verify
   `DiscoveryRequest.manualPaths` handling (`discovery_service.dart:189`) and the
   `Equatable` props list (`discovered_config.dart:116`) after adding fields.
4. **Tests:** a unit test asserting that removing a dual-provenance file keeps the
   catalog entry, and that removing a manual-only file drops it entirely; a regression test
   for the original silent-no-op.

---

## Workstream C — Extract config persistence out of the widget layer (Qodo architecture finding)

**Problem (verified 2026-08-18):** Widgets reach into services directly:

- `MainShell` calls `ConfigService.saveConfig` / `saveRawConfig` inside the `ConfigEditor`
  `onSave` callback (`lib/screens/main_shell.dart:457–472`), and reads
  `configServiceProvider` in multiple spots (lines 64, 123, 222, 457).
- `HistoryModal` reads data via `backupListProvider` directly
  (`lib/widgets/history_modal.dart:106`).

This couples presentation to persistence and makes the save/refresh flow hard to test in
isolation.

**Fix approach (incremental, non-breaking):**

1. Introduce a **save controller / notifier** (e.g. `configSaveControllerProvider`) that
   owns the `ConfigService` call, the `backupListProvider` invalidation
   (`main_shell.dart:474`), and the active-config state update (`setState` @ `:476`).
   `MainShell` invokes the controller and reacts to its `AsyncValue` result instead of
   calling `ConfigService` inline.
2. Move `HistoryModal`'s `backupListProvider` read behind the same or a dedicated provider
   so the widget stays presentation-only.
3. Keep `ConfigService` as the persistence boundary; the controller is a thin orchestration
   layer (consistent with AGENTS.md: "Widgets may still invoke services from callbacks —
   that orchestration is not 'business logic in the widget'"). **[REVIEW]** Decide whether a
   full notifier is in scope or a smaller `ref.read`-free helper is sufficient — the goal is
   testability, not a rewrite.
4. **Tests:** a unit/widget test that drives a save through the controller and asserts the
   backup list invalidates and active config updates, without `ConfigService` being invoked
   from a `StatefulWidget` body.

---

## Workstream D — Build settings finalization

- **macOS:** verify `macos/Runner/Configs/` (AppInfo/Debug/Release/Warnings `.xcconfig`),
  app icon, and entitlements. Confirm no network/entitlement creep contradicts the
  "no networking in `lib/`" privacy claim established in Phase 5.5.
- **Windows:** verify `windows/CMakeLists.txt` + runner icon/metadata.
- **Linux:** verify `linux/CMakeLists.txt` + runner icon/metadata.
- **[REVIEW]** Decide icon assets: are final icons available, or do we ship placeholder
  icons for this release? (README screenshot is still user-blocked per TO_DO.md — release
  notes should not claim a screenshot that doesn't exist.)

---

## Workstream E — Release notes

- Draft user release notes sourced from `CHANGELOG.md` (post the 0.1.0 reset from Phase 5.5)
  and the drift-guarded supported-tool list — **not** hand-written ad hoc.
- State explicitly: local-build scope, backup-before-write safety, supported tools
  (currently 9 in `ToolDescriptorRegistry`), and known limitations (e.g. TOML comment
  loss on raw re-serialize — see Workstream C follow-up / ADR in
  `lib/parsers/toml_config_parser.dart`).
- **[REVIEW]** Confirm whether release notes ship with or without the user-captured README
  screenshot (still blocked on user).

---

## Explicitly deferred (NOT in this phase)

- Code-signing / notarization / store distribution / auto-update.
- SonarCloud coverage wiring (`test` job's 80% lcov gate already enforces coverage; the
  SonarCloud reporting switch is a separate TO_DO item).
- TOML lossless round-trip (separate TO_DO item; ADR exists in `toml_config_parser.dart`).
- Phase 9 tool-support expansion (Kilo, Cline, Cursor split, etc.) — tracked in TO_DO.md.
- Semver institutionalization, SonarCloud issue triage, changelog-policy clarification —
  adjacent TO_DO items; **[REVIEW]** confirm none are release-gating.

---

## Acceptance criteria (proposed)

- [ ] Corrupt configs never auto-overwrite on-disk originals; raw-editor recovery offered;
      per-format line/col (or documented fallback) shown. (A1–A3)
- [ ] Unit + widget tests for parse-error recovery pass. (A4)
- [ ] Removing a manual path removes manual-only files and keeps catalog-backed files; no
      silent no-op without explanation. (B)
- [ ] Widgets no longer call `ConfigService`/`backupListProvider` directly for saves;
      controller owns the flow; new test passes. (C)
- [ ] `flutter build` succeeds for macOS, Windows, Linux with icons/metadata in place. (D)
- [ ] Release notes drafted from CHANGELOG + supported-tool list, reviewed. (E)
- [ ] All new behavior covered by tests; `flutter analyze --fatal-infos` and
      `flutter test` green.

## Test plan

- Parser-level corrupted-input tests (JSON/JSONC/YAML/TOML) — no-overwrite + correct error.
- Widget test: corrupted-file dialog (raw-editor-open / skip).
- Discovery unit tests: dual-provenance removal (B); manual-only removal.
- Save-controller test: invalidation + active-config update without widget-layer service
  calls (C).

## Files touched (anticipated)

- `lib/models/discovered_config.dart` (B)
- `lib/services/discovery_service.dart` (B)
- `lib/state/providers.dart` (B, C)
- `lib/services/discovery_preferences_store.dart` (B)
- `lib/screens/main_shell.dart` (A, C)
- `lib/widgets/config_editor.dart` (A)
- `lib/widgets/history_modal.dart` (C)
- `lib/services/config_service.dart` (A audit; C orchestration may stay here)
- `macos/`, `windows/`, `linux/` build metadata (D)
- `docs/`, `CHANGELOG.md`, release notes (E)
- New: save controller/notifier (C)

## Reviewer checklist (NEEDS REVIEW)

- [ ] Is "release" scoped to local build artifacts only? (Scope boundary)
- [ ] YAML/TOML position-reporting fallback agreed? (A2)
- [ ] Provenance model shape (`fromCatalog`/`fromManual` vs `Set<Provenance>`)? (B)
- [ ] Save-controller granularity (full notifier vs thin helper)? (C)
- [ ] Icons/assets availability for D; README screenshot decision for E.
- [ ] Confirm deferred TO_DO items are not release-gating.
- [ ] Update `initial_master_plan.md` §Phase 6 placeholder to link this file once approved.

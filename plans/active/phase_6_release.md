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
- **Structured-merge write path (must be audited):** `saveRawConfig` has a second write
  path at lines 167–187 where it merges structured edits (rules/permissions from the
  structured editor) on top of raw text. This merge re-serializes through the parser and
  overwrites the on-disk file. If the user only edited raw text but the structured editor
  was also touched, the merge result may not match the user's intent. A1's safety invariant
  must cover this path: the structured editor should be disabled or gated behind a confirm
  while the file is in a parse-error state, and the merge path should be audited to confirm
  it only activates when the user explicitly touched the structured editor.
- **Raw editor as sole write path for corrupt files:** When a file fails to parse, the
  structured editor must not be shown (currently correct — `_loadConfig` sets `_error` and
  leaves `_activeConfig` null at `main_shell.dart:55–71`, so `ConfigEditor` is never
  rendered for a corrupt file). Make this an explicit, tested invariant rather than an
  implicit side effect of the null check.

### A2. Line/column error reporting

- JSON/JSONC: `FormatException` from `jsonDecode` has an `offset` property. Surface
  line/col in the error UI where the parser provides it. **Caveat:** when the JSONC
  fallback path triggers (`json_config_parser.dart:45–56`), the inner `FormatException`
  has an offset **into the cleaned string** (comments/trailing commas stripped), which is
  NOT the same offset as the user's raw file. Surfacing that offset directly would point
  the user at the wrong character. Either map the offset back to the original content
  (track which character ranges were blanked by `JsoncCleaner.clean`), or explicitly
  document the offset as "approximate, after comment stripping" in the error UI.
- YAML: `loadYaml` throws `YamlException` which carries `span` (line/col/watermark), but
  `yaml_config_parser.dart:33` currently wraps it in a generic `ConfigParseException`,
  discarding position. Fix: extract `span` from the caught exception before wrapping.
- TOML: `TomlDocument.parse` throws `TomlParserException` with `line`/`col`, but
  `toml_config_parser.dart:32` wraps it generically. Fix: same pattern — extract position
  before wrapping.
- Fallback (all formats): when the underlying exception has no position info, show message
  only. This is the common case for non-syntax errors (e.g. "YAML root must be a map").
- Reuse the existing error UI hooks in `main_shell.dart` rather than rebuilding them.

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
  comments preserved"). The warning is informational; it does not block the save path.

### A4. Tests

- Unit tests per parser for corrupted-input recovery (assert no overwrite + correct error
  surfaced).
- Widget test for the corrupted-file dialog (offer raw-editor-open; remove/skip actions).
- Edge case: empty file recovery. Parsers already handle empty content via `isContentEmpty`
  (returns an empty `ToolConfig`), but the recovery UX should also handle it gracefully —
  don't show "corrupt file" for an empty config; show the raw editor with an empty buffer.

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

- **Catalog-first** (the common case): the file is discovered via its catalog target with
  `isManual: false`. When the same path appears in the manual list, the dedup guard at
  line 37 returns `false` without setting `isManual`. Result: **the sidebar "remove" button
  never appears** — the user has no affordance to remove the manual entry from their
  preferences. This is worse than a silent no-op: there is no affordance at all.
- **Manual-first** (rare): `isManual` is `true`, the remove button appears, `removeManualPath`
  deletes the preference entry, but the file is rediscovered via its catalog target on the
  next refresh with `isManual: false`. Result: **the file silently reappears** after the
  sidebar refreshes.

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
6. **Tests:** a unit test asserting that removing a dual-provenance file keeps the
   catalog entry, and that removing a manual-only file drops it entirely; a regression test
   for the original silent-no-op; a test that provenance is correct regardless of discovery
   order (manual-first vs catalog-first); a test that the sidebar "remove" button appears
   for catalog-first dual-provenance files (currently missing — the dedup guard prevents
   `isManual` from being set, so the button never shows).

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
  icons for this build? (README screenshot is still user-blocked per TO_DO.md — release
  notes should not claim a screenshot that doesn't exist.)

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

- [ ] Corrupt configs never auto-overwrite on-disk originals; raw-editor recovery offered;
      per-format line/col (or documented fallback) shown. (A1–A3)
- [ ] Unit + widget tests for parse-error recovery pass, including empty-file edge case. (A4)
- [ ] Removing a manual path removes manual-only files and keeps catalog-backed files;
      remove button appears for dual-provenance files (catalog-first case); no silent
      reappearance after refresh; provenance correct regardless of discovery order. (B)
- [ ] `flutter build` succeeds for macOS, Windows, Linux with icons/metadata in place. (D)
- [ ] Release notes drafted from CHANGELOG + supported-tool list, reviewed. (E)
- [ ] All new behavior covered by tests; `flutter analyze --fatal-infos` and
      `flutter test` green.

## Test plan

- Parser-level corrupted-input tests (JSON/JSONC/YAML/TOML) — no-overwrite + correct error.
- Widget test: corrupted-file dialog (raw-editor-open / skip).
- Edge case: empty file shows raw editor, not "corrupt" error.
- Discovery unit tests: dual-provenance removal (B); manual-only removal; order-independence.

## Files touched (anticipated)

- `lib/models/discovered_config.dart` (B)
- `lib/models/tool_config.dart` (A3 — `parseWarnings` field)
- `lib/services/discovery_service.dart` (B)
- `lib/state/providers.dart` (B)
- `lib/services/discovery_preferences_store.dart` (B)
- `lib/screens/main_shell.dart` (A)
- `lib/widgets/config_editor.dart` (A)
- `lib/parsers/json_config_parser.dart` (A3)
- `lib/parsers/yaml_config_parser.dart` (A2)
- `lib/parsers/toml_config_parser.dart` (A2)
- `macos/`, `windows/`, `linux/` build metadata (D)
- `docs/`, `CHANGELOG.md`, release notes (E)

## Reviewer checklist (NEEDS REVIEW)

- [ ] Is "build readiness" scoped to local build artifacts only? (Scope boundary)
- [ ] YAML/TOML position extraction approach agreed? (A2)
- [ ] Provenance model shape (`fromCatalog`/`fromManual` vs `Set<Provenance>`)? (B)
- [ ] Icons/assets availability for D; README screenshot decision for E.
- [ ] Confirm deferred TO_DO items are not release-blocking.
- [ ] Update `initial_master_plan.md` §Phase 6 placeholder to link this file once approved.

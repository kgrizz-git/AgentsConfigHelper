# Plan: Expected-File Relevance in the Overview

Last reviewed: 2026-09-14
Status: proposed (not started)
Linked TO_DO item: **Expected-file relevance in the overview**

## Goal

Make Config Overview represent a healthy local setup by default. Exact catalog
targets that are absent today all become `missing`, including targets for other
operating systems, optional/legacy files, and tools with no discovered
configuration. This creates a noisy report that implies a broken setup.

Add catalog-backed platform and optionality metadata, classify absent entries by
relevance, hide non-relevant targets by default, and retain an explicit audit
view that can show every catalog target.

## Scope

- Add platform and optionality metadata to catalog targets with safe defaults.
- Annotate only targets supported by repository catalog evidence.
- Classify overview entries as present, expected missing, optional missing,
  other platform, or not installed/configured.
- Default the screen to relevant entries; label optional entries separately from
  missing entries.
- Provide an audit control that reveals hidden catalog targets with clear labels.
- Preserve these labels in Markdown and HTML exports.
- Add model, catalog, builder, widget, fixture, documentation, and changelog
  coverage required by the repository policies.

## Non-goals

- Do not change discovery paths, probing, or matching.
- Do not add filesystem installation detection; derive relevance from discovery
  results already in memory.
- Do not implement permission-kind classification, export bundles, CLI/API work,
  or configuration-copy features.
- Do not introduce equivalence-group semantics for alternate config files in this
  iteration.

## Current evidence

- `ConfigTarget` in `lib/models/tool_descriptor.dart` has path, format, scope,
  and kind metadata but no platform or optionality.
- `buildOverviewModel` in `lib/reports/config_overview_report.dart` emits a
  missing entry for every undiscovered exact target; glob targets are skipped.
- `ConfigOverviewEntry` has only a `missing` boolean. Markdown, HTML, and the
  overview screen all render it as a warning.
- The registry has platform-specific targets for Cursor IDE and Copilot JetBrains
  instructions. The Kilo `models.json` target is explicitly described as an
  optional/legacy cache file.
- Snapshot fixtures live in `test/fixtures/config_overview_expected.md` and
  `.html`; report and widget tests currently assert the existing missing behavior.
- `docs/supported-tools.md` is the evidence source for catalog path/platform
  annotations.

## Decisions to confirm during implementation

1. Use a domain enum, not Flutter's `TargetPlatform`, so the catalog stays
   pure-Dart: `ConfigPlatform { any, macOS, linux, windows, posix }`. `posix`
   covers macOS and Linux. Give every target `ConfigPlatform.any` by default.
2. Add `optional: false` to `ConfigTarget`. Missing optional entries for a
   relevant tool are visible with a muted `optional` label, never a warning
   `missing` label.
3. Treat a tool as installed/configured when discovery contains at least one
   item associated with that tool descriptor. This avoids new I/O. A custom,
   unregistered path can be audited through the full catalog view.
4. Hide other-platform and not-installed catalog targets in the default screen.
   The audit control reveals all entries with `other OS` or `not installed`
   labels and an explanatory tooltip/count.
5. Exports follow the current view: default export is relevant-only; enabling
   audit exports the complete, labeled catalog view.

## Candidate catalog annotations

Validate each annotation against `docs/supported-tools.md` before applying it.

| Tool | Target | Proposed metadata |
| --- | --- | --- |
| Cursor IDE | `Library/Application Support/Cursor/User/settings.json` | macOS |
| Cursor IDE | `.config/Cursor/User/settings.json` | Linux |
| Cursor IDE | `AppData/Roaming/Cursor/User/settings.json` | Windows |
| Copilot | `.config/github-copilot/intellij/global-copilot-instructions.md` | POSIX, pending macOS evidence confirmation |
| Copilot | `AppData/Local/github-copilot/intellij/global-copilot-instructions.md` | Windows |
| Kilo | `.config/kilo/models.json` | optional/legacy |
| Kilo | user and project `kilo.json` alternate targets | optional, only where evidence confirms alternates |
| Copilot | `.copilot/config.json` | optional only if managed-state evidence supports it |

Leave uncertain targets at the default metadata and record a follow-up rather
than guessing.

## Implementation stages

### 1. Catalog metadata and evidence

- Extend `ConfigTarget` and its equality properties in
  `lib/models/tool_descriptor.dart`.
- Add a pure platform applicability helper in the catalog layer plus an explicit
  host-platform resolver for UI composition.
- Annotate the validated inventory entries in
  `lib/catalog/tool_descriptor_registry.dart`, with short evidence comments.
- Update registry invariant and descriptor tests.
- Update the relevant `docs/supported-tools.md` path tables and review dates.

### 2. Pure overview relevance model

- Add `OverviewRelevance` to `ConfigOverviewEntry` with values for present,
  expected missing, optional missing, other platform, and not installed.
- Make `buildOverviewModel` accept the current platform explicitly and compute
  installed tool IDs from discovered descriptor-backed items.
- Keep glob-target behavior and existing deduplication intact.
- During migration, derive the existing `missing` behavior only from expected
  missing entries; remove compatibility code once every caller is migrated.
- Update Markdown and HTML builders with neutral optional/audit labels and CSS.
- Regenerate and review Markdown/HTML fixtures; add focused classification tests
  for every relevance value and builder label.

### 3. Overview UX and audit control

- Make `ConfigOverviewScreen` stateful only for the audit-view toggle.
- Default to present, expected-missing, and optional-missing entries.
- Expose an accessible control such as a `FilterChip` with a hidden-row count
  and tooltip explaining it includes other-OS and not-installed catalog targets.
- In audit view, show target-platform and not-installed labels. Render warning
  styling only for expected missing files; keep optional and audit labels muted.
- Preserve Open, Reveal, and Copy only for resolved present entries.
- Verify default/audit behavior and exports in widget tests.

### 4. Documentation, release notes, and closure

- Add an Unreleased user-facing `CHANGELOG.md` entry for the clearer overview
  and audit view. Add `CHANGELOG.dev.md` only for developer-only changes, per
  the changelog policy.
- Update `docs/DESIGN_LANGUAGE.md` if a new muted badge token/class is needed.
- On completion, validate, review, remove the linked TO_DO entry, mark this plan
  complete, and move it to `plans/archive/` as the feature branch's final commit.

## Acceptance criteria

- A healthy macOS, Windows, or Linux setup does not show other-platform entries
  as missing in the default Overview.
- A discovered tool's genuinely expected absent exact target remains visible as
  `missing`.
- A validated optional target is visibly `optional`, does not receive warning
  styling, and remains auditable.
- Tools with no discovered configuration do not fill the default Overview with
  missing rows.
- The audit control exposes every suppressed catalog target with a reason, and
  the exported report matches the selected view.
- Platform behavior is covered off-host through explicit platform injection.

## Validation

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- Focused tests first:
  `flutter test test/catalog test/reports/config_overview_report_test.dart test/widgets/config_overview_screen_test.dart`
- `flutter test`
- `pre-commit run --all-files`
- Manual macOS smoke: confirm default relevance, audit labels/count, and both
  export formats.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Incorrect catalog classification | Annotate only documented paths; retain defaults when evidence is weak. |
| Installed-tool false negatives | Use an explicit audit view and document the discovery-based heuristic. |
| Platform logic becomes host-dependent in tests | Pass platform into pure report construction. |
| Optional badges look like errors | Use neutral/muted screen and export styling, with dedicated tests. |
| Scope expands into permission classification | Keep it explicitly out of scope and leave its separate TO_DO item intact. |

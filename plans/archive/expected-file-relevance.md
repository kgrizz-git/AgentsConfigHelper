# Plan: Expected-File Relevance in the Overview

Last reviewed: 2026-09-14
Status: complete
Linked TO_DO item: **Expected-file relevance in the overview** (closed; see follow-ups)

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

## Adopted design decisions

1. Use a domain enum, not Flutter's `TargetPlatform`, so the catalog stays
   pure-Dart: `ConfigPlatform { any, macOS, linux, windows, posix }`. `posix`
   covers macOS and Linux. Give every target `ConfigPlatform.any` by default.
2. Add `optional: false` to `ConfigTarget`. Missing optional entries for a
   relevant tool are visible with a muted `optional` label, never a warning
   `missing` label.
3. Name the heuristic `has discovered configuration`, not `installed`. A tool
   has discovered configuration when discovery contains at least one item
   associated with its descriptor. This avoids new I/O, but does not prove the
   executable is installed. A custom, unregistered path can be audited through
   the full catalog view.
4. Hide other-platform and not-installed catalog targets in the default screen.
   The audit control reveals all entries with `other OS` or `not installed`
   labels and an explanatory tooltip/count.
5. Keep audit state local to `ConfigOverviewScreen` with `setState`; it is an
   inspection choice, not a preference. The screen passes its filtered entries
   to the existing save service/builders and supplies an optional hidden-target
   count for a self-describing export header. Default export is relevant-only;
   audit export is the complete, labeled catalog view.

## Candidate catalog annotations

Validate each annotation against `docs/supported-tools.md` before applying it.

| Tool | Target | Proposed metadata |
| --- | --- | --- |
| Cursor IDE | `Library/Application Support/Cursor/User/settings.json` | macOS |
| Cursor IDE | `.config/Cursor/User/settings.json` | Linux |
| Cursor IDE | `AppData/Roaming/Cursor/User/settings.json` | Windows |
| Copilot | `.config/github-copilot/intellij/global-copilot-instructions.md` | POSIX (macOS documented; Linux follows XDG path convention) |
| Copilot | `AppData/Local/github-copilot/intellij/global-copilot-instructions.md` | Windows |
| Kilo | `.config/kilo/kilo.json` | optional supported alternate to primary `kilo.jsonc` |
| Kilo | `kilo.json`, `.kilo/kilo.jsonc`, `.kilo/kilo.json` | optional project alternatives pending a later equivalence-group design |
| Kilo | `.config/kilo/models.json` | optional undocumented/legacy target; retain a catalog-removal follow-up |
| Copilot | `.copilot/config.json` | expected managed state, not optional |

GitHub's JetBrains custom-instruction guide documents the `.config` mapping on
macOS; Linux uses the matching XDG convention and requires a focused test.
Kilo documents `kilo.jsonc` as primary and `kilo.json` as a supported
alternate; `.kilo/kilo.jsonc` takes precedence when present. `models.json` is
not in Kilo's current documented configuration list, so it must never imply a
broken installation. Leave all other uncertain targets at the default metadata
and record a follow-up rather than guessing.

`Documents/Cline/Rules` and `Cline/Rules` need no platform metadata in this
slice: they are glob targets, do not create missing rows, and discovery already
uses the latter only as a fallback when the former is absent.

### External evidence to retain with implementation

- GitHub documents the Copilot JetBrains global-instructions directory as
  `~/.config/github-copilot/intellij/` on macOS and `%LOCALAPPDATA%` on
  Windows: <https://docs.github.com/en/copilot/how-tos/configure-custom-instructions-in-your-ide/add-repository-instructions-in-your-ide>.
- Kilo documents global `kilo.jsonc`, project `kilo.jsonc` and
  `.kilo/kilo.jsonc`, with `kilo.json` as a supported alternate:
  <https://kilo.ai/docs/getting-started/settings>.
- GitHub defines Copilot CLI `config.json` as automatically managed application
  state rather than the editable settings file:
  <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference>.

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
  tool IDs with discovered configuration from descriptor-backed items.
- Keep glob-target behavior and existing deduplication intact.
- Replace the public `missing` field in the same change; use a derived
  `isExpectedMissing` getter only where it improves readability. Migrate every
  screen, builder, fixture, and test reference in this PR so there are never
  two independently stored status fields.
- Update Markdown and HTML builders with neutral optional/audit labels and CSS.
- Update Markdown/HTML fixtures in this stage before the full test suite, then
  add focused classification tests for every relevance value and builder label.

### 3. Overview UX and audit control

- Make `ConfigOverviewScreen` stateful only for the local audit-view toggle.
- Default to present, expected-missing, and optional-missing entries.
- Expose an accessible control such as a `FilterChip` with a hidden-row count
  and tooltip explaining it includes other-OS and not-installed catalog targets.
- In audit view, show target-platform and not-installed labels. Render warning
  styling only for expected missing files; keep optional and audit labels muted.
- Preserve Open and Reveal only for resolved present entries. Preserve Copy for
  every entry with a known file path so users can copy an expected missing path.
- Pass the filtered current-view entry list to the existing save service. Add an
  optional hidden-target count/view label to the report builders so exports say
  when entries were omitted; do not add audit state to `ReportSaveService`.
- Verify default/audit behavior, export filtering, and export provenance text in
  widget and builder tests.

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
  missing rows. Project-only tools without configured roots are explicitly
  subject to this conservative heuristic and remain available in audit view.
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
| Installed-tool false negatives | Call the state `has discovered configuration`, document false negatives for unconfigured, nonstandard-path, shared-file, and project-only tools, and retain audit view. |
| Platform logic becomes host-dependent in tests | Pass platform into pure report construction. |
| Optional badges look like errors | Use neutral/muted screen and export styling, with dedicated tests. |
| Scope expands into permission classification | Keep it explicitly out of scope and leave its separate TO_DO item intact. |
| Export is mistaken for a complete audit | Include active-view and hidden-target-count provenance in exports. |

## Follow-ups

- Verify the first-party Microsoft documentation for Copilot JetBrains
  `global-git-commit-instructions.md` against current GitHub docs or the
  shipping extension before adding its POSIX/Windows catalog targets.
- Reassess or remove the undocumented Kilo `models.json` target after catalog
  evidence is available; its optional label is a conservative interim measure.

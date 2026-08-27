# Plan: Formatting Fidelity Disclosure

Last reviewed: 2026-08-27
Date: 2026-08-27
Author: maintainers
Status: planned
Linked parent: [Structured Configuration Roadmap](structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Goal

Before a user edits a configuration, make it clear whether the app's **structured
save** can reformat or discard comments. The notice must be visible as soon as the
editor opens, accessible without relying on colour or hover, and truthful about the
actual serialization path. Viewing a file must remain explicitly described as
non-mutating.

This plan does not add structured editing for a new tool or an AST-preserving TOML
writer. It improves disclosure for the generic editor the app already ships.

## Verified baseline

| Format or path | Current write behavior | Fidelity classification for this plan |
| --- | --- | --- |
| Markdown/text raw editor, with no independently dirty structured values | `saveRawConfig` writes the validated raw text directly. | Direct raw write; no conversion notice. |
| Raw save with independently dirty structured values | `saveRawConfig` replays the structured values through `parser.serialize` on top of the raw text. | Merge-specific risk; it is not a direct raw write. TOML therefore rewrites even when the raw edit itself looks harmless. |
| JSON/JSONC supported flat `rules` or `permissions` change | `JsonConfigParser` patches source offsets and validates the resulting JSONC. | Preserving path. |
| JSON/JSONC unsupported/failed patch | Parser catches the failure and fully serializes the decoded map. | Possible rewrite fallback. |
| YAML supported map update | `YamlEditor` updates the parsed source. | Preserving path. |
| YAML failed in-place update | Parser builds a fresh YAML document. | Possible rewrite fallback. |
| TOML structured change | `TomlConfigParser` always serializes a map with `TomlDocument.fromMap`. | Unconditional structured rewrite. |

The current editor has a TOML warning only in the Review Changes dialog and only
after a structured value has changed. Its JSONC parse warning says comments are
preserved, but does not disclose the full-rewrite fallback. YAML has no equivalent
warning. The existing source and tests establish these facts:

- `lib/parsers/json_config_parser.dart`
- `lib/parsers/yaml_config_parser.dart`
- `lib/parsers/toml_config_parser.dart`
- `lib/widgets/config_editor.dart`
- `docs/adr/ADR-001-toml-comment-preservation.md`

## Product decisions

- A notice describes save behavior, not viewing behavior. It must begin by stating
  that opening/viewing the file does not change it.
- The notice is persistent for the selected file and appears above both structured
  controls and the raw editor. It has no dismiss action that could hide it until
  the user switches files.
- TOML receives a warning: a structured save can discard comments and reformat
  whitespace, ordering, and layout.
- YAML and parsed JSONC receive a caution: the supported in-place path preserves
  comments and formatting, but the current fallback can rewrite the document. A
  `.json` file parsed as JSONC must be treated as JSONC regardless of its extension.
- Strict JSON is not warned specifically about comments because comments are not
  valid JSON. It still belongs to the same serialization-capability model so a
  future formatting disclosure cannot drift from parser behavior.
- Markdown/text raw-only files receive no conversion notice. If raw content and
  structured state are independently dirty, the notice must reflect the merge path
  `saveRawConfig` will actually take; it must never classify that save as a direct
  raw write.
- `ConfigFormat.unknown`, a raw-only corrupt-file editor, and an unsupported parser
  outcome are safe/no-assessment states. They must not crash the editor or receive a
  misleading format-specific disclosure.
- Existing parse warnings remain distinct from fidelity notices: one says how a file
  was parsed; the other says what a later structured save may do.
- The notice is disclosure, not consent for data loss. Before another structured
  write surface is enabled, decide whether JSONC/YAML fallback must fail closed.

## Design and accessibility contract

The notice is a reusable editor component, not a tool-specific card. It must include:

1. A visible warning/caution icon and concise title, for example **Formatting may
   change on structured save**.
2. Plain-language body text naming the relevant format and exact risk. TOML must use
   unambiguous wording: **comments and formatting can be discarded**.
3. The statement: **Viewing this file does not modify it.**
4. Guidance to edit raw content when exact layout matters and to use Review Changes
   before saving. Do not claim raw editing can preserve a prior formatting style
   after the user has deliberately changed it.
5. `Semantics`/accessible label containing the title and risk, with normal text
   contrast and no information conveyed only by icon or colour. It is informational,
   not a modal or focus trap. Use a non-live semantics region so switching files does
   not repeatedly announce a warning outside the user's normal reading flow.

The Review Changes dialog retains a matching final warning when a risky structured
save is pending. Both locations must obtain wording and severity from one model so
they cannot contradict each other.

## Proposed design

### 1. Pure-Dart fidelity assessment

Introduce a narrow immutable assessment, preferably near the parser contract, such
as `ConfigSerializationFidelity` with these states:

| State | Meaning |
| --- | --- |
| `directRawWrite` | The submitted raw text is written without parser serialization and no structured state must be replayed. |
| `structuredMerge` | Raw text is submitted but independently dirty structured state must be replayed through a serializer; its risk is the serializer's risk, not raw-write fidelity. |
| `preservesSupportedPatch` | The requested structured update has a known in-place preserving path. |
| `possibleRewriteFallback` | A supported path exists but the present request can fall back to a full rewrite. |
| `structuredRewrite` | The current structured serializer always rebuilds the document. |
| `notApplicable` | No supported serializer applies (for example an unknown/raw-only format); no conversion claim is made. |

The public editor-facing method may report the *risk ceiling* before a save rather
than predict whether a particular parser edit will succeed. It must take the format,
parsed JSONC status, raw-only/unsupported state, raw and structured dirty state, and
the baseline-to-current structured divergence into account. Do not infer it from the
extension alone or duplicate parser heuristics in a widget. For JSON/YAML, report the
riskiest applicable field/subtree behavior; do not label a document categorically
preserved merely because one flat field has an in-place patch path while another
recognized subtree is intentionally left untouched.

### 2. Parser and service integration

- Keep parser-specific policy alongside the parser or `ConfigParser` contract.
- Surface an assessment on `ToolConfig` or through a small pure service that
  `ConfigEditor` can consume without performing I/O.
- Make `ConfigService.saveConfig` and the structured-merge branch of
  `saveRawConfig` use the same policy as the UI. The initial version does not need
  to change fallback behavior, but must make it observable and testable.
- Preserve direct raw-write behavior exactly. Do not reserialize merely to produce
  a notice.

### 3. Editor integration

- Add `FormattingFidelityNotice` under `lib/widgets/` and render it in
  `ConfigEditor` before parse warnings and editable content.
- Remove the TOML-specific inline Review Changes implementation and replace it with
  the shared notice/model when a risky structured diff is present.
- Avoid tool/schema conditions. The generic editor asks the fidelity assessment;
  read-only Claude and future Cursor cards inherit the visible file-level notice
  without owning fidelity logic.

## Phases and checklist

### Phase 1 — define and test the fidelity contract

- [ ] Add pure-Dart states, messages/severity metadata, and a single assessment
      entry point.
- [ ] Cover TOML, YAML, explicit `.jsonc`, `.json` parsed using JSONC fallback,
      strict JSON, Markdown/text, unknown/raw-only outcomes, and raw-plus-structured
      merge conditions.
- [ ] Document which current parser fallbacks trigger the conditional risk. Do not
      describe successful-path preservation as a guarantee.
- [ ] Replace `JsonConfigParser.jsoncFallbackWarning`'s unconditional promise that
      comments "are preserved on save" with conditional, accurate wording. Add a
      parser test for the corrected string alongside the existing JSONC fallback
      test; the opening fidelity notice supplements that parse warning but does not
      leave the old promise in place.
- [ ] Add service regression tests for an unchanged raw buffer plus independently
      diverged structured values. In particular, prove that this `saveRawConfig`
      merge routes TOML through the lossy serializer and receives `structuredMerge`
      / `structuredRewrite` risk rather than `directRawWrite`.
- [ ] Add JSON/YAML cases with nested/non-list `permissions` and a simultaneous
      flat-field edit. The assessment must identify the applicable patch scope and
      may conservatively return a conditional risk instead of claiming full-file
      preservation.

### Phase 2 — render the persistent accessible notice

- [ ] Implement the reusable notice with an accessible semantic label and
      high-contrast text.
- [ ] Render it on initial `ConfigEditor` display for TOML, YAML, and parsed JSONC.
- [ ] Assert it is above raw content and does not disappear after editing or opening
      Review Changes.
- [ ] Keep parse warnings separately visible and test both notices together for a
      `.json` file accepted as JSONC.
- [ ] Assert the notice's explicit semantic label and text equivalent of its icon in
      widget tests. Verify a user can learn the risk from text and semantics alone,
      not `AppColors.warning` or `Icons.warning_amber`.

### Phase 3 — align review and save behavior

- [ ] Replace the TOML-only diff-dialog warning with the shared disclosure.
- [ ] Test that the opening and review notices agree on severity and wording.
- [ ] Preserve existing backup, diff, parse-validation, and direct raw-save behavior.
- [ ] Add a regression test that merely opening a config or inspecting the notice
      causes no write or backup.

### Phase 4 — decide fallback safety before broader structured writes

- [ ] Run focused YAML fixtures for comments adjacent to edited keys, anchors,
      aliases, block scalars, nested maps, and unsupported structures.
- [ ] For each fixture, assert either a supported edit retains the adjacent comment
      or the assessed path is conditional/blocked. Do not rely on a generic
      `YamlEditor` success test to establish behavior for the app's actual shapes.
- [ ] Decide whether JSONC/YAML fallback must fail closed instead of rewriting.
      Recommended: block the structured save and direct the user to raw content if
      the preserving path cannot be proven.
- [ ] Decide whether generic TOML structured controls stay writable with a warning
      or become read-only until an AST-aware patcher exists. Record the decision in
      `ADR-001` and update the notice copy if the behavior changes.

## File map

| File | Expected change |
| --- | --- |
| `lib/parsers/config_parser.dart` and/or new pure model | Shared fidelity contract. |
| `lib/parsers/json_config_parser.dart` | Report JSONC preservation/fallback capability without changing parsing semantics. |
| `lib/parsers/yaml_config_parser.dart` | Report in-place/fallback capability. |
| `lib/parsers/toml_config_parser.dart` | Report unconditional rewrite capability. |
| `lib/services/config_service.dart` | Align pre-save assessment with structured and raw-merge paths. |
| `lib/widgets/formatting_fidelity_notice.dart` | Accessible persistent presentation. |
| `lib/widgets/config_editor.dart` | Render shared opening/review notices; remove TOML-only copy. |
| Parser, service, and widget tests | Classification, no-write, semantics, and visibility coverage. |
| `docs/adr/ADR-001-toml-comment-preservation.md` | Record any TOML safety decision. |
| `docs/supported-tools.md` | Make parser/fidelity summary accurately qualified. |

## Acceptance criteria

- Opening a TOML structured config immediately shows an accessible persistent warning
  before the editor; it says viewing is safe and structured saving can discard
  comments and formatting.
- Opening YAML or parsed JSONC immediately shows a persistent caution that accurate
  preserving behavior depends on the safe in-place path; a `.json` filename does
  not suppress the JSONC caution.
- Raw Markdown/text files do not receive an irrelevant conversion warning.
- Review Changes repeats the same risk only when a risky structured save is pending.
- A `.json` file parsed as JSONC no longer contains an unconditional parse warning
  promising comment preservation; its parse and fidelity notices agree that a safe
  in-place update preserves comments but a fallback can rewrite the file.
- When raw content is saved alongside independently dirty structured values, the
  fidelity assessment reports the serializer path. A TOML merge is never represented
  as a direct raw write.
- Unknown and raw-only unsupported files remain usable and do not cause assessment
  errors or inaccurate format-specific notices.
- A file view, notice render, and read-only card interaction create no write or
  backup and leave source bytes untouched.
- The app does not claim a format preserves comments when its active path may fully
  rewrite the document.
- The standard formatter, analyzer, test, internal-link, and pre-commit gates pass.

## Open questions

1. Does `yaml_edit` preserve all YAML constructs relevant to this app's proposed
   schemas? The answer must come from fixtures, not package marketing or a generic
   unit test.
2. Is the right near-term safety posture a strong warning or fail-closed structured
   saves for TOML? The current warning does not itself prevent data loss.
3. Should a future "save as normalized" action provide an explicit opt-in rewrite
   path, separate from the ordinary save button? It is out of scope here.

## Validation

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
python3 ci/scripts/check_doc_links.py --internal-only --strict
pre-commit run --files \
  plans/active/formatting-fidelity-disclosure.md \
  plans/active/structured-configuration-roadmap.md \
  TO_DO.md
```

## Completion steps

1. Record implemented behavior and the fallback decision in the parent roadmap and
   `ADR-001`.
2. Add user-facing notice behavior to `CHANGELOG.md` and test-only/developer details
   to `CHANGELOG.dev.md`.
3. Remove or narrow the linked `TO_DO.md` entry only when the fidelity disclosure
   and its recorded safety decision are complete. Do not close the separate
   [`TO_DO.md` TOML lossless-round-trip follow-up](../../TO_DO.md#deferred-from-pr-5-review-qodo--sonarcloud)
   merely because the warning has shipped.
4. Move this plan to `plans/archive/` as the final completion action.

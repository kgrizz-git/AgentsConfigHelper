# Plan: Formatting Fidelity Disclosure

Last reviewed: 2026-08-28
Date: 2026-08-27
Author: maintainers
Status: in progress — disclosure implemented; fallback-safety decisions remain open
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
| Raw save with independently dirty structured values and a usable baseline | `saveRawConfig` replays the structured values through `parser.serialize` on top of the raw text. | Merge-specific risk; it is not a direct raw write. For TOML, this route reconstructs the document even if the raw edit itself only changed one character. |
| JSON/JSONC supported flat `rules` or `permissions` change | `JsonConfigParser` patches source offsets and validates the resulting JSONC. | Preserving path. |
| JSON/JSONC unsupported/failed patch | Parser catches the failure and fully serializes the decoded map. | Possible rewrite fallback. |
| YAML supported map update | `YamlEditor` updates the parsed source. | Preserving path. |
| YAML failed in-place update | Parser builds a fresh YAML document. | Possible rewrite fallback. |
| TOML structured change | `TomlConfigParser` always serializes a map with `TomlDocument.fromMap`. | Unconditional structured rewrite. |

The current editor has a TOML warning only in the Review Changes dialog and only
after a structured value has changed. Its JSONC parse warning unconditionally says
comments are preserved on save, which is incorrect because a later serializer
fallback can rewrite the document. YAML has no equivalent warning. The existing
source and tests establish these facts:

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
- TOML receives a warning: its structured serializer reconstructs the document and
  will discard existing comments; whitespace, ordering, and layout can change.
- JSON, JSONC, and YAML receive a caution whenever the generic editor offers a
  structured save. The app can attempt an in-place update, but the current parser
  can fall back to a whole-document rewrite. Strict JSON has no valid comments, but
  its formatting can still change; a `.json` file parsed as JSONC must identify the
  comment risk regardless of its extension.
- Markdown/text raw-only files receive no conversion notice. If raw content and
  structured state are independently dirty, the notice must reflect the merge path
  `saveRawConfig` will actually take; it must never classify a parser-backed merge
  as a direct raw write.
- `ConfigFormat.unknown`, a raw-only corrupt-file editor, and an unsupported parser
  outcome are safe/no-assessment states. They must not crash the editor or receive a
  misleading format-specific disclosure.
- Existing parse warnings remain distinct from fidelity notices: one says how a file
  was parsed; the other says what a later structured save may do.
- A JSONC parse warning may state only that comments/trailing commas were detected;
  it must not predict preservation before a later edit is attempted. The fidelity
  assessment owns all save-risk language.
- Markdown/text do not expose structured controls in the editor. If a non-UI caller
  supplies divergent `rules`/`permissions` to their raw save path, `TextConfigParser`
  returns raw text and those values are not persisted. This is not a formatting
  rewrite, but Phase 1 must add a defensive service invariant (prefer rejection)
  rather than silently treating that invalid combination as a successful merge.
- The notice is disclosure, not consent for data loss. Before another structured
  write surface is enabled, decide whether JSONC/YAML fallback must fail closed.

## Design and accessibility contract

The notice is a reusable editor component, not a tool-specific card. It must include:

1. A visible warning/caution icon and concise title. Use **Structured save will
   reconstruct this TOML file** for TOML and **Formatting may change on structured
   save** for JSON, JSONC, and YAML.
2. Plain-language body text naming the relevant format and exact risk. TOML must use
   unambiguous wording: **existing comments will be discarded**.
3. The statement: **Opening this file does not change it on disk.**
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

Introduce a narrow immutable assessment, preferably near the parser contract. Keep
the visual risk separate from the save mechanism so the widget does not translate a
large enum back into user-facing concepts:

```dart
enum FidelityRisk { none, caution, warning }

enum SaveMechanism { directRaw, parserSerialization }

class FidelityAssessment {
  const FidelityAssessment({
    required this.risk,
    required this.mechanism,
    required this.formatLabel,
  });

  final FidelityRisk risk;
  final SaveMechanism mechanism;
  final String formatLabel;
}
```

The editor-opening assessment is a conservative capability statement, not a promise
that a particular edit will patch successfully: TOML is `warning`; generic JSON,
JSONC, and YAML are `caution`; raw-only/Markdown/text receive no conversion notice.
`rawOnly` is an opening-assessment input and takes precedence over the supplied file
format: a recovery editor for corrupt JSON, YAML, or TOML has no structured save path
and therefore returns no assessment. This prevents a recovery editor from showing a
misleading format-specific warning.
The pending-save assessment distinguishes `saveConfig` (parser serialization), a
direct `saveRawConfig` write, and a `saveRawConfig` structured merge. It requires the
format, editor raw-only state, save kind, usable baseline, and whether the structured
values diverged from that baseline. Parsed JSONC status selects accurate wording but
does not reduce the caution. Do not predict in-place JSON/YAML success by inspecting
AST geometry—the parsers currently decide that only while serializing and may catch
any failure into a rewrite fallback.

`ConfigFormat.unknown` and unsupported recovery files return no assessment rather
than an enum state. For a non-UI text/Markdown call with divergent structured values,
the service must reject before classifying a successful save; it is not a valid
direct-raw mechanism.

### 2. Parser and service integration

- Keep parser-specific policy alongside the parser or `ConfigParser` contract.
- Provide a small pure `FidelityAssessor` that `ConfigEditor` can consume without
  I/O. It owns display severity/text keys; the widget only renders its result.
- Use the same policy for `ConfigService.saveConfig`, the direct branch of
  `saveRawConfig`, and the structured-merge branch of `saveRawConfig`. The initial
  version does not need to change JSON/YAML fallback behavior. It must make every
  *potential write classification* observable and testable; it must not pretend to
  know an individual JSON/YAML serialization result before that parser runs. Cover
  deterministic parser fallback fixtures separately where they exist. Do not add
  instrumentation solely to make an otherwise unreachable catch-all fallback appear
  in a service test; the Phase 4 fail-closed decision may require an explicit
  serialization-outcome seam.
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

- [x] Add pure-Dart states, messages/severity metadata, and a single assessment
      entry point: a three-level display risk plus a direct-raw versus
      parser-serialization mechanism.
- [x] Cover TOML, YAML, explicit `.jsonc`, `.json` parsed using JSONC fallback,
      strict JSON (including a `.jsonc` file containing strict JSON), Markdown/text,
      unknown/raw-only outcomes, and raw-plus-structured merge conditions.
- [ ] Make raw-only precedence explicit in the pure contract: a recovery editor for
      corrupt TOML or JSON returns no opening fidelity assessment even though its
      discovered format is TOML or JSON. Add widget coverage that the recovery editor
      has no notice or structured controls and that its repaired raw save is direct.
- [ ] Document which current parser fallbacks trigger the conditional risk. Do not
      describe successful-path preservation as a guarantee.
- [x] Replace `JsonConfigParser.jsoncFallbackWarning`'s unconditional promise that
      comments "are preserved on save" with a parse-only statement that JSONC syntax
      was detected. Add a parser test for the corrected string alongside the
      existing JSONC fallback test; the opening fidelity notice owns the conditional
      save-risk language. Assert the new warning identifies detected comments or
      trailing commas and no longer contains "preserved on save". `JsoncCleaner`
      currently cannot say which of comments or trailing commas it removed, so retain
      combined wording rather than claiming the parser identified one exact syntax.
- [ ] Add service regression tests for an unchanged raw buffer plus independently
      diverged structured values. In particular, prove that this `saveRawConfig`
      merge routes TOML through the lossy serializer and receives warning/
      parser-serialization rather than `directRaw`.
- [x] Add the concrete merge regression: a TOML `saveRawConfig` with a one-character
      raw edit and independently diverged structured values must route through
      `TomlDocument.fromMap`, lose a fixture comment, and assess as
      warning/parser-serialization rather than `directRaw`. Also assert it creates
      exactly one pre-write backup, so this exceptional merge path retains the normal
      backup-before-write guarantee.
- [ ] Add JSON/YAML cases with nested/non-list `permissions` and a simultaneous
      flat-field edit. The assessment stays conservatively `caution`; tests may
      document a successful rules-only patch but must not infer pre-save certainty
      from it. Assert the opening assessment remains `caution` even when the known
      fixture happens to patch successfully.
- [ ] Cover `saveConfig` explicitly for every supported structured format, including
      a newly-created file with no usable original source; JSON/JSONC/YAML remain
      caution because serialization can rebuild the document.
- [x] Assert a `.jsonc` file that is valid strict JSON is still opening-assessed as
      `caution` (formatting can change), but receives no JSONC parse warning.
- [x] Add a service invariant for text/Markdown with divergent structured values.
      Confirm the normal UI cannot construct it, then reject it (preferred) or make
      any alternative non-lossy behavior explicit and tested.

### Phase 2 — render the persistent accessible notice

Phase 1's text/Markdown divergent-structured-values invariant is a prerequisite for
this phase. Do not render a "no conversion notice" state while the service can still
silently accept and discard that invalid overlay.

- [x] Implement the reusable notice with an accessible semantic label and
      high-contrast text.
- [x] Render it on initial `ConfigEditor` display for TOML, JSON/JSONC, and YAML.
- [ ] Assert it is above raw content and does not disappear after editing or opening
      Review Changes.
- [x] Keep parse warnings separately visible and test both notices together for a
      `.json` file accepted as JSONC.
- [ ] Assert raw-only recovery editors for corrupt TOML and JSON show neither a
      fidelity notice nor structured controls. Their repaired raw save remains a
      direct raw write.
- [x] Assert the notice's explicit semantic label and text equivalent of its icon in
      widget tests. Verify a user can learn the risk from text and semantics alone,
      not `AppColors.warning` or `Icons.warning_amber`.

### Phase 3 — align review and save behavior

- [x] Replace the TOML-only diff-dialog warning with the shared disclosure.
- [x] Test that the opening and review notices agree on severity and wording.
- [x] Preserve existing backup, diff, parse-validation, and direct raw-save behavior.
- [ ] Add a regression test that merely opening a config or inspecting the notice
      causes no write or backup.

### Phase 4 — decide fallback safety before broader structured writes

- [ ] Run focused YAML fixtures for comments adjacent to edited keys, anchors,
      aliases, block scalars, nested maps, and unsupported structures.
- [ ] Include a comment between a key and its block value, plus an alias whose target
      key is edited. These are likely `yaml_edit` edge cases; an alias rewritten as a
      literal is a semantic change, not merely a formatting difference.
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
| `lib/parsers/config_parser.dart` and/or `lib/services/fidelity_assessor.dart` | Shared pure assessment contract. |
| `lib/parsers/json_config_parser.dart` | Remove the false JSONC preservation promise and expose accurate parse status. |
| `lib/parsers/yaml_config_parser.dart` | Report in-place/fallback capability. |
| `lib/parsers/toml_config_parser.dart` | Report unconditional rewrite capability. |
| `lib/services/config_service.dart` | Align pre-save assessment with structured and raw-merge paths. |
| `lib/widgets/formatting_fidelity_notice.dart` | Accessible persistent presentation. |
| `lib/widgets/config_editor.dart` | Render shared opening/review notices; remove TOML-only copy. |
| Parser, service, and widget tests | Classification, no-write, semantics, and visibility coverage. |
| `README.md` and `ARCHITECTURE.md` | Replace unconditional comment-preservation claims with the conditional JSON/JSONC/YAML behavior and the always-lossy TOML behavior. |
| `CHANGELOG.md` | Add the user-facing notice behavior while retaining the existing Unreleased correction for the prior broad comment-preservation claim; preserve the historical 0.1.0 entry rather than rewriting release history. |
| `docs/adr/ADR-001-toml-comment-preservation.md` | Record any TOML safety decision. |
| `docs/supported-tools.md` | Describe `yaml_edit` as the in-place path and qualify all parser/fidelity claims. |

## Acceptance criteria

- Opening a TOML structured config immediately shows an accessible persistent warning
  before the editor; it says opening does not change the source file and a structured
  save reconstructs the document, discarding existing comments.
- Opening JSON, JSONC, or YAML in the generic structured editor immediately shows a
  persistent caution that the current serializer can rewrite formatting; a `.json`
  filename does not suppress the JSONC comment-risk wording.
- Raw Markdown/text files do not receive an irrelevant conversion warning.
- Review Changes repeats the same risk only when a risky structured save is pending.
- A `.json` file parsed as JSONC no longer contains an unconditional parse warning
  promising comment preservation; the parse notice reports syntax detection only
  and the fidelity notice owns the potential rewrite warning.
- When raw content is saved alongside independently dirty structured values, the
  fidelity assessment reports the serializer path. A TOML merge is never represented
  as a direct raw write.
- Unknown and raw-only unsupported files remain usable and do not cause assessment
  errors or inaccurate format-specific notices.
- A direct raw save with no structured divergence remains direct, including TOML.
  A raw-plus-structured TOML merge reports warning/parser-serialization. A text or
  Markdown structured overlay cannot be silently discarded as a successful save.
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
4. How should an externally changed file be handled between opening the editor and
   saving it? Review Changes refreshes the current on-disk JSON/JSONC parse status
   before a structured save so its disclosure describes the source `saveConfig`
   will serialize. A replacement after the dialog opens remains a separate
   conflict-handling decision; add a focused regression before archive.

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
2. Align `README.md`, `ARCHITECTURE.md`, `docs/supported-tools.md`, and `ADR-001` with
   the shipped conditional-fallback behavior. Add user-facing notice behavior to
   `CHANGELOG.md` while retaining its correcting Unreleased entry; add
   test-only/developer details to `CHANGELOG.dev.md`. Do not rewrite the historical
   0.1.0 release entry.
3. Remove or narrow the linked `TO_DO.md` entry only when the fidelity disclosure
   and its recorded safety decision are complete. Do not close the separate
   [`TO_DO.md` TOML lossless-round-trip follow-up](../../TO_DO.md#deferred-from-pr-5-review-qodo--sonarcloud)
   merely because the warning has shipped.
4. Move this plan to `plans/archive/` as the final completion action.

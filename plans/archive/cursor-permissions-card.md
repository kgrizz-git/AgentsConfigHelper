# Plan: Cursor Agent Permissions Card (roadmap Phase 4A, read-only)

Last reviewed: 2026-09-07
Date: 2026-09-07
Author: maintainers
Status: complete — implemented on the `impl/cursor-permissions-card` branch (2026-09-07) and archived
Linked parent: [Structured Configuration Roadmap](../active/structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Outcome

Shipped on the `impl/cursor-permissions-card` branch. A pure-Dart
`CursorPermissionsAdapter` + `CursorPermissionsPresentation` + reviewed help implement
`PolicyCardAdapter`; a read-only `CursorPermissionsCard` widget mirrors the Claude card.
Both register in the shared `PolicyCardRegistry`/`PolicyCardWidgetRegistry`, so the card
renders with **no `ConfigEditor` change** (the Phase 0 seam holds). The adapter guards
the catalog path with a component-boundary check (rejecting near-misses), preserves
omitted-vs-explicit-`[]` per field, keeps unknown siblings unclassified, and returns
unsupported (raw-editor-first) for malformed recognized fields (never imitating Cursor's
silent drop). On-disk fixtures under `test/fixtures/cursor_home` and `edge_cases`
exercise the states, including a JSONC file; the full suite is green (400 tests, +36
from the 364 baseline). Docs: `docs/supported-tools.md` (fixtures + JSONC note + card),
user-facing `CHANGELOG.md` entry, roadmap Phase 0 + Phase 4A marked done with open
questions resolved, and the `TO_DO.md` note updated. The primary Cursor reference was
re-checked 2026-09-07.

## Objective

Add a read-only policy card for catalog-discovered Cursor Agent `permissions.json`
as the first non-Claude consumer of the shared policy-card registry introduced in
PR #41. A Cursor adapter registers in `PolicyCardRegistry` and a Cursor card builder
registers in `PolicyCardWidgetRegistry` — with **no new branch in `ConfigEditor`**,
which is exactly the seam the Phase 0 refactor was built to prove. This delivers
roadmap Phase 4A: `structured-configuration-roadmap.md:197-249`.

It is a **presentation slice only**: the card displays the file's stored entries and
must not calculate the effective Cursor permission policy or write a Cursor file.

## Primary source

Cursor's `permissions.json` reference reviewed 2026-08-27
(<https://cursor.com/docs/reference/permissions>) documents the user path
`~/.cursor/permissions.json`, the project path `<workspace>/.cursor/permissions.json`,
JSONC support, and four optional stored fields. Re-check this reference before
implementation and retain the review date in `docs/supported-tools.md`.

| Stored field | Accepted display shape | Card meaning |
| --- | --- | --- |
| `mcpAllowlist` | `string[]` | MCP `server:tool` patterns declared in this file. |
| `terminalAllowlist` | `string[]` | Terminal command/prefix patterns declared in this file. |
| `autoRun.allow_instructions` | `string[]` | Natural-language guidance that leans Auto-review toward allowing calls. |
| `autoRun.block_instructions` | `string[]` | Natural-language guidance that leans Auto-review toward prompting. |

All four fields are optional. Unknown top-level or `autoRun` sibling keys remain
unclassified and available in raw content.

## Scope

### In scope

- A pure-Dart `CursorPermissionsAdapter` implementing `PolicyCardAdapter`, with a
  `CursorPermissionsPresentation` and reviewed, plain-language help.
- A read-only `CursorPermissionsCard` widget and its registration in
  `PolicyCardWidgetRegistry.shared`.
- Registration of the Cursor adapter in `PolicyCardRegistry.shared`.
- Fixtures and tests: adapter, registry selection, widget mapping, card, fallback,
  help/link failure, JSONC labeling, and a read-only/no-byte-mutation assertion.
- Docs and docstring follow-through (see [Docs, docstrings, and metadata](#docs-docstrings-and-metadata)).

### Out of scope

- Any write, patch, or serialization path for Cursor files. No save control.
- Computing an effective/runtime Cursor permission policy or precedence outcome.
- Editing `mcpAllowlist` / `terminalAllowlist` / `autoRun` values.
- Other Cursor files (`cli-config.json`, `sandbox.json`, `settings.json`,
  `.cursor/rules/*.mdc`, `.cursorrules`, `AGENTS.md`/`CLAUDE.md`).
- Any change to the generic flat `permissions`/`rules` editors, `FidelityAssessor`,
  `StructuredSaveFlow`, or `ConfigEditor` structure.

## Current-state baseline (as of plan start)

- `lib/schemas/policy_card_registry.dart` — `PolicyCardRegistry.shared` seeds only
  `ClaudeCodePermissionsAdapter()`. `select` returns the first non-`notApplicable`
  selection or the `noAdapterId` sentinel. Registration order wins.
- `lib/widgets/policy_card_widget_registry.dart` — `shared` maps
  `ClaudeCodePermissionsAdapter.adapterId` → `_buildClaudeCard`; `buildCard` returns
  `null` for unknown ids / non-available / null presentation.
- `lib/schemas/policy_card.dart` — `PolicyCardAdapter` interface (`String get id`,
  `PolicyCardSelection interpret({config, discoveredConfig})`), `PolicyCardStatus`,
  `PolicyCardPresentation`.
- `lib/widgets/config_editor.dart` — `build` resolves `_registry.select(...)` and
  renders `_widgetRegistry.buildCard(selection)`, falling back to the generic flat or
  nested-permissions text. No Cursor-specific code; none is added.
- `lib/catalog/tool_descriptor_registry.dart` — `ToolId.cursor` declares two
  `ConfigTarget`s for `.cursor/permissions.json` (user and project), format `json`,
  kind `structuredConfig`.
- `lib/parsers/json_config_parser.dart` — `ToolConfig.rawSettings` is the decoded
  **top-level** object. For a Cursor `permissions.json` the whole document *is* the
  policy, so the adapter reads fields directly from `config.rawSettings`
  (mirroring how the Claude adapter reads the `permissions` subtree). `ToolConfig`
  also carries `parsedAsJsonc` (true when strict JSON failed and a JSONC fallback
  decoded the file).
- `lib/services/fidelity_assessor.dart` — `_jsonLabel` already labels by parsed
  content (`parsedAsJsonc`) and the `.jsonc` suffix, **not** by the discovered
  filename alone. This resolves roadmap open question 3 (below): no new notice is
  needed; the existing opening notice already says "JSONC" for a `.json` Cursor file
  that parses as JSONC.
- `docs/supported-tools.md` — Cursor Agent evidence row (line 53) records "no fixture
  exercising the structured config"; the `permissions.json` format section (line 341)
  does not yet state JSONC acceptance.
- The generic flat editor would show an empty list for a Cursor file (it has no
  `permissions` key), so today a Cursor `permissions.json` renders only raw content
  plus an empty flat editor — the empty behavior this card replaces.

## Target design

### Adapter (`lib/schemas/cursor_permissions.dart`, pure Dart)

```dart
class CursorPermissionsAdapter implements PolicyCardAdapter {
  static const adapterId = 'cursor.permissions';          // static + instance id, as Claude
  static final Uri documentationUri =
      Uri.parse('https://cursor.com/docs/reference/permissions');

  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) { /* see below */ }
}
```

`interpret` returns:

- **`notApplicable`** — when the config is not a catalog-discovered `ToolId.cursor`
  `.cursor/permissions.json` target. Target check (`_isCursorPermissionsTarget`):
  `discoveredConfig != null && fromCatalog &&
  discoveredConfig.descriptor?.id == ToolId.cursor &&
  kind == ConfigSourceKind.structuredConfig &&
  discoveredConfig.format == ConfigFormat.json &&
  config.format == ConfigFormat.json &&
  scope in {user, project}` — identical shape to the Claude adapter's
  `_isClaudeSettingsTarget`, so manual paths, other tools, and `null` discovery all
  fall through. (A `.json` Cursor file that parses as JSONC still has discovered
  format `json`; the JSONC nuance is surfaced by the fidelity notice, not by widening
  the adapter's format match.)

  **Do not rely on the kind/format/scope combination alone.** It matches the two
  `.cursor/permissions.json` targets today, but a future catalog addition of any other
  user/project `structuredConfig` + JSON Cursor file (for example `.cursor/mcp.json`)
  would be mis-identified as a permissions card. The adapter must additionally verify
  the discovered file is one of the two `.cursor/permissions.json` catalog targets by
  matching its normalized path at a **path-component boundary**: `p.basename(filePath)
  == 'permissions.json' && p.basename(p.dirname(filePath)) == '.cursor'`. Use
  `discoveredConfig.filePath` only — it is normalized via `p.normalize`
  (`lib/models/discovered_config.dart:33,95`), whereas `config.filePath`
  (`lib/models/tool_config.dart:48`) is un-normalized user input. This basename +
  immediate-parent check (both platform-independent via `p`) rejects near-misses that a
  raw `endsWith('.cursor/permissions.json')` would wrongly accept — for example
  `workspace.cursor/permissions.json` (whose parent is `workspace.cursor`, not
  `.cursor`) or any other directory's `permissions.json`. Keep this path-identity guard
  in `_isCursorPermissionsTarget`; add regression tests asserting a **different Cursor
  structured-JSON target** (a `.cursor/…/something.json` with `structuredConfig`,
  `json`, user scope) is `notApplicable`, and that a **near-miss path**
  (`workspace.cursor/permissions.json` with the same catalog-descriptor/kind/format/
  scope) is also `notApplicable`.
- **`available`** — a valid policy object. `rawSettings` is the top-level object;
  recognize `mcpAllowlist`, `terminalAllowlist`, and `autoRun` with
  `allow_instructions` / `block_instructions`. Each recognized field is **optional**;
  **preserve whether a field was omitted vs explicitly present**, since both are valid
  stored states. A field that is **present** must be a `string[]` (it may be empty), and
  its value is retained. A field that is **absent** is recorded as omitted (null), not
  as an empty list — this matters for the card copy ("Not set" vs "No entries.", below).
  `autoRun`, when present, must be a `Map` whose recognized subfields are `string[]`
  (each also tracked as present-or-omitted). An empty object and omitted fields are
  valid empty policy states. Unknown top-level or `autoRun`
  sibling keys set `hasUnclassifiedSettings` but do not suppress the card.

  The recognized-key sets must be explicit constants (mirroring
  `ClaudeCodePermissionsAdapter._recognizedKeys`):
  - top level: `mcpAllowlist`, `terminalAllowlist`, `autoRun`;
  - `autoRun` sub-keys: `allow_instructions`, `block_instructions`.
  `hasUnclassifiedSettings` is true when any top-level key is outside the first set
  **or** any `autoRun` sub-key is outside the second set. A top-level key or
  `autoRun` sub-key that is not a `String` is **unsupported**, not an unclassified
  key — mirror Claude's rejection of non-`String` keys (`claude_code_permissions.dart:179-190`).
- **`unsupported`** (with a plain-language `unsupportedReason`) — when a **present
  recognized field** is not the accepted shape: a non-list value, a list containing a
  non-string entry, or `autoRun` present but not a `Map`. This mirrors the Claude
  adapter's `_stringArray`/`_unsupportedField` helpers and keeps raw-editor-first so
  the app does not silently imitate Cursor's dropping of malformed entries.

`CursorPermissionsPresentation extends PolicyCardPresentation` (Equatable):
`mcpAllowlist`, `terminalAllowlist`, `allowInstructions`, `blockInstructions`
(non-null `List<String>`? per field, **null = omitted from the file**; an explicit `[]`
is a non-null empty list) and `hasUnclassifiedSettings` (bool). Field lists are
`List.unmodifiable` in the constructor, matching the Claude presentation. Unlike the
Claude presentation there is **no `hasConfiguredPolicy` flag**: for Cursor the file
itself is the policy, so an empty object or omitted fields are a valid **configured but
empty** policy (Claude's flag exists only because the `permissions` subtree can be
absent from a `settings.json`; that is not a Cursor case). The card therefore shows no
"no policy is configured" banner. Because a field's presence is preserved, each field
group renders one of three states, mirroring the Claude card's per-field copy
(`claude_code_permissions_card.dart:117-121`):

- **omitted** (`null`) → **"Not set."** (the field is not present in this file);
- **present and empty** (`[]`) → **"No entries."** (deliberately allow nothing here);
- **non-empty** → the bulleted entries, as before.

`CursorPermissionsHelp` — reviewed, plain-language `label` + `description` per field,
modeled on `ClaudeCodePermissionsHelp`. The card-level statement and each field's
description must say the card shows **this file's stored entries, not runtime
decisions**. Because a `permissions.json` is a single file, the card displays only that
one file's entries — it does not merge or show user and project arrays together. (Cursor
combines the user and project files at runtime, and team-admin or in-app settings can
take precedence; the help text may mention that as Cursor's behavior, but must not claim
the card itself computes the combined/effective policy.) Do not encode reports of
version-specific Cursor behavior as product truth. All help lives in the pure-Dart
schema layer.

### Card widget (`lib/widgets/cursor_permissions_card.dart`)

A read-only `StatelessWidget` mirroring `ClaudeCodePermissionsCard`: header with
`Icons.policy_outlined`, the card-level help statement, a per-field group (label +
count, help button, and the three-state entry rendering from the presentation spec:
bulleted `SelectableText` entries for non-empty, **"No entries."** for explicit `[]`,
**"Not set."** for omitted), an unclassified-settings note when
`hasUnclassifiedSettings`, and a documentation
launcher (`TextButton.icon` → `documentationUri`) with the same
`onOpenDocumentation`/error-SnackBar pattern as the Claude card. No editing controls,
no write path; it renders only from the immutable presentation.

### Registrations

- `PolicyCardRegistry.shared` → add `CursorPermissionsAdapter()`. Keep the Claude
  adapter first (current order); the two adapters match disjoint descriptor ids, so
  order is not behavior-critical, but registration order is the documented selection
  rule and the ordering test asserts first-match-wins.
- `PolicyCardWidgetRegistry.shared` → add
  `CursorPermissionsAdapter.adapterId: _buildCursorCard`. `_buildCursorCard` type-checks
  the presentation (`is!`) and returns `CursorPermissionsCard(...)` (default launcher),
  exactly like `_buildClaudeCard`.

### File-length gate

The repo's `check-file-length` hook caps files at 700 lines. The two new source files
(`lib/schemas/cursor_permissions.dart`, `lib/widgets/cursor_permissions_card.dart`)
track their Claude mirrors (258 and 225 lines respectively) and are expected to land
well under the limit, but verify both after implementation. `test/fixtures/
cursor_permissions_fixtures_test.dart` is new; do not add these tests to any file that
is already near the cap.

### ConfigEditor

**No changes.** `build` already renders whatever `buildCard(selection)` returns. The
whole slice reduces to "register an adapter + a card builder", which is the Phase 0
goal. Any need to touch `ConfigEditor` is a signal the seam is wrong and should be
flagged, not worked around. This is also load-bearing for the file-length gate:
`lib/widgets/config_editor.dart` is already at **700 lines** (checked 2026-09-07), so
the slice must not add or grow any `ConfigEditor` code.

## Test strategy

Follow the Claude vertical-slice test layout so the two adapters stay symmetric.

### Adapter unit tests (`test/schemas/cursor_permissions_test.dart`)

- `notApplicable` for: a manual-path Cursor config (`fromCatalog: false`), a
  non-Cursor tool, `discoveredConfig: null`, a non-`.cursor/permissions.json`
  Cursor target (other format/kind), a **different Cursor structured-JSON target**
  (a `.cursor/…/something.json` with `structuredConfig`, `json`, user scope — proves the
  path-identity guard, per the target-check note above), and a **near-miss path**
  (`workspace.cursor/permissions.json` with the same descriptor/kind/format/scope —
  its parent is `workspace.cursor`, not `.cursor`).
- `available` for catalog-discovered user-scope and project-scope targets; each of the
  four fields parses to its list.
- `available` with a present-but-empty `[]` field is distinct from an **omitted** field:
  a present `[]` yields a non-null empty list, an omitted field yields `null`
  (assert both explicitly, for a top-level field and for an `autoRun` subfield).
  An empty object is a valid empty policy (`hasUnclassifiedSettings: false`).
- `available` with unknown top-level keys and unknown `autoRun` sibling keys sets
  `hasUnclassifiedSettings: true` but stays available.
- `unsupported` (raw-editor-first) for: a recognized field that is not a list, a list
  with a non-string entry, `autoRun` present but not a `Map`, and a non-`String`
  top-level or `autoRun` sub-key.
- Registry selection: a Cursor config through `PolicyCardRegistry.shared`-equivalent
  (Claude + Cursor adapters) resolves to the Cursor selection with
  `CursorPermissionsPresentation`; a Claude config still resolves to Claude (no
  cross-match).

  The `test/schemas/policy_card_registry_test.dart` file already defines a
  `cursorConfig()` helper (line 54); reuse it in the new adapter test if convenient,
  or add a local copy to `test/schemas/cursor_permissions_test.dart` — either is fine,
  but choose one and keep the registry test's helper untouched.

### Fixtures (`test/fixtures/cursor_permissions_fixtures_test.dart`)

**On-disk, token-free fixtures** under `test/fixtures/` (mirroring the Claude fixture
layout, which reads files from `test/fixtures/` — see `claude_permissions_fixtures_test.dart:36-44`),
not inline strings. Suggested paths: `test/fixtures/staging_home/.cursor/permissions.json`
(user), `test/fixtures/staging_home/workspace/.cursor/permissions.json` (project), and
`test/fixtures/edge_cases/cursor_permissions_*.json` for: a **JSONC** fixture with
comments and a trailing comma; malformed recognized fields (non-list, non-string
entry); an unsupported nested shape (`autoRun` non-Map / malformed subfield); unknown
siblings; an **explicit-empty** policy (one or more fields set to `[]`); an **omitted**
policy (a field absent from the object, distinct from `[]`); and an empty policy.
The fixtures test asserts parsing and presentation correctness, including that an
explicit `[]` and an omitted field are preserved as distinct states.
The no-save / no-byte-change assertion lives in the ConfigEditor
integration test (`test/widgets/config_editor_policy_card_test.dart`, which at 257
lines has room); it is **not** duplicated in the fixtures test. Record the fixture
paths in the `docs/supported-tools.md` evidence row (below).

> **Non-string keys are not a fixture case.** JSON/JSONC decoding always yields `String`
> object keys (an unquoted key is a parse error; a quoted key decodes to a string and
> follows the unclassified-key path). A non-`String` key can only be constructed directly
> in a Dart `Map`, so it is exercised only in the direct-construction adapter unit tests
> (the `unsupported` case above), not in an on-disk fixture.

### Widget mapping (`test/widgets/policy_card_widget_registry_test.dart`)

- `CursorPermissionsAdapter.adapterId` maps to the Cursor card.
- `buildCard` returns `null` (no crash) for an unknown id / non-available / null
  presentation passed to the Cursor builder (same contract as Claude).

### Card widget (`test/widgets/cursor_permissions_card_test.dart`)

- Renders each field group with its count and entries; the three empty-states are
  distinct: an omitted field shows **"Not set."**, a present-but-empty `[]` field shows
  **"No entries."**, and a non-empty field shows its bulleted entries.
- Help dialog opens per field; documentation-launcher failure shows the error
  SnackBar when the URL cannot be opened (inject a failing `onOpenDocumentation`).

### ConfigEditor integration (`test/widgets/config_editor_policy_card_test.dart`)

Policy-card editor integration lives in `test/widgets/config_editor_policy_card_test.dart`
(257 lines), not `config_editor_test.dart` — route the Cursor card, fallback, and
read-only integration tests there to match the repo convention (Claude's policy-card
editor tests already live there). This file already contains a test to **rewrite**:
`config_editor_policy_card_test.dart:17-71` builds a catalog-discovered `ToolId.cursor`
`.cursor/permissions.json` with a top-level `permissions` Map and currently expects the
generic nested notice. Once the Cursor adapter lands, that config is `available` (unknown
top-level `permissions` → `hasUnclassifiedSettings: true`, empty recognized lists) and
renders a Cursor card, so the assertion breaks. Rewrite that test to use a tool with **no
matching adapter** (e.g. `ToolId.lmStudio` or a manual-path config) — it becomes the
generic-fallback test below.

Add to `test/widgets/config_editor_policy_card_test.dart`:

- A catalog-discovered Cursor `permissions.json` renders the Cursor card (not the
  flat editor, not the nested-permissions text).
- A config with a `permissions` Map for a tool with **no matching adapter** — e.g. a
  `ToolId.lmStudio` config, or a manual-path config with `descriptor: null` — still
  renders the generic nested-permissions text. This proves the Cursor adapter did not
  swallow generic tools (and replaces the rewritten test above). Do **not** use a
  Claude-style `permissions` Map here: the Claude adapter is registered first in
  `PolicyCardRegistry.shared` and would match that config, masking the generic-fallback
  behavior this test is meant to guard.
- A **malformed recognized field** (e.g. `mcpAllowlist` not a list) renders the
  unsupported-reason text and **no** Cursor card (raw-editor-first), mirroring Claude's
  editor-level unsupported test (`config_editor_test.dart:421-519`).
- A Cursor card is **read-only**: interacting (opening help/docs) never mutates
  `originalContent` or triggers a save.

### JSONC fidelity labeling (in `test/fixtures/cursor_permissions_fixtures_test.dart`)

- Opening a `.json` Cursor fixture that parses as JSONC yields a `JSONC`-labeled
  opening notice via the existing `FidelityAssessor` (no new notice code). Put this
  assertion in the fixtures test, **not** `test/widgets/config_editor_fidelity_test.dart`
  — that file is already at the 700-line hook limit (checked 2026-09-07) and extending
  it would breach the gate.

## Docs, docstrings, and metadata

The Cursor card is **user-visible**, so this slice updates user-facing docs (unlike
the Phase 0 registry refactor, which was developer-only).

- `docs/supported-tools.md`:
  - Evidence row for Cursor Agent (line 53): change "no fixture exercising the
    structured config" to record the new on-disk fixture paths (for example
    `test/fixtures/staging_home/.cursor/permissions.json` and
    `test/fixtures/edge_cases/cursor_permissions_*.json`) and the read-only card;
    update the source-review date.
  - Cursor Config format section (line 341): state that `permissions.json` accepts
    JSONC despite the `.json` filename, and that the app's fidelity notice follows
    parsed content.
  - Tool-overview summary table (line 26, Cursor Agent row): reflect the read-only
    structured card. (This is the overview table near the top of the file, not the
    "Config format summary" table around line 697, which lists format/parser rows —
    JSON/JSONC, TOML, YAML, Markdown — and needs no Cursor change.)
- `CHANGELOG.md`: add a user-facing entry for the read-only Cursor permissions card.
- `plans/active/structured-configuration-roadmap.md`: mark the Phase 0 shared-interface
  box done (Cursor is the first non-Claude consumer); check off the completed Phase 4A
  acceptance items; resolve the three open questions (below).
- `TO_DO.md`: keep the "Structured configuration presentation" entry open (more tools
  remain) but note the Cursor card shipped; reference the archived plan after archival.
- **Docstrings:** every new public member in `cursor_permissions.dart`,
  `cursor_permissions_card.dart`, and the registry additions gets a doc comment
  following the existing convention (concise; no comments unless they add non-obvious
  context — public API docstrings are the established norm in these files).

## Resolved open implementation questions

1. **Effective-policy / precedence reports** — the card avoids computing an effective
   policy, so this does not block read-only presentation. Re-check the primary
   reference before implementation; retain the review date in `supported-tools.md`.
2. **All four fields vs split `autoRun`** — show **all four fields** in the first
   card (recommended in the roadmap). Splitting `autoRun` would leave a documented
   permission-adjacent object raw.
3. **JSONC notice vs a JSONC Cursor fixture** — resolved by the existing
   `FidelityAssessor._jsonLabel`, which labels by parsed content (`parsedAsJsonc`)
   and the `.jsonc` suffix, not the filename. No new notice code; add the regression
   test asserting a JSONC Cursor fixture opens with a `JSONC`-labeled notice.

## Implementation steps

1. Add `lib/schemas/cursor_permissions.dart` (adapter + presentation + help, all
   pure Dart, docstrings on public members). `CursorPermissionsAdapter.adapterId =
   'cursor.permissions'` with `String get id => adapterId;` (required by the
   interface; a static member cannot satisfy `implements`).
2. Add `lib/widgets/cursor_permissions_card.dart` (read-only card, default doc
   launcher, help dialog, no write path).
3. Register the adapter in `PolicyCardRegistry.shared` and the card builder in
   `PolicyCardWidgetRegistry.shared`. Confirm `ConfigEditor` needs **no** changes.
4. Add the fixtures and tests from [Test strategy](#test-strategy), including
   **rewriting the existing cursor-nested test** in
   `config_editor_policy_card_test.dart:17-71` to use a no-adapter tool (it breaks once
   the Cursor adapter makes that config `available`).
5. Update the docs, `CHANGELOG.md`, roadmap (check Phase 0 box + Phase 4A items +
   resolve questions), and `TO_DO.md` from
   [Docs, docstrings, and metadata](#docs-docstrings-and-metadata).
6. Run the gates; then review the branch, fix findings, and archive this plan as the
   final commit before merge (per AGENTS.md — never a direct-to-main post-merge step).

## Acceptance criteria

- A catalog-discovered Cursor `permissions.json` (user or project) renders a read-only
  card showing the file's stored `mcpAllowlist`, `terminalAllowlist`, and
  `autoRun.allow_instructions` / `block_instructions`.
- Manual paths and other tools are unaffected; a non-Cursor nested Map still renders
  the generic nested-permissions text; the flat editor still handles other cases.
- A present recognized field with a non-list / non-string entry, or `autoRun` not a
  `Map`, is an unsupported subtree → raw-editor-first (never imitates Cursor's silent
  drop). Unknown keys alone do not suppress an otherwise valid card; an empty object /
  omitted fields are a valid empty policy.
- The card states it shows stored entries, not runtime decisions.
- `ConfigEditor` is unchanged (no new tool branches).
- No interaction with the card saves or changes bytes.
- Gates green: `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze --fatal-infos`, `flutter test`, and
  `python3 ci/scripts/check_doc_links.py --internal-only --strict`.

## Completion steps

Per AGENTS.md, archive this plan as the last step before merging (final commit on this
feature branch, riding in the PR; never a direct-to-main post-merge step):

1. [x] Record the seam in the parent roadmap: mark Phase 0's shared-interface box `[x]`
   (Cursor is the first non-Claude consumer) and the completed Phase 4A acceptance
   items; resolve the open questions.
2. [x] Keep the `TO_DO.md` "Structured configuration presentation" entry open and aligned.
3. [x] Log the change in `CHANGELOG.md` (user-visible card) and `CHANGELOG.dev.md` if any
   developer-only note is warranted.
4. [x] Move this file to `plans/archive/` as the final commit on the branch.

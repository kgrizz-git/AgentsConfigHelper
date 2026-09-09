# Plan: Opencode Permissions Card (roadmap Phase 4, item 1)

Last reviewed: 2026-09-08
Date: 2026-09-08
Author: maintainers
Status: active — awaiting review and implementation
Linked parent: [Structured Configuration Roadmap](../active/structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Objective

Add a read-only policy card for the Opencode `permission` object (a catalog-discovered
`opencode.json`), as the second non-Claude consumer of the shared policy-card registry
after Cursor (Phase 4A). Opencode is the roadmap's Phase 4 "expand one schema at a time"
progression item 1: `structured-configuration-roadmap.md:188-191` names "Opencode's
per-tool allow/ask/deny maps, as a distinct nested-map adapter." A new
`OpencodePermissionsAdapter` + `OpencodePermissionsCard` register in the shared
registries with **no `ConfigEditor` change**, proving the seam a third way.

It is a **presentation slice only**: the card displays the file's stored `permission`
entries and must not compute the effective Opencode policy (last-match-wins precedence,
per-agent overrides, auto mode) or write an Opencode file.

## Primary source

Opencode's permissions reference reviewed 2026-09-08
(<https://opencode.ai/docs/permissions/>) documents the `permission` config, the three
actions, the granular object syntax, and the available tools. Retain the review date in
`docs/supported-tools.md`.

The `permission` value in `opencode.json` is one of:

- **a scalar action string** — `"allow"`/`"ask"`/`"deny"`, applying to all tools
  (`"permission": "allow"`), or
- **an object** mapping a tool name (or `*`) to either a scalar action string
  (`"bash": "allow"`) or a **granular rule map** of `pattern → action`
  (`"bash": { "*": "ask", "git *": "allow", "rm *": "deny" }`).

Actions are exactly `allow`, `ask`, `deny`. Known tools: `read`, `edit`, `glob`,
`grep`, `bash`, `task`, `skill`, `lsp`, `question`, `webfetch`, `websearch`,
`external_directory`, `doom_loop`. Wildcards are `*` (zero+ chars) and `?` (one char).
`~`/`$HOME` may start a pattern. Per-agent overrides exist (`agent.<name>.permission`)
but are out of scope for this card.

## Scope

### In scope

- A pure-Dart `OpencodePermissionsAdapter` implementing `PolicyCardAdapter`, with an
  `OpencodePermissionsPresentation` and reviewed, plain-language help.
- A read-only `OpencodePermissionsCard` widget and its registration in
  `PolicyCardWidgetRegistry.shared`; registration of the adapter in
  `PolicyCardRegistry.shared`.
- Fixtures and tests: adapter, registry selection, widget mapping, card, fallback,
  help/link failure, and a read-only/no-byte-mutation assertion.
- Docs and docstring follow-through (see [Docs, docstrings, and metadata](#docs-docstrings-and-metadata)).

### Out of scope

- Any write, patch, or serialization path. No save control.
- Computing the effective Opencode policy (last-match-wins, `--auto` mode,
  per-agent overrides, external-directory inheritance, defaults).
- Other Opencode config (`model`, `instructions`, `mcp`, `plugin`, `agent`),
  rules/skills/agents markdown, or the `~/.config/opencode/auth.json`.
- The **deprecated legacy `tools` boolean key** (documented as merged into `permission`
  as of Opencode v1.1.1). It is out of scope: an Opencode config that uses only `tools`
  (with no `permission`) renders the empty state, and the plan does not translate the
  legacy key. A follow-up may add it.
- Any change to the generic flat editors, `FidelityAssessor`, `StructuredSaveFlow`,
  or `ConfigEditor` structure.

## Current-state baseline (as of plan start)

- `lib/schemas/policy_card_registry.dart` — `shared` seeds `ClaudeCodePermissionsAdapter`
  then `CursorPermissionsAdapter`. `select` returns the first non-`notApplicable`
  selection or the `noAdapterId` sentinel.
- `lib/widgets/policy_card_widget_registry.dart` — `shared` maps the Claude and Cursor
  adapter ids to their card builders; `buildCard` returns `null` for unknown/non-available/
  null-presentation.
- `lib/schemas/policy_card.dart` — the `PolicyCardAdapter` interface and
  `PolicyCardSelection`/`PolicyCardStatus`/`PolicyCardPresentation`.
- `lib/widgets/config_editor.dart` — resolves `_registry.select` then
  `_widgetRegistry.buildCard`, with generic flat/nested fallbacks. No Opencode branch.
- `lib/catalog/tool_descriptor_registry.dart` — `ToolId.opencode` declares two structured
  targets, both `ConfigFormat.jsonc`: `.config/opencode/opencode.json` (user) and
  `.opencode/opencode.json` (project), plus an `AGENTS.md` instruction target.
- `lib/parsers/json_config_parser.dart` — `ToolConfig.rawSettings` is the decoded
  top-level object; `parsedAsJsonc` marks a JSONC fallback. Opencode config is JSON and
  supports JSONC; the fidelity notice labels by parsed content.
- `test/fixtures/staging_home/.config/opencode/opencode.json` — `model` + a small
  `permission` (`read`/`edit` with `*` rules). Today a catalog-discovered Opencode
  `opencode.json` renders only the generic flat editor (it has no `permissions` list
  key), which this card replaces.

## Target design

### Adapter (`lib/schemas/opencode_permissions.dart`, pure Dart)

```dart
class OpencodePermissionsAdapter implements PolicyCardAdapter {
  static const adapterId = 'opencode.permissions';   // static + instance id, as Claude/Cursor
  static final Uri documentationUri =
      Uri.parse('https://opencode.ai/docs/permissions/');
}
```

`interpret` reads the top-level `permission` value from `config.rawSettings` (the
decoded `opencode.json`). It returns:

- **`notApplicable`** — when the config is not a catalog-discovered `ToolId.opencode`
  structured target. Target check (`_isOpencodeTarget`):
  `discoveredConfig != null && fromCatalog &&
  discoveredConfig.descriptor?.id == ToolId.opencode &&
  kind == ConfigSourceKind.structuredConfig &&
  discoveredConfig.format == ConfigFormat.jsonc &&
  config.format == ConfigFormat.jsonc &&
  scope in {user, project} && p.basename(filePath) == 'opencode.json'`.
  Both Opencode structured targets are declared `ConfigFormat.jsonc`
  (`tool_descriptor_registry.dart:90,96`), and `ConfigService.loadDiscoveredConfig`
  passes that catalog format into the parser (`config_service.dart:73-78`), so the
  parsed `config.format` is `jsonc` too — **both sides must be `jsonc`**. Do not use
  `ConfigFormat.json` here: the parser's extension-based JSON default
  (`json_config_parser.dart:40-42`) only applies when `format` is omitted, and
  production always supplies the discovered format. Tests that hand-build a
  `ToolConfig` must set `format: ConfigFormat.jsonc` to mirror production (a `json`
  ToolConfig would pass a synthetic test but fail the real load path). The basename
  guard is defensive (both structured targets are named `opencode.json`; the parent
  directory varies — `~/.config/opencode/` and `.opencode/` — so a parent check like
  Cursor's is not possible). It prevents a future catalog addition of a different
  Opencode structured file from being mis-identified.
- **`available`** — a valid `permission`. When the key is **absent**, present an empty
  presentation with `hasConfiguredPermission: false` (like Claude's `hasConfiguredPolicy`
  for "no permissions subtree"); the card shows a safe empty state. When the key is
  **present but empty** (`permission: {}`), present `hasConfiguredPermission: true` with
  empty `tools` and no `globalAction` (analogous to Cursor's explicit-`[]` vs omitted
  distinction: a present-but-empty `permission` is a configured empty policy).
  - `permission` is a **scalar action string** → `globalAction = <action>` (validated as
    `allow`/`ask`/`deny`).
  - `permission` is an **object** → for each entry, a non-`String` key is unsupported
    (unrepresentable via typed `rawSettings`, kept defensively for direct-construction
    tests). A `*` key must be a scalar action string and sets `globalAction`. A tool key's
    value must be either a **scalar action string** (simple) or a **granular rule map** of
    `pattern → action` (each key a `String`, each value a valid action). Everything is
    displayed as stored; there is no "unclassified sibling" concept within `permission`
    because every entry is a tool or `*`.
- **`unsupported`** (raw-editor-first) — when a present recognized shape is malformed:
  a `permission` value that is neither a valid action string nor an object (including a
  JSON `null` and a non-string/number/bool); a `*` key whose value is not a scalar
  action string; a tool value that is neither a valid action string nor a map whose
  values are all valid actions (a non-`String` pattern key, a non-action value, or a
  value that is not a string/map). Each unsupported case returns a stable
  `unsupportedReason`, e.g. `'Opencode permission "<field>" is not a supported value. '
  'Use the raw editor to review it.'` for a malformed field and
  `'This Opencode permission shape is not supported for structured display. Use the '
  'raw editor to review it.'` for a whole-`permission` shape that is neither action nor
  object — mirroring the Claude/Cursor reason patterns.
`OpencodePermissionsPresentation extends PolicyCardPresentation` (Equatable):
`globalAction` (`String?`), `tools` (an ordered `Map<String, OpencodeToolPermission>`),
and `hasConfiguredPermission` (`bool`). `OpencodeToolPermission` (Equatable, props
`[action, patterns]`) holds a simple `action` (`String?`) **or** `patterns`
(`Map<String,String>?`); exactly one is set per stored tool. All maps are unmodifiable.
`rawSettings` values are typed `Map<String, Object?>` (`tool_config.dart:60`), so when
building `patterns` the adapter must validate each pattern value with an `is! String`
check and copy directly into a `Map<String, String>` (e.g. `Map<String, String>.from(
entries)`). **Never cast the `Map<String, Object?>` instance to `Map<String, String>`**:
Dart generic map types are invariant, so an `as Map<String, String>` cast throws at
runtime even when every value has been validated as a `String`. A non-`String` value is
unsupported, never silently coerced. This mirrors how Claude/Cursor presentations
preserve exactly what is stored.

`OpencodePermissionsHelp` — reviewed, plain-language `label` + `description` per
group, modeled on the existing help classes. The card-level statement and each
group's description must say the card shows **this file's stored `permission` entries,
not Opencode's effective policy** (which resolves last-match-wins, applies per-agent
overrides and `--auto`, and inherits defaults). It must not claim the app can predict
whether a future action will run without approval. Exact strings (draft, finalized at
implementation):

- `policy`: label `'Opencode permissions'`; description `'This card shows the allow, '
  'ask, and deny rules stored in the permission block of this opencode.json file. '
  'Opencode resolves those rules at runtime (last match wins, with per-agent overrides '
  'and auto mode); this card does not compute that effective policy.'`
- `global`: label `'Global'`; description `'An action applied to every tool when the '
  'permission block is a single value or a * rule. Stored here; Opencode applies it at '
  'runtime.'`
- per-tool `toolPermission(String toolName)`: returns a `CursorPermissionFieldHelp`
  whose label is the tool name (e.g. `'bash'`) and whose description is
  `'The action or rules stored for this tool in this file. Opencode applies them at '
  'runtime; for granular pattern rules, the last matching rule wins.'` — distinguishing
  a scalar action from a granular rule map (the "last matching rule wins" statement
  applies only to granular rules). A single-argument factory, not a two-argument one.

All help lives in the pure-Dart schema layer. The adapter tests must assert these exact
help strings (mirroring `cursor_permissions_test.dart:49-76`).

### Card widget (`lib/widgets/opencode_permissions_card.dart`)

A read-only `StatelessWidget` mirroring `CursorPermissionsCard`: header with
`Icons.policy_outlined` and "Opencode permissions", the card-level help statement, a
"Global" group showing `globalAction` (when present, e.g. "allow"), a per-tool group
showing either its simple action or its bulleted `pattern → action` rules, a
hasUnclassified-free layout (no note needed — everything in `permission` is shown), and
a documentation launcher labeled **"Opencode permissions documentation"** →
`documentationUri` with the same `onOpenDocumentation`/mounted-guarded SnackBar pattern.
No editing controls, no write path. When `hasConfiguredPermission` is false, show a
safe empty state: **"No Opencode permissions policy is configured. Legacy `tools`
settings are not shown. Use raw content to add a `permission` block."** — this exact
string is the one the card-widget test asserts (via `find.textContaining`, mirroring
`claude_code_permissions_card_test.dart`).

### Registrations

- `PolicyCardRegistry.shared` → add `OpencodePermissionsAdapter()` (after Cursor; the
  three adapters gate on disjoint descriptor ids, so order is not behavior-critical).
- `PolicyCardWidgetRegistry.shared` → add
  `OpencodePermissionsAdapter.adapterId: _buildOpencodeCard`; the builder type-checks
  (`is!`) and returns `OpencodePermissionsCard(...)` with the default launcher.

### ConfigEditor

**No changes.** `build` already renders whatever `buildCard(selection)` returns: it
resolves `_registry.select(...)` (~`config_editor.dart:411-414`) and renders
`_widgetRegistry.buildCard(selection)`; the nested-permissions fallback
(`:416-419`) keys on the **plural** `permissions`, which Opencode's singular
`permission` does not collide with. The whole slice reduces to "register an adapter +
a card builder" — the proven Phase 0/4A seam. `lib/widgets/config_editor.dart` is at
the 700-line cap, so this is also load-bearing for the file-length gate.

## Test strategy

Follow the Claude/Cursor vertical-slice test layout.

### Adapter unit tests (`test/schemas/opencode_permissions_test.dart`)

- `notApplicable` for: a manual-path Opencode config, a non-Opencode tool, `null`
  discovery, a non-`opencode.json` basename with the same descriptor/kind/format/scope,
  and another format/kind. The `available` tests must build `ToolConfig` with
  `format: ConfigFormat.jsonc` (matching `loadDiscoveredConfig`) so the target guard
  passes exactly as in production.
- `available` for user-scope and project-scope catalog targets; a scalar `permission`
  string sets `globalAction`; an object with `*` sets `globalAction`; a tool with a
  scalar action vs one with a granular pattern map are preserved distinctly; an absent
  `permission` yields `hasConfiguredPermission: false`; a present empty object `{}`
  yields `hasConfiguredPermission: true` with empty `tools` and no `globalAction`.
- `unsupported` for: a `permission` that is neither an action string nor an object
  (including `permission: null`); a `*` value that is not a scalar action; a tool value
  that is not a valid action and not a map whose values are all valid actions
  (including a pattern map with a non-action value, and a directly-constructed
  non-`String` pattern key). Assert the stable `unsupportedReason` string.
- Registry selection: with Claude + Cursor + Opencode registered, an Opencode config
  resolves to the Opencode adapter and the other two remain `notApplicable` (no
  cross-match, both directions). Add these 3-adapter cross-match tests to
  `test/schemas/policy_card_registry_test.dart` (parallel to the Cursor ones added for
  Phase 4A), not only in the adapter test file.

### Fixtures (`test/fixtures/opencode_permissions_fixtures_test.dart`)

On-disk, token-free fixtures under `test/fixtures/edge_cases/opencode_permission_*.json`
(mirroring the Cursor fixture layout; no need to touch `staging_home`), covering: a
global scalar (`"permission": "allow"`); an object with `*` + a scalar tool + a
granular tool; malformed (non-action value, non-string pattern key is direct-construction
only, a `permission` value that is neither action nor object, and `permission: null`);
and an absent `permission`. Plus **one JSONC fixture**,
`test/fixtures/edge_cases/opencode_permission_comments.jsonc`, with a comment and a
trailing comma. Assert parsing, presentation, and that opening does not change bytes
(the no-save/no-byte assertion lives in the ConfigEditor integration test, not
duplicated here). Mirror Cursor's JSONC assertions
(`cursor_permissions_fixtures_test.dart:85-103,159-172`): the JSONC fixture parses with
`parsedAsJsonc == true` and `parseWarnings` non-empty, and a `FidelityAssessor`
`assessOpening` on it labels the notice `JSONC`.

### Widget mapping (`test/widgets/policy_card_widget_registry_test.dart`)

- `OpencodePermissionsAdapter.adapterId` maps to the Opencode card.
- `buildCard` returns `null` (no crash) for an unknown id / non-available / null
  presentation / wrong-type presentation passed to the Opencode builder.

### Card widget (`test/widgets/opencode_permissions_card_test.dart`)

- Renders the global action and each tool group (simple action vs granular rules);
  for the empty state asserts `find.textContaining('No Opencode permissions policy is '
  'configured. Legacy tools settings are not shown.')` (matching the card's exact
  revised string, via `textContaining` like Claude).
- Help dialog opens per group; documentation-launcher failure shows the SnackBar
  (inject a failing `onOpenDocumentation`).

### ConfigEditor integration (`test/widgets/config_editor_policy_card_test.dart`)

- A catalog-discovered Opencode `opencode.json` (built with `format: ConfigFormat.jsonc`
  on both the `DiscoveredConfig` and the `ToolConfig`, mirroring production) renders the
  Opencode card (not the flat editor, not the nested-permissions text).
- A malformed `permission` renders the unsupported-reason text and no card.
- An Opencode card is **read-only**: interacting (help/docs) never triggers a save —
  assert `onSave` is **not** invoked (a save-counter stays `0`). Because the harness
  builds the `ToolConfig` directly (no on-disk file is involved), it cannot snapshot and
  compare file bytes; the meaningful assertion is that no save/edit path runs. Do not
  rely on comparing `ToolConfig.originalContent`, which is a final field and cannot
  change.
- The existing no-adapter nested-fallback test (`ToolId.lmStudio`) stays green — the
  Opencode adapter must not swallow generic tools.

### JSONC fidelity (no new code)

Opencode config supports JSONC; a `.json` file parsed via the JSONC fallback already
gets a JSONC-labeled notice from the existing `FidelityAssessor._jsonLabel` (labels by
`parsedAsJsonc`, not the filename). The `test/fixtures/edge_cases/opencode_permission_comments.jsonc`
fixture (with a comment and a trailing comma) exercises this: assert `parsedAsJsonc ==
true`, `parseWarnings` non-empty, and a `FidelityAssessor.assessOpening` label of
`JSONC`. No new notice code.

## Docs, docstrings, and metadata

The Opencode card is **user-visible**, so this slice updates user-facing docs.

- `docs/supported-tools.md`:
  - Opencode evidence row (~line 56): change the "Schema evidence" cell from
    `verified example (fixture exercises \`model\` + \`permission\` object shape; full JSON schema published)`
    to `verified example (fixture exercises \`model\` + \`permission\` object shape; read-only card)`;
    update the source-review date to 2026-09-08.
  - Opencode Permissions section (~line 236): add this bullet under "Opencode
    Permissions":
    `- **Read-only card:** The app renders the \`permission\` block of a discovered \`opencode.json\` as a read-only policy card showing the file's stored entries; it does not compute Opencode's effective policy.`
- `CHANGELOG.md`: add a user-facing entry for the read-only Opencode permissions card.
- `plans/active/structured-configuration-roadmap.md`: mark the Phase 4 progression item 1
  (Opencode) done; note the shared-interface box stays done (it is not undone by adding
  a third consumer).
- `TO_DO.md`: keep the "Structured configuration presentation" entry open; note the
  Opencode card shipped and reference the archived plan after archival.
- **Docstrings:** every new public member in `opencode_permissions.dart`,
  `opencode_permissions_card.dart`, and the registry additions gets a doc comment
  following the existing convention.

## Resolved open questions

1. **`permission` as a scalar string vs an object.** Both are valid and must be shown:
   the adapter sets `globalAction` from a scalar `permission` or a `*` key, and shows
   per-tool actions/rules otherwise. A scalar `permission: "allow"` is a common global
   config, so the card shows a "Global: allow" row rather than treating it as unsupported.
2. **Per-agent overrides.** `agent.<name>.permission` is documented but out of scope:
   the card reads only the top-level `permission`, and its help states it shows stored
   top-level entries, not the merged per-agent effective config.
3. **Which tools to show.** Every stored tool entry is shown as-is (the card is a
   "show stored entries" view, so it does not filter to a known tool allowlist or hide
   unknown tool names).
4. **Effective-policy caveats.** The card must not encode last-match-wins, `--auto`,
   defaults, or external-directory inheritance as product truth; its help states it
   shows stored entries and that Opencode resolves them at runtime.
5. **Project-root `opencode.json` is not catalog-registered.** The catalog registers
   only `.config/opencode/opencode.json` (user) and `.opencode/opencode.json` (project);
   a plain project-root `opencode.json` (listed in `docs/supported-tools.md`) is **not**
   a registered discovery target, so it will not render the card. Reconcile the
   `docs/supported-tools.md` path table with the catalog (add the root target, or remove
   it from the docs) as a catalog-integrity follow-up, out of scope for this card slice.

## Implementation steps

1. Add `lib/schemas/opencode_permissions.dart` (adapter + presentation + help, pure
   Dart, docstrings). `OpencodePermissionsAdapter.adapterId = 'opencode.permissions'`
   with `String get id => adapterId;`. Import `package:path/path.dart` as `p` for the
   `p.basename` target guard (mirroring `cursor_permissions.dart`).
2. Add `lib/widgets/opencode_permissions_card.dart` (read-only card, default doc
   launcher, help dialog, no write path).
3. Register the adapter in `PolicyCardRegistry.shared` and the card builder in
   `PolicyCardWidgetRegistry.shared`. Confirm `ConfigEditor` needs **no** changes.
4. Add the fixtures and tests from [Test strategy](#test-strategy).
5. Update the docs, `CHANGELOG.md`, roadmap, and `TO_DO.md` from
   [Docs, docstrings, and metadata](#docs-docstrings-and-metadata).
6. Run the gates; then review the branch, fix findings, and archive this plan as the
   final commit before merge (per AGENTS.md — never a direct-to-main post-merge step).

## Acceptance criteria

- A catalog-discovered Opencode `opencode.json` (user or project) renders a read-only
  card showing the stored `permission`: a global action when a scalar `permission` or
  `*` is present, and each tool's simple action or granular `pattern → action` rules.
- Manual paths, other tools, and non-`opencode.json` targets are unaffected; the
  generic flat/nested fallbacks are preserved.
- A malformed `permission` (neither action string nor object; a tool value that is
  neither a valid action nor a valid pattern map; a `*` that is not a scalar action) is
  an unsupported subtree → raw-editor-first.
- An absent `permission` renders a safe empty state.
- The card states it shows stored entries, not the effective policy.
- `ConfigEditor` is unchanged (no new tool branches).
- No interaction with the card saves or changes bytes.
- Gates green: `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze --fatal-infos`, `flutter test`, and
  `python3 ci/scripts/check_doc_links.py --internal-only --catalog-strict`.

## Completion steps

Per AGENTS.md, archive this plan as the last step before merging (final commit on this
feature branch, riding in the PR; never a direct-to-main post-merge step):

1. Record the seam in the parent roadmap (mark the Phase 4 progression item 1, Opencode,
   done).
2. Keep the `TO_DO.md` "Structured configuration presentation" entry open and aligned.
3. Log the change in `CHANGELOG.md` (user-visible card) and `CHANGELOG.dev.md` if any
   developer-only note is warranted.
4. Move this file to `plans/archive/` as the final commit on the branch.

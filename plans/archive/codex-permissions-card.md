# Plan: Codex Permissions Card (roadmap Phase 4, item 2, read-only)

Last reviewed: 2026-09-10
Date: 2026-09-10
Author: maintainers
Status: complete — implemented on the `impl/codex-permissions-card` branch (2026-09-10) and archived
Linked parent: [Structured Configuration Roadmap](../active/structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Outcome

Shipped on the `impl/codex-permissions-card` branch. A pure-Dart
`CodexPermissionsAdapter` + `CodexPermissionsPresentation` + reviewed help implement
`PolicyCardAdapter` for legacy `sandbox_mode`/`approval_policy` keys, the
`default_permissions` selection, and named `[permissions.*]` profiles (filesystem
rules with scoped subpaths, network policy subset, workspace roots, extends
displayed-not-resolved); a read-only `CodexPermissionsCard` widget mirrors the
Cursor/Opencode cards. All three register in the shared
`PolicyCardRegistry`/`PolicyCardWidgetRegistry`, plus two bounded tool-agnostic
companions: the card renders under the default TOML opt-out without exposing edit
controls, non-list `rules` shows a nested notice instead of the Rules editor, and
the TOML serializer preserves non-list `rules`/`permissions` tables instead of
silently deleting them (diff-review + fidelity notice unchanged). The adapter guards
the catalog path (toml on both sides, basename `config.toml` with a `.codex`
parent dir — profile files, system config, near-misses, and sibling targets
excluded), keeps unknown keys visible, and returns unsupported (raw-editor-first)
for malformed shapes. On-disk fixtures under `test/fixtures/edge_cases` exercise
legacy/profile/malformed/empty states including the quoted dotted-key decode path;
the full suite is green (478 tests, +41 from the 437 baseline). Docs:
`docs/supported-tools.md` (evidence + read-only bullet, re-checked 2026-09-10),
user-facing `CHANGELOG.md` entry, `CHANGELOG.dev.md` entry, roadmap Phase 4
progression item 2 done with item 4 (Codex editing) still gated, and the `TO_DO.md`
note updated. The primary Codex references were reviewed 2026-09-10.

## Objective

Add a read-only policy card for the Codex TOML permission configuration (a
catalog-discovered `.codex/config.toml`), as the next non-Claude consumer of the
shared policy-card registry after Cursor (Phase 4A) and Opencode (Phase 4 item 1).
Codex is the roadmap's Phase 4 "expand one schema at a time" progression item 2.
A new `CodexPermissionsAdapter` + `CodexPermissionsCard` register in the shared
registries, plus one tool-agnostic `ConfigEditor` change (see [ConfigEditor
presentation decoupling](#configeditor-presentation-decoupling)): no card has
covered a TOML-backed tool before, and today the TOML structured-save opt-out hides the whole
structured block including policy cards. The read-only card must render under
the default opt-out without enabling any write capability.

It is a **presentation slice only**: the card displays the file's stored permission
entries and must not compute the effective Codex policy (config-layer merging,
`extends` inheritance, runtime workspace roots, the sandbox-vs-profiles
precedence) or write a Codex file. **No TOML write capability is added.**
One bounded serializer preservation fix (see [TOML serializer preservation
fix](#toml-serializer-preservation-fix)) stops the pre-existing silent deletion
of map-shaped tables on structured save; it enables no new editing. The
roadmap's AST-preserving TOML edit strategy still gates Codex *structured
editing* (a later item); it does not gate this read-only card, which needs no
serialization path. The existing `FidelityAssessor` TOML notice keeps describing
the lossy structured-save behavior for the raw/generic editors; this slice does
not touch it.

## Primary source

Codex's config and permissions references reviewed 2026-09-10
(<https://developers.openai.com/codex/config-basic>,
<https://developers.openai.com/codex/permissions>) document the config layers,
the legacy sandbox keys, and the named permission profiles (beta, may change).
Retain the review date in `docs/supported-tools.md`.

Config layers, highest precedence first: CLI flags/`--config` overrides, project
`.codex/config.toml` files (root down to CWD, trusted projects only), profile
files (`~/.codex/<profile>.config.toml` via `--profile`), user
`~/.codex/config.toml`, cloud-managed defaults, system `/etc/codex/config.toml`,
built-in defaults. Only the user and project `.codex/config.toml` layers are
catalog discovery targets in this app; profile files and the system config are
not registered and must never render the card.

The permission-relevant stored keys are:

- **Legacy keys (top level):** `sandbox_mode` (`read-only`, `workspace-write`,
  `danger-full-access`) and `approval_policy` (`on-request`, `never`;
  `untrusted` is retired and migrates to the newer policies).
- **`default_permissions`** (top-level string): selects one profile by name — a
  custom `[permissions.<name>]` table or a built-in (`:read-only`, `:workspace`,
  `:danger-full-access`).
- **`[permissions.<name>]` tables**, each with:
  - `description` (string, not inherited through `extends`),
  - `extends` (string parent: a built-in `:read-only`/`:workspace` or another
    named profile; Codex rejects `:danger-full-access`, unknown parents, and
    inheritance cycles),
  - `[permissions.<name>.workspace_roots]` (path → boolean; `true` enables the
    root),
  - `[permissions.<name>.filesystem]` (path → `read`/`write`/`deny`, plus scoped
    subpath maps and `glob_scan_max_depth`; special roots `:root`, `:minimal`,
    `:workspace_roots`, `:tmpdir`, `:slash_tmp`; absolute and `~/` paths; more
    specific entries win ties, `deny` wins equal-specificity ties),
  - `[permissions.<name>.network]` (`enabled` boolean; `domains` host →
    `allow`/`deny` with `*`/`**.` wildcards, deny wins; `unix_sockets` path →
    `allow`/`deny`; `allow_local_binding`; proxy listener/transport keys
    (`proxy_url`, `enable_socks5`, `socks_url`, `enable_socks5_udp`,
    `allow_upstream_proxy`) and `dangerously_*` operational keys, all left to
    the raw editor).
- **Precedence rules the card must not evaluate:** profiles do not compose with
  the older sandbox settings — if `sandbox_mode` appears in any loaded layer,
  Codex uses the older sandbox settings instead of `default_permissions`
  (managed `allowed_permission_profiles` excepted); `network.enabled = true`
  without an active proxy means unrestricted direct access (domain rules
  unenforced); narrower deny rules stay in force inside broader grants.

## Scope

### In scope

- A pure-Dart `CodexPermissionsAdapter` implementing `PolicyCardAdapter`, with a
  `CodexPermissionsPresentation` and reviewed, plain-language help.
- A read-only `CodexPermissionsCard` widget and its registration in
  `PolicyCardWidgetRegistry.shared`; registration of the adapter in
  `PolicyCardRegistry.shared`.
- Two bounded, tool-agnostic safety companions: the `ConfigEditor`
  presentation decoupling plus non-list rules notice, and the
  `TomlConfigParser` preservation rule (neither adds a write capability).
- Fixtures and tests: adapter, registry selection, widget mapping, card,
  fallback, help/link failure, a read-only/no-byte-mutation assertion, parser
  preservation, and opt-in save-path coverage.
- An exploratory research spike (recorded below) verifying the TOML decoded-map
  shapes before the adapter is written.
- Docs and docstring follow-through (see [Docs, docstrings, and metadata](#docs-docstrings-and-metadata)).

### Out of scope

- Any new write capability, patch path, or save control. No save control is
  added; `FidelityAssessor`, `StructuredSaveFlow`, and the generic TOML editor
  are untouched, and `TomlConfigParser` gains only the bounded preservation
  rule in [TOML serializer preservation
  fix](#toml-serializer-preservation-fix). Codex structured editing remains a
  later roadmap item gated on an AST-preserving TOML strategy.
- Computing the effective Codex policy: layer merging across user/project/profile
  files, `extends` inheritance resolution, runtime workspace-root expansion, the
  sandbox-vs-profiles precedence decision, and proxy-active network enforcement.
- Other Codex config (`model`, `features`, `tui`, `shell_environment_policy`,
  `windows`, `mcp`, `hooks`, `log_dir`), rules (`.rules`), `AGENTS.md`
  instruction documents, and managed `requirements.toml`.
- Profile files (`~/.codex/<profile>.config.toml`) and the system config: not
  cataloged, never card-eligible.
- The legacy `[sandbox_workspace_write]` table is out of card scope: a file with
  only that table (no `sandbox_mode`, `approval_policy`, `default_permissions`,
  or `[permissions]`) renders the empty state. When the table co-exists with
  displayed keys, the card shows a static "legacy table present but not shown —
  see the raw editor" note (presence detected via `rawSettings.containsKey`,
  contents never parsed).
- The pre-existing structured-save data-loss hazard: a map-shaped `permissions`
  (or `rules`) table decodes to `extractStringList → []`, so an opt-in
  structured TOML save today strips the whole table from its output
  (`toml_config_parser.dart:87-98`). The `FidelityAssessor` TOML notice does
  **not** warn about this — it covers comments/formatting loss only
  (`fidelity_assessor.dart:60-64`); the deletion surfaces in the save-review
  diff but is never announced. This slice fixes the root cause with the bounded
  preservation rule in [TOML serializer preservation
  fix](#toml-serializer-preservation-fix) and must not widen structured-save
  behavior in any other way.
- Any change to `FidelityAssessor` or `StructuredSaveFlow`. Three bounded,
  tool-agnostic exceptions, none adding a write capability or per-tool branch:
  the `ConfigEditor` presentation decoupling, the `ConfigEditor` non-list
  rules notice, and the `TomlConfigParser` preservation rule, all described
  below.

## Current-state baseline (as of plan start)

- `lib/schemas/policy_card_registry.dart` — `shared` seeds
  `ClaudeCodePermissionsAdapter`, `CursorPermissionsAdapter`, then
  `OpencodePermissionsAdapter`. `select` returns the first non-`notApplicable`
  selection or the `noAdapterId` sentinel.
- `lib/widgets/policy_card_widget_registry.dart` — `shared` maps the Claude,
  Cursor, and Opencode adapter ids to their card builders; `buildCard` returns
  `null` for unknown/non-available/null-presentation.
- `lib/schemas/policy_card.dart` — the `PolicyCardAdapter` interface and
  `PolicyCardSelection`/`PolicyCardStatus`/`PolicyCardPresentation`.
- `lib/widgets/config_editor.dart` — resolves `_registry.select` then
  `_widgetRegistry.buildCard`, with generic flat/nested fallbacks. No Codex branch.
- `lib/catalog/tool_descriptor_registry.dart` — `ToolId.codex` declares two
  structured targets, both `ConfigFormat.toml`: `.codex/config.toml` (user) and
  `.codex/config.toml` (project), plus `.rules`/`AGENTS.md` instruction targets.
- `lib/parsers/toml_config_parser.dart` — `parse` decodes via `TomlDocument`
  and exposes the document as `ToolConfig.rawSettings` (`doc.toMap()`); nested
  TOML tables arrive as nested maps. Syntax errors throw `ConfigParseException`
  before any adapter runs, so the adapter only sees decoded maps.
- `test/fixtures/staging_home/.codex/config.toml` (legacy `model` +
  `approval_policy` + `sandbox_mode` + `[sandbox_workspace_write]`) and
  `test/fixtures/staging_home/workspace/.codex/config.toml` (legacy `model` +
  `approval_policy`) exercise the legacy shape only; no fixture uses
  `[permissions.*]`. Today a catalog-discovered Codex `config.toml` renders the
  generic TOML editor, which this card replaces for permission-bearing files.

## Target design

### Adapter (`lib/schemas/codex_permissions.dart`, pure Dart)

`CodexPermissionsAdapter.adapterId = 'codex.permissions'` with
`String get id => adapterId;` (static/instance names must differ). The target
guard follows the Cursor pattern (basename + parent-dir — stricter than
Opencode's basename-only check): `ToolId.codex` + `structuredConfig` +
`ConfigFormat.toml` on both `discoveredConfig.format` and `config.format` (both
sides carry the catalog format via `loadDiscoveredConfig`), user/project scope,
plus `p.basename(discoveredConfig.filePath) == 'config.toml'` with
`p.basename(p.dirname(discoveredConfig.filePath)) == '.codex'`. Path identity
comes from the normalized discovery metadata (`discoveredConfig.filePath`,
normalized in `DiscoveredConfig.fromPath`), never the un-normalized
`config.filePath`. The basename check excludes profile files
(`<profile>.config.toml`) by construction; the parent-dir check excludes the
system config (`/etc/codex/…`, whose parent is `codex`) and near-misses
(`workspace.codex/…`); the catalog-discovered check excludes manual paths.
Adapter invariant: once this guard passes, `interpret` returns `available` or
`unsupported`, never `notApplicable` — `select` returns the first
non-`notApplicable` selection (`policy_card_registry.dart:43-48`), so a stray
`notApplicable` would hide the card even for valid files under opt-out.

The presentation model:

- `sandboxMode` / `approvalPolicy`: top-level strings when present (`null` when
  omitted — the card distinguishes "Not set." from a stored value, including a
  stored retired `untrusted` policy, which help annotates with the migration
  link rather than translating). A present `[sandbox_workspace_write]` table
  adds the static legacy-table note from Scope (presence only, never parsed).
- `defaultPermissions`: top-level string when present. When it names a profile
  with no table in this file (a built-in, or possibly defined in another layer
  — or an unknown value Codex itself would reject), the card
  shows the selection plus a "not defined in this file" note — it never
  resolves across files.
- `profiles`: one entry per `[permissions.<name>]` table with `description`,
  `extends` (stored value only, never resolved; unknown-parent and cycle
  rejection are Codex runtime behavior, not card behavior), `workspaceRoots`
  (path → bool map shown as-is), `filesystem` rules (path → access plus scoped
  subpath maps and `glob_scan_max_depth`), and the policy-relevant `network`
  subset (`enabled`, `domains`, `unix_sockets`, `allow_local_binding`). Proxy
  listener/transport keys (`proxy_url`, `enable_socks5`, `socks_url`,
  `enable_socks5_udp`, `allow_upstream_proxy`) and `dangerously_*` operational
  keys are left to the raw editor (see unclassified rule below). The network
  section carries a static, non-evaluative help line that domain rules are
  enforced only when the network proxy is active (see `features.network_proxy`
  or managed requirements) — the card never evaluates enforcement.
- Unrecognized keys — at top level or inside a profile table — do not suppress
  an otherwise valid card; they stay visible in raw content. A present
  recognized value with the wrong type (for example `sandbox_mode` as a table,
  `permissions` as a string, a filesystem access that is not
  `read`/`write`/`deny`, `network.enabled` as a string, a workspace-root value
  that is not boolean) is an unsupported subtree → the adapter declines and the
  raw editor leads. An absent permission block (no legacy keys, no
`default_permissions`, no `[permissions]`) renders a safe empty state ("No
permission settings stored in this file."), not an error. A present-but-empty
`[permissions]` table (no profile children) renders the same empty state.
- When `sandbox_mode` coexists with `[permissions]` in the stored file, the card
  shows both stored halves plus a help note that Codex prefers the older sandbox
  settings when `sandbox_mode` appears in any loaded layer (with the doc link);
  the card does not decide which system is effective.
- Help strings are reviewed, plain-language, and link to the owning primary
  reference (`config-basic`, `permissions`, `agent-approvals-security`); unknown
  settings stay visibly unclassified rather than explained.

### Card widget (`lib/widgets/codex_permissions_card.dart`)

A read-only card mirroring the Cursor/Opencode cards: legacy sandbox/approval
rows, the `default_permissions` selection row, one section per stored profile
(filesystem rules, network rules, workspace roots, description/extends), the
empty state, the stored-entries-not-effective-policy notice, default doc
launcher, and help dialog. No write path, no save control, no editable inputs.

### Registrations

Register the adapter in `PolicyCardRegistry.shared` (after Opencode) and the
card builder in `PolicyCardWidgetRegistry.shared`, plus the tool-agnostic
`ConfigEditor` presentation decoupling from [ConfigEditor](#configeditor) so
the card renders under the default TOML opt-out (same no-per-tool-branches
rule as stated in Scope).

### ConfigEditor

One tool-agnostic change (see [ConfigEditor presentation
decoupling](#configeditor-presentation-decoupling) below). No per-tool
branches; the card still renders through the existing select/buildCard seam,
and the generic TOML editor, fidelity notice, and opt-in banner keep working
as today.

### ConfigEditor presentation decoupling

Today `_supportsStructuredFields` (`config_editor.dart:170-178`) returns the
TOML opt-in flag, so with the default opt-out the whole structured block —
Rules editor and `_buildPermissionsSection` (the card host, `:587-591`) — is
skipped. A read-only card gated behind a lossy-write opt-in is unreachable by
default, which defeats this slice. The fix decouples *presentation* from the
*write* gate, without touching what the opt-in protects:

- The Rules `StringListEditor` gate is untouched: it renders only under
  `_supportsStructuredFields && !rawOnly`, exactly as today.
- The `_buildPermissionsSection` call site gets one exact widened condition:
  render iff `!rawOnly && (_supportsStructuredFields || card != null)`, where
  `card` is the already-built card for the current selection. Concretely, split
  the single outer gate: keep the Rules editor under
  `if (_supportsStructuredFields && !widget.rawOnly)`, and call
  `_buildPermissionsSection` under `if (!widget.rawOnly &&
  (_supportsStructuredFields || card != null))`. The section
  internals are not restructured: when the card is available only the card
  branch shows, and the `:270-294` flat-editor/notice branches keep no
  independent opt-in check — so they must never be hoisted outside the gate on
  their own. Card-absent TOML files (manual paths, non-permission files) render
  exactly as today (banner + raw editor). A manual-path TOML regression test
  under opt-out pins `findsNothing` `StringListEditor`. A malformed
  (adapter-declined) Codex file under opt-out likewise renders banner + raw
  editor with no nested notice — identical to today, documented as intentional.
- The opt-in banner, opt-out row, fidelity notice, and save flow are untouched.
- Line budget: `config_editor.dart` sits exactly at the 700-line cap, so the
  diff must be minimal (a few lines — for example hoisting the built card or a
  small getter — with no net growth beyond what the cap allows).

### Rules non-list notice (companion ConfigEditor change)

`rules` has no nested heuristic: a map-shaped (or scalar) `rules` value still
renders the Rules `StringListEditor` under opt-in while `config.rules` stays
`[]`, so attempted edits would be silently ignored once the map is preserved
— an editable control over an unsavable shape. The fix mirrors the
permissions nested-notice pattern: when `rawSettings['rules']` is non-null
and not a `List`, the Rules block shows the static notice "Nested rules are
preserved but not editable here yet." instead of the `StringListEditor`; the
raw editor remains the path for such files. List/absent shapes render exactly
as today. This is tool-agnostic (any TOML file, not just Codex) and shares the
700-line budget with the decoupling change — both diffs must stay minimal.

### TOML serializer preservation fix

`serializeWithOutcome` (`toml_config_parser.dart:87-98`) starts from
`config.rawSettings` but then unconditionally overwrites or removes the
`rules`/`permissions` keys from `config.rules`/`config.permissions` — which
`extractStringList` maps to `[]` for any map-shaped (or scalar) table. The
bounded fix manages those keys exactly where the flat editor is active: set
when the new list is non-empty and remove when emptied if the raw value was a
`List` (exactly as today); additionally write the user's additions when the
raw key was absent and the new list is non-empty (adding entries to a keyless
file works today and must keep working); leave the raw value untouched for
every other shape (Map, scalar — for `permissions` those take the
nested-notice branch, so the flat editor can never hold an in-flight edit over
them; map/scalar `rules` takes the companion notice from [Rules non-list
notice](#rules-non-list-notice-companion-configeditor-change) instead of the
Rules editor, so the same holds there). Consequences, all
covered by parser unit tests: map/scalar shapes keep every entry (assert
decoded-subtree equality after re-parsing the serialized output — formatting
may still change, so never assert byte equality);
absent+empty stays absent; absent+added writes; kept lists behave exactly as
today; cleared lists still remove the key. It enables no new editing and
changes no other key. Broader fail-closed policy
for lossy saves on complex TOML (refusing saves rather than warning) stays a
future product decision — tracked in [Resolved open
questions](#resolved-open-questions), out of this slice.

## Exploratory research spike

The spike ran 2026-09-10 as a throwaway test (not committed) against a
profile-shaped fixture. Outcomes, recorded here before implementation chunk 1:

1. `TomlDocument.parse(...).toMap()` returns `Map<String, dynamic>` at every
   level with `String` keys throughout — TOML keys are always strings, so the
   adapter has no non-string-key case (unlike the JSON adapters). Dotted table
   headers nest exactly as the presentation model assumes:
   `[permissions.project-edit.filesystem.":workspace_roots"]` decodes to
   `permissions → project-edit → filesystem → :workspace_roots → {...}`.
   Profile-shape values decode to `String`/`bool`/`int` (`glob_scan_max_depth
   = 3` → `int`); exotic values (for example TOML dates → `DateTime`) remain
   possible in principle, so the adapter uses `is Map` checks plus per-value
   `as` casts and never `as Map<String, String>`.
2. `extractStringList` on a table value is established behavior
   (`config_parser.dart:96-99`): non-lists yield `[]`, so a map-shaped
   `permissions` sets neither `config.permissions` nor the flat editor — the
   nested-permissions heuristic fires instead. A *list*-shaped `permissions`
   would populate `config.permissions` and hide that heuristic, so the adapter
   must decline it as malformed (see [Test strategy](#test-strategy)).
3. Both-sides `ConfigFormat.toml` is asserted by the chunk-1 guard tests
   (mirroring the Opencode jsonc-both-sides precedent via
   `loadDiscoveredConfig`); no separate spike needed.

Record the outcomes in this plan (Resolved open questions) before implementation
chunk 1; if the decoded shapes differ from the assumptions above, revise the
presentation model first.

## Test strategy

### Adapter unit tests (`test/schemas/codex_permissions_test.dart`)

Guard: user + project targets match; other tools, manual paths, profile-file
names (`dev.config.toml`), non-`config.toml` basenames, and non-TOML formats
decline. Shape: legacy keys only; `default_permissions` naming a built-in, a
same-file profile, and a missing (other-layer) profile; a full custom profile
(description, extends, workspace roots, filesystem with scoped subpaths +
`glob_scan_max_depth`, network with domains/unix_sockets); `extends`
displayed-not-resolved; sandbox_mode coexisting with `[permissions]`; malformed
recognized values decline (`permissions` as string, int (`permissions = 42`),
and TOML date (`permissions = 2021-01-01` → `DateTime`), access as int,
enabled as string, workspace-root value as string); empty file renders the
empty state; unsupportedReason is set on decline. Scope: TOML keys are always strings, so no
non-string-key case exists (unlike JSON adapters) — assert values only.
Near-miss paths decline (`workspace.codex/config.toml`, whose parent is not
`.codex`), mirroring the Cursor `workspace.cursor` regression test. Sibling
Codex catalog targets decline (for example `.codex/rules/default.rules`),
mirroring the Cursor `mcp.json` decline test. A list-shaped `permissions`
declines as malformed: it would otherwise populate `config.permissions` and
hide the nested-permissions heuristic, risking flat-editor exposure.

### Fixtures (`test/fixtures/codex_permissions_fixtures_test.dart`)

On-disk token-free user + project `config.toml` fixtures under
`test/fixtures/edge_cases` exercising the legacy shape, a full profile shape
**including a quoted dotted sub-table** (`[permissions.<name>.filesystem.":workspace_roots"]`,
the decode path the spike hinges on), a malformed shape, and an empty shape;
registry selection in both directions; assert the profile-file basename never
matches. Note: the existing `staging_home/.codex/config.toml` fixtures are
legacy-shape catalog targets, so widget/smoke paths surfacing them will now
render the card instead of the generic TOML editor — confirm no existing
assertion depends on the generic render for these files.

### Widget mapping (`test/widgets/policy_card_widget_registry_test.dart`)

Extend with the Codex adapter id → card builder mapping and the null cases
(unknown id, unavailable card, null presentation).

### Card widget (`test/widgets/codex_permissions_card_test.dart`)

Renders legacy rows, the selection row, profile sections, the empty state, the
stored-entries notice, the legacy-table presence note (when the table
co-exists), and the proxy-enforcement help line; malformed states are covered
at the adapter level.

### ConfigEditor integration (`test/widgets/config_editor_policy_card_test.dart`)

Extend with: a Codex card renders for a catalog-discovered `config.toml`; a
malformed Codex file falls back to the generic TOML editor; interacting with
the read-only card never saves or changes bytes (assert `onSave` is never
invoked and the captured raw content is unchanged). When
the card renders for a profile-shaped file, assert the nested-permissions
notice and the flat permissions editor stay hidden (mirroring the Opencode
`findsNothing` assertions), proving the card wins over the
`hasNestedUnsupportedPermissions` heuristic. Add opt-out coverage: with
`tomlStructuredSaveEnabled: false`, a Codex card still renders, the opt-in
banner still shows, and no `StringListEditor` appears anywhere (Rules stays
hidden, the permissions section shows only the card); assert the
`Permissions` section header renders with the card (it is part of the
section, new under opt-out alongside the card). Add opt-in preservation
coverage: with `tomlStructuredSaveEnabled: true`, saving a profile-shaped file
round-trips the `[permissions]` table with every entry preserved (assert
decoded-subtree equality after re-parsing, not byte equality — formatting may
still change) (parser preservation
fix). Add rules-notice coverage: a map-shaped (and scalar) `rules` value under
opt-in shows the nested-rules notice with no Rules `StringListEditor`, and a
save round-trips the raw `rules` table with every entry preserved. Card-absent TOML files
keep today's behavior — the existing fidelity-test `findsNothing`
`StringListEditor` assertions (for example `config_editor_fidelity_test.dart`
with a card-less config) must keep passing unchanged, plus a new manual-path
TOML regression test under opt-out.

### TOML fidelity and serializer preservation (`test/parsers/toml_config_parser_test.dart`)

TOML structured saves stay lossy for formatting and opt-in; the existing
`FidelityAssessor` opening notice already covers Codex files. Assert the notice
is present on a Codex target (viewing is safe) without adding notice code.
Additionally pin the preservation fix with parser unit tests: a map-shaped
`permissions`/`rules` value keeps every entry (assert decoded-subtree equality
after re-parsing the serialized output — formatting may still change, so never
assert byte equality), as does a scalar
value; an absent key with an empty list stays absent, while an absent key with
added entries writes them; a kept list behaves exactly as today; a
cleared list still removes the key (existing tests cover the kept-list path).
Include a tool-agnostic regression case: a manual-path-shaped TOML file (path
outside any `.codex/` dir) with a map-shaped table serializes with the table
preserved — the rule lives in the shared parser, so manual paths and any
current/future TOML tool are covered, while card eligibility stays
Codex-catalog-scoped.

## Docs, docstrings, and metadata

The Codex card is **user-visible**, so this slice updates user-facing docs.
Every statement must keep the read-only boundary explicit: the card shows
stored entries; structured editing of TOML stays opt-in/lossy and out of scope.

- `docs/supported-tools.md`:
  - Codex evidence row: append the read-only card to the "Schema
    evidence" cell; re-check the primary references and update the
    source-review date.
  - Codex Permissions section: add this bullet:
    `- **Read-only card:** The app renders the permission block of a discovered
    config.toml as a read-only policy card showing the file's stored entries;
    it does not compute Codex's effective policy and cannot edit TOML structure.`
- `CHANGELOG.md`: add a user-facing entry for the read-only Codex permissions
  card, worded as presentation-only.
- `plans/active/structured-configuration-roadmap.md`: mark the Phase 4
  progression item 2 (Codex read-only) done; keep item 4 (Codex editing gated on
  the AST-preserving TOML strategy) open.
- `TO_DO.md`: keep the "Structured configuration presentation" entry open; note
  the Codex card shipped and reference the archived plan after archival.
- **Docstrings:** every new public member in `codex_permissions.dart`,
  `codex_permissions_card.dart`, and the registry additions gets a doc comment
  following the existing convention.

## Resolved open questions

1. **Does the TOML-edit blocker apply to a read-only card?** No — decided with
   the maintainer 2026-09-10. The AST-preserving TOML strategy gates structured
   *editing* (roadmap item 4); this card adds no serialization path, so it
   proceeds as item 2. The roadmap and `TO_DO.md` now state the read/edit
   boundary explicitly.
2. **`extends` resolution.** Displayed, never resolved. Cross-file parents and
   inheritance semantics are Codex runtime behavior; the card shows the stored
   value and notes when the parent is not defined in this file (a built-in, a
   possible other-layer definition, or an unknown value Codex would reject).
3. **Legacy + profiles in one file.** Both halves shown as stored, plus the
   documented both-systems rule as a help note with a doc link. The card never
   decides which system Codex will use.
4. **Which top-level keys the card shows.** Bounded slice: `sandbox_mode`,
   `approval_policy`, `default_permissions`, `[permissions]`. All other stored
   config (`model`, `features`, MCP, hooks, keymaps) stays raw-editor-only and
   never suppresses the card.
5. **Network operational keys.** The card shows the policy subset (`enabled`,
   `domains`, `unix_sockets`, `allow_local_binding`); proxy listeners and
   `dangerously_*` keys are left to the raw editor without suppressing the card.
6. **Profile files and system config.** Not cataloged, never card-eligible;
   the basename + catalog-discovered guard excludes them by construction.
7. **Retired `approval_policy = "untrusted"`.** Shown as stored with a
   migration help link, never translated.
8. **TOML opt-out hides the card host (Greptile review, 2026-09-10).**
   `_supportsStructuredFields` returns the opt-in flag for TOML, so the
   default opt-out skipped the whole structured block including
   `_buildPermissionsSection` — the read-only card would have been reachable
   only after enabling lossy writes. Decided: decouple presentation from the
   write gate (one tool-agnostic `ConfigEditor` change with the exact render
   condition `!rawOnly && (_supportsStructuredFields || card != null)`,
   flat-editor branches never hoisted on their own) instead of leaving the
   card opt-in-gated (rejected: contradicts the read-only premise) or building
   a separate screen (rejected: over-engineering).
9. **Silent deletion of map-shaped tables on structured save (agy review,
   2026-09-10).** `serializeWithOutcome` dropped `rules`/`permissions` whenever
   the decoded value was not a non-empty list, silently deleting
   `[permissions.*]` on any opt-in save; the fidelity notice never warned
   about data loss. Decided with the maintainer: fix the root cause in-slice
   with the bounded preservation rule (list-shaped raw values are managed as
   today, user additions onto absent keys still write, everything else
   round-trips with entries preserved), plus parser and opt-in-save tests.
   A broader fail-closed policy for lossy saves on complex TOML is tracked as
   a future product decision, out of this slice.
10. **Editable Rules editor over an unsavable shape (CodeRabbit review,
    2026-09-10).** Map/scalar `rules` rendered the Rules `StringListEditor`
    while `config.rules` stayed `[]`, so attempted edits were silently
    ignored. Decided: mirror the permissions nested-notice pattern — a static
    notice replaces the editor for non-list `rules` shapes (tool-agnostic,
    raw editor remains the path), with widget + save-path tests. Documenting
    the quirk was rejected: an editable control must not accept edits it
    cannot persist.

## Implementation steps

1. The exploratory research spike already ran (2026-09-10); outcomes are
   recorded above. Re-run only if the presentation model changes.
2. Add `lib/schemas/codex_permissions.dart` (adapter + presentation + help, pure
   Dart, docstrings). `CodexPermissionsAdapter.adapterId = 'codex.permissions'`
   with `String get id => adapterId;`. Import `package:path/path.dart` as `p`
   for the `p.basename`/`p.dirname` target guard (mirroring
   `cursor_permissions.dart`/`opencode_permissions.dart`).
3. Add `lib/widgets/codex_permissions_card.dart` (read-only card, default doc
   launcher, help dialog, no write path).
4. Register the adapter in `PolicyCardRegistry.shared` and the card builder in
   `PolicyCardWidgetRegistry.shared`, plus the tool-agnostic presentation
   decoupling and non-list rules notice in `ConfigEditor` (card renders under
   the TOML opt-out; edit controls stay gated; unsavable rules shapes show a
   notice) and the bounded `TomlConfigParser` preservation fix.
   None of the three adds a per-tool branch or a write capability.
5. Add the fixtures and tests from [Test strategy](#test-strategy).
6. Update the docs, `CHANGELOG.md`, roadmap, and `TO_DO.md` from
   [Docs, docstrings, and metadata](#docs-docstrings-and-metadata).
7. Run the gates; review each chunk with the kilo stepfun + agy gemini
   reviewers, run the opencode whole-branch review before opening the PR, then
   archive this plan as the final commit before merge (per AGENTS.md — never a
   direct-to-main post-merge step).

## Acceptance criteria

- A catalog-discovered Codex `config.toml` (user or project) renders a
  read-only card showing the stored permission configuration: legacy
  sandbox/approval keys, the `default_permissions` selection, and each stored
  `[permissions.*]` profile's policy entries — **including with the default
  TOML structured-save opt-out** (no write capability required to view).
- With the opt-out, no structured edit affordance appears: the Rules editor and flat
  permissions editor stay hidden and the opt-in banner still shows; the only
  additions are the read-only card and its `Permissions` section header (part
  of the section, asserted in tests). (The raw text editor remains editable as
  today — that is a direct raw write, not a structured save.)
- With the opt-in, saving a profile-shaped file preserves the `[permissions]`
  (and `rules`) table with every entry preserved (assert decoded-subtree
  equality after re-parsing, not byte equality) (parser preservation fix);
  a map/scalar `rules` value shows the nested-rules notice instead of an
  editable Rules editor, and also round-trips preserved; formatting
  loss warnings still apply.
- The preservation rule applies to every TOML serialization — catalog Codex
  targets, manual TOML paths, and any current/future TOML tool — because it
  lives in the shared `TomlConfigParser`; card eligibility and presentation
  stay Codex-catalog-scoped as specified in the guard.
- Profile files, the system config, manual paths, other tools, and
  non-`config.toml` targets are unaffected; the generic TOML editor and the
  fidelity notice keep working.
- A malformed permission block (wrong-typed recognized value) declines to the
  raw-editor-first fallback; unknown keys alone never suppress the card.
- An absent permission block renders a safe empty state.
- The card states it shows stored entries, not the effective policy, and offers
  no edit affordance for TOML structure.
- `ConfigEditor` gains only the tool-agnostic presentation decoupling and the
  non-list rules notice; `TomlConfigParser` gains only the bounded preservation
  rule (which covers all TOML serializations, not just Codex targets — no new
  write capability); `FidelityAssessor` and `StructuredSaveFlow` are unchanged.
  `config_editor.dart` must stay within the 700-line cap.
- No interaction with the card saves or changes bytes.
- Gates green: `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze --fatal-infos`, `flutter test`, and
  `python3 ci/scripts/check_doc_links.py --internal-only --catalog-strict`.

## Completion steps

Per AGENTS.md, archive this plan as the last step before merging (final commit on
the implementation branch, riding in the PR; never a direct-to-main post-merge step):

1. [ ] Record the seam in the parent roadmap (mark the Phase 4 progression item 2,
   Codex read-only, done; keep item 4, Codex editing, open).
2. [ ] Keep the `TO_DO.md` "Structured configuration presentation" entry open and aligned.
3. [ ] Log the change in `CHANGELOG.md` (user-visible card) and `CHANGELOG.dev.md`
   if any developer-only note is warranted.
4. [ ] Move this file to `plans/archive/` as the final commit on the branch.

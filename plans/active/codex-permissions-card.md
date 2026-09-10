# Plan: Codex Permissions Card (roadmap Phase 4, item 2, read-only)

Last reviewed: 2026-09-10
Date: 2026-09-10
Author: maintainers
Status: active — planning on the `plan/codex-permissions-card` branch
Linked parent: [Structured Configuration Roadmap](structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Objective

Add a read-only policy card for the Codex TOML permission configuration (a
catalog-discovered `.codex/config.toml`), as the next non-Claude consumer of the
shared policy-card registry after Cursor (Phase 4A) and Opencode (Phase 4 item 1).
Codex is the roadmap's Phase 4 "expand one schema at a time" progression item 2.
A new `CodexPermissionsAdapter` + `CodexPermissionsCard` register in the shared
registries, plus one tool-agnostic `ConfigEditor` change (see [ConfigEditor
presentation decoupling](#configeditor-presentation-decoupling)): Codex is the
first TOML card, and today the TOML structured-save opt-out hides the whole
structured block including policy cards. The read-only card must render under
the default opt-out without enabling any write capability.

It is a **presentation slice only**: the card displays the file's stored permission
entries and must not compute the effective Codex policy (config-layer merging,
`extends` inheritance, runtime workspace roots, the sandbox-vs-profiles
precedence) or write a Codex file. **No TOML write path is added or changed.**
The roadmap's AST-preserving TOML edit strategy still gates Codex *structured
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
    `allow`/`deny`; `allow_local_binding`; proxy listener and `dangerously_*`
    operational keys).
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
- Fixtures and tests: adapter, registry selection, widget mapping, card,
  fallback, help/link failure, and a read-only/no-byte-mutation assertion.
- An exploratory research spike (recorded below) verifying the TOML decoded-map
  shapes before the adapter is written.
- Docs and docstring follow-through (see [Docs, docstrings, and metadata](#docs-docstrings-and-metadata)).

### Out of scope

- Any write, patch, or serialization path. No save control; `TomlConfigParser`,
  `FidelityAssessor`, `StructuredSaveFlow`, and the generic TOML editor are
  untouched. Codex structured editing remains a later roadmap item gated on an
  AST-preserving TOML strategy.
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
  or `[permissions]`) renders the empty state.
- The pre-existing structured-save boundary: a map-shaped `permissions` table
  decodes to `extractStringList → []`, so an opt-in structured TOML save would
  strip `[permissions.*]` from its output (`toml_config_parser.dart:95-98`).
  This slice adds no write path and must not widen that behavior; the
  `FidelityAssessor` TOML notice already warns.
- Any change to the generic flat editors, `FidelityAssessor`, `StructuredSaveFlow`,
  or `TomlConfigParser`. The single `ConfigEditor` exception is the
  tool-agnostic presentation decoupling described below — no per-tool branches,
  no new write path.

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

The presentation model:

- `sandboxMode` / `approvalPolicy`: top-level strings when present (`null` when
  omitted — the card distinguishes "Not set." from a stored value, including a
  stored retired `untrusted` policy, which help annotates with the migration
  link rather than translating).
- `defaultPermissions`: top-level string when present. When it names a profile
  with no table in this file (built-in, or defined in another layer), the card
  shows the selection plus a "defined in another config layer" note — it never
  resolves across files.
- `profiles`: one entry per `[permissions.<name>]` table with `description`,
  `extends` (stored value only, never resolved; unknown-parent and cycle
  rejection are Codex runtime behavior, not card behavior), `workspaceRoots`
  (path → bool map shown as-is), `filesystem` rules (path → access plus scoped
  subpath maps and `glob_scan_max_depth`), and the policy-relevant `network`
  subset (`enabled`, `domains`, `unix_sockets`, `allow_local_binding`). Proxy
  listener and `dangerously_*` operational keys are left to the raw editor (see
  unclassified rule below).
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
card builder in `PolicyCardWidgetRegistry.shared`. Confirm `ConfigEditor` needs
**no** changes.

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

- The Rules `StringListEditor` and every other edit control stay gated on the
  opt-in exactly as today.
- `_buildPermissionsSection` additionally renders when a card is available
  (`buildCard` non-null), even with the opt-out. When the card is available
  the section shows only the card — the flat `StringListEditor` and nested
  notice live on the card-absent branches (`:267-276`) and therefore cannot
  appear without the opt-in. Card-absent TOML files render exactly as today
  (banner + raw editor).
- The opt-in banner, opt-out row, fidelity notice, and save flow are untouched.
- Line budget: `config_editor.dart` sits exactly at the 700-line cap, so the
  diff must be minimal (a few lines — for example hoisting the built card or a
  small getter — with no net growth beyond what the cap allows).

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
recognized values decline (`permissions` as string, access as int, enabled as
string, workspace-root value as string); empty file renders the empty state;
unsupportedReason is set on decline. Scope: TOML keys are always strings, so no
non-string-key case exists (unlike JSON adapters) — assert values only.
Near-miss paths decline (`workspace.codex/config.toml`, whose parent is not
`.codex`), mirroring the Cursor `workspace.cursor` regression test. Sibling
Codex catalog targets decline (for example `.codex/rules/default.rules`),
mirroring the Cursor `mcp.json` decline test. A list-shaped `permissions`
declines as malformed: it would otherwise populate `config.permissions` and
hide the nested-permissions heuristic, risking flat-editor exposure.

### Fixtures (`test/fixtures/codex_permissions_fixtures_test.dart`)

On-disk token-free user + project `config.toml` fixtures under
`test/fixtures/edge_cases` exercising the legacy shape, a full profile shape,
a malformed shape, and an empty shape; registry selection in both directions;
assert the profile-file basename never matches.

### Widget mapping (`test/widgets/policy_card_widget_registry_test.dart`)

Extend with the Codex adapter id → card builder mapping and the null cases
(unknown id, unavailable card, null presentation).

### Card widget (`test/widgets/codex_permissions_card_test.dart`)

Renders legacy rows, the selection row, profile sections, the empty state, and
the stored-entries notice; malformed states are covered at the adapter level.

### ConfigEditor integration (`test/widgets/config_editor_policy_card_test.dart`)

Extend with: a Codex card renders for a catalog-discovered `config.toml`; a
malformed Codex file falls back to the generic TOML editor; interacting with
the read-only card never saves or changes bytes (byte-compare via
`originalContent`, since it is final — assert `onSave` is never invoked). When
the card renders for a profile-shaped file, assert the nested-permissions
notice and the flat permissions editor stay hidden (mirroring the Opencode
`findsNothing` assertions), proving the card wins over the
`hasNestedUnsupportedPermissions` heuristic. Add opt-out coverage: with
`tomlStructuredSaveEnabled: false`, a Codex card still renders, the opt-in
banner still shows, and no `StringListEditor` appears anywhere (Rules stays
hidden, the permissions section shows only the card). Card-absent TOML files
keep today's behavior — the existing fidelity-test `findsNothing`
`StringListEditor` assertions (for example `config_editor_fidelity_test.dart`
with a card-less config) must keep passing unchanged.

### TOML fidelity (no new code)

TOML structured saves stay unconditionally lossy and opt-in; the existing
`FidelityAssessor` opening notice already covers Codex files. Assert the notice
is present on a Codex target (viewing is safe) without adding notice code.

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
   value and notes definitions may live in another layer.
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
   write gate (one tool-agnostic `ConfigEditor` change, specified above)
   instead of leaving the card opt-in-gated (rejected: contradicts the
   read-only premise) or building a separate screen (rejected:
   over-engineering).

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
   decoupling in `ConfigEditor` (card renders under the TOML opt-out; edit
   controls stay gated). No per-tool branches.
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
- With the opt-out, no edit affordance appears: the Rules editor and flat
  permissions editor stay hidden and the opt-in banner still shows; the only
  addition is the read-only card.
- Profile files, the system config, manual paths, other tools, and
  non-`config.toml` targets are unaffected; the generic TOML editor and the
  fidelity notice keep working.
- A malformed permission block (wrong-typed recognized value) declines to the
  raw-editor-first fallback; unknown keys alone never suppress the card.
- An absent permission block renders a safe empty state.
- The card states it shows stored entries, not the effective policy, and offers
  no edit affordance for TOML structure.
- `ConfigEditor` gains only the tool-agnostic presentation decoupling (no
  per-tool branches); `TomlConfigParser`, `FidelityAssessor`, and
  `StructuredSaveFlow` are unchanged (no new write path). `config_editor.dart`
  must stay within the 700-line cap.
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

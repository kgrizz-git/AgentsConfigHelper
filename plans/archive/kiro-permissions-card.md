# Plan: Kiro Permissions Card (roadmap Phase 4, read-only)

Last reviewed: 2026-11-28
Date: 2026-11-26
Author: maintainers
Status: implemented and archived 2026-11-28 — read-only Kiro permissions card shipped; no write path
Tracking: completed; focused `TO_DO.md` entry removed; parent roadmap remains active
Linked issue/PR: #93 (plan), #94 (implementation)
Parent roadmap: [Structured Configuration Roadmap](../active/structured-configuration-roadmap.md)
Research: [configuration structured-editing gap](../../docs/research/config-structured-editing-gap.md)

## Outcome

Add one read-only Kiro permissions card for the catalog-discovered user file
`~/.kiro/settings/permissions.yaml`. The card shows the stored capability rules in a
focused, understandable view while the raw editor remains the source of truth. This slice
does not add editing, does not calculate Kiro's effective policy, and does not change any
bytes in the file. It also suppresses the legacy generic YAML Rules editor for this target
so the map-shaped capability list cannot be represented or edited through the string-list
path.

## Why this slice

The parent roadmap's Phase 4 progression names Kiro's YAML capability model and Devin's
scope-based model as the next schemas. Kiro is the better first slice for this cycle:

- It has exactly one registered structured target: the user `permissions.yaml`.
- Its documented format is a compact `rules` list with a closed capability set and a
  small effect set.
- The existing fixture is non-conforming, so the slice also corrects the fixture and
  establishes the first real Kiro schema contract.
- Devin's model spans user and project JSONC files and a broader permission syntax; it
  remains the next schema after this one.

The supporting architecture already exists. `PolicyCardAdapter`, `PolicyCardRegistry`, and
`PolicyCardWidgetRegistry` are shared, pure-Dart/UI seams with four registered consumers
(Claude, Cursor, Opencode, Codex). This slice adds a Kiro adapter and widget without
putting Kiro conditionals in `ConfigEditor`.

## Primary source

Reviewed 2026-11-26 against the current Kiro documentation:

- [Permissions](https://kiro.dev/docs/permissions/) (page updated 2026-11-26)
- [Configuration scopes](https://kiro.dev/docs/configuration/)
- [`docs/supported-tools.md` Kiro section](../../docs/supported-tools.md#kiro)
- Catalog target in `lib/catalog/tool_descriptor_registry.dart`

The Kiro permissions page now documents the following stored shape:

```yaml
rules:
  - capability: shell
    match: ["git *", "npm *"]
    exclude: ["git push *"]
    effect: allow
  - capability: fs_read
    effect: deny
```

### Stored rule contract

| Field | Required | Accepted stored shape |
| --- | --- | --- |
| `capability` | yes | One documented capability string |
| `effect` | yes | `deny`, `ask`, `allow`, or `evaluate` |
| `match` | no | List of glob-pattern strings |
| `exclude` | no | List of glob-pattern strings |

Documented capabilities are `fs_read`, `fs_write`, `shell`, `web_fetch`, `web_search`,
`mcp`, `subagent`, `skill`, `power`, `context`, `diagnostics`, and `sandbox_network`.
The meta-capabilities `all`, `builtin`, and `filesystem` are also documented values.
Kiro's current effect priority is `deny > ask > allow > evaluate`; `evaluate` is the
weakest effect and depends on Kiro's trust classifier. The user and workspace files can
also contain a top-level `policies` list of preset IDs; this slice does not expand or
display presets.

The card must describe **stored rules in this file**, not Kiro's effective decision.
Kiro evaluates rules across user, workspace, agent, session, enterprise, and hardcoded
scopes, and its default policy and trust invariants are not represented by this file.
The existing catalog evidence row predates several of these documented details, including
`evaluate` and meta-capabilities; update that row with the 2026-11-26 review date.

## Scope

### In scope

- Read-only presentation of `rules` in the catalog-discovered user target
  `~/.kiro/settings/permissions.yaml`.
- All documented effects, including `evaluate`.
- All documented capabilities, including the `all`, `builtin`, and `filesystem`
  meta-capabilities.
- Optional `match` and `exclude` string lists, displayed verbatim in file order.
- Empty/absent `rules` as a safe empty state.
- Unknown top-level keys, including `policies`, as an unclassified-content notice while
  still showing a valid `rules` list.
- Raw-editor fallback whenever the recognized `rules` subtree is malformed or
  unrepresentable.
- A shared policy-card ownership flag that suppresses the legacy generic YAML `Rules`
  `StringListEditor` for the Kiro target, keeping `rules` reachable only through the raw
  editor.
- Reviewed plain-language help and a link to the Kiro permissions documentation.
- Token-free fixtures, adapter tests, widget tests, registry tests, and ConfigEditor
  integration tests.

### Out of scope

- Any write or structured edit path for Kiro.
- Computing Kiro's effective allow/ask/deny/evaluate decision.
- Workspace-scoped `~/.kiro/workspace-roots/<hash>/permissions.yaml`, enterprise
  `managed-settings.json`, agent profiles, or in-memory session rules.
- Expanding or displaying `policies` presets, default policy, hardcoded trust invariants,
  sandbox host filtering, or workspace trust state.
- Kiro MCP, agents, steering, specs, or other undocumented targets.
- Devin, Antigravity, or any other schema.
- Automatic schema inference from arbitrary YAML files.
- Redesigning or suppressing the generic Rules editor for other schemas; this slice adds
  a shared ownership flag and uses it for Kiro only.

## Current-state baseline (as of plan start)

- `ToolId.kiro` is registered with one structured target:
  `.kiro/settings/permissions.yaml` (user scope, YAML) plus project steering Markdown.
- The generic YAML parser supplies `ToolConfig.rawSettings`; there is no Kiro schema
  adapter or card today.
- `PolicyCardRegistry.shared` registers Claude, Cursor, Opencode, and Codex only.
- `PolicyCardWidgetRegistry.shared` maps those four adapter IDs to widgets.
- `test/fixtures/staging_home/.kiro/settings/permissions.yaml` currently contains a
  non-conforming placeholder (`rules` of strings plus an undocumented top-level
  `permissions` map). It must become a valid, token-free Kiro example.
- Kiro's top-level `rules` is a YAML list, so the pre-existing generic `Rules`
  `StringListEditor` currently renders for a Kiro file. `extractStringList` drops the
  map-shaped entries, so the editor cannot represent them. A dirty generic rules save is
  refused by `_assertYamlFieldSafe` with `StructuredEditRefusedException`; this is not a
  silent overwrite, but the editor is misleading and unusable. This slice suppresses it
  for the Kiro target so `rules` stays raw-editor-only.
- `test/services/config_service_test.dart` uses `rules:\n  - r1` only to verify YAML
  loading by known target; it is not a schema fixture and does not need to become valid
  Kiro policy.

## Target design

### Adapter (`lib/schemas/kiro_permissions.dart`, pure Dart)

Implement `KiroPermissionsAdapter` with:

- `static const adapterId = 'kiro.permissions';` and `String get id => adapterId;`.
- `static final Uri documentationUri = Uri.parse('https://kiro.dev/docs/permissions/');`.
- A target guard requiring all of:
  - `discoveredConfig != null` and `fromCatalog == true`;
  - descriptor ID `ToolId.kiro`;
  - `kind == ConfigSourceKind.structuredConfig`;
  - `format == ConfigFormat.yaml` on both `DiscoveredConfig` and `ToolConfig`;
  - scope `ConfigLocationScope.user`;
  - normalized path components ending in `.kiro`, `settings`, `permissions.yaml`.
    Use path-component checks, not a loose suffix or basename alone, so a manual path
    with the same shape does not receive a card.
- Add `bool suppressGenericRulesSection` (default `false`) to `PolicyCardSelection` and
  include it in value equality. The Kiro adapter sets it true for every matching Kiro
  target selection, including `unsupported`; it stays false for `notApplicable` and for
  all existing adapters.
- `rawSettings['rules']` interpretation:
  - absent or an empty list: available empty state;
  - a present `null` value: unsupported (raw-editor-first), per resolved question 4;
    detect it with `rawSettings.containsKey('rules') && rawSettings['rules'] == null`,
    not from `ToolConfig.rules`, which the parser normalizes to an empty list;
  - a non-list value: unsupported;
  - every list entry must be a map with only the known keys;
  - `capability` and `effect` must be strings in the documented sets;
  - `match` and `exclude`, when present, must be lists containing only strings;
  - any unknown rule key, unknown capability, unknown effect, wrong type, or malformed
    entry makes the whole recognized subtree unsupported (raw-editor-first);
  - rules retain file order; duplicates are displayed as written.
- Top-level keys other than `rules` do not suppress a valid rules list, but set
  `hasUnclassifiedSettings = true`. This includes `policies`.
- No adapter method mutates the config or touches the filesystem.

Presentation types:

- `KiroPermissionRule` with `capability`, `effect`, `List<String>? match`, and
  `List<String>? exclude`. A null list means the key was omitted; an empty list means the
  user wrote an empty list. The card shows those states distinctly without assigning
  extra meaning to either.
- `KiroPermissionsPresentation extends PolicyCardPresentation` with an immutable
  `List<KiroPermissionRule> rules` and `bool hasUnclassifiedSettings`.
- `KiroPermissionFieldHelp` plus a `KiroPermissionsHelp` metadata holder for the policy
  introduction, effect explanations, capability labels/help, and the read-only scope.

Unsupported selections carry a concise reason naming the field or rule index. Available
selections always carry a non-null presentation, matching the `PolicyCardSelection`
contract.

### Card (`lib/widgets/kiro_permissions_card.dart`)

Render a read-only card with:

- Header `Kiro permissions` and the policy-level read-only explanation.
- Empty state: no rules stored in this file.
- One section per stored rule in file order:
  - human-readable capability label with help affordance;
  - effect badge/text (`deny`, `ask`, `allow`, `evaluate`);
  - `Match` patterns and `Exclude` patterns as selectable code text;
  - explicit `Not set` for an omitted list and `No patterns` for an explicit empty list;
  - a short help description that says this is the stored rule, not Kiro's effective
    decision.
- An unclassified-content notice when `hasUnclassifiedSettings` is true, directing the
  user to raw content.
- A `Kiro permissions documentation` action using the same injected launcher/error
  handling pattern as the existing cards.
- Accessible controls, narrow-width wrapping, and 2x text-scale tolerance.
- No edit, save, add, or delete controls.

The card never infers that an omitted `match`/`exclude` means "all"; it displays the
stored absence and explains only what the primary source documents.

### Registrations and ConfigEditor

- Register `KiroPermissionsAdapter()` in `PolicyCardRegistry.shared` after the existing
  adapters; the target guard makes it non-overlapping.
- Register `KiroPermissionsAdapter.adapterId` → `KiroPermissionsCard` in
  `PolicyCardWidgetRegistry.shared`.
- Do not add Kiro branches to `ConfigEditor`. Unsupported selections continue through the
  existing raw-editor-first path.
- `ConfigEditor` must skip `_buildRulesSection` when the selected policy card has
  `suppressGenericRulesSection == true`. This is a shared ownership seam, not a Kiro
  branch; the raw editor remains available.
- The Kiro card remains read-only. The suppression prevents the legacy string-list
  editor from replacing map-shaped rules; it does not add a write path.
- Existing adapters default the flag false, so their generic Rules behavior is unchanged.
  Keep the existing card rendering and raw fallback intact except for this shared flag.

## Fixtures

Replace `test/fixtures/staging_home/.kiro/settings/permissions.yaml` with a valid,
token-free example containing several capabilities, all common effects, at least one
`evaluate` rule, at least one `match`/`exclude` pair, and at least one rule without
`match`. Add edge-case fixtures under `test/fixtures/edge_cases/`:

- valid all-effects/meta-capability fixture;
- empty `rules`;
- absent `rules` with unrelated top-level keys;
- top-level `policies` plus a valid rules list;
- non-list `rules`;
- `rules: null` (an explicit null value);
- non-map rule entry;
- missing capability/effect;
- unknown capability/effect;
- scalar/non-string `match`/`exclude`;
- unknown rule key.

Fixtures must contain no secrets, tokens, token-shaped placeholders, or real user data.
Document the fixture contract in the fixture test and keep the safe-testing intake rule.

## Test strategy

### Adapter tests (`test/schemas/kiro_permissions_test.dart`)

- Target gating: valid catalog user target; manual path; wrong tool; wrong scope; wrong
  format; wrong kind; path near-misses (for example a similarly named file outside
  `.kiro/settings`); null `DiscoveredConfig`.
- Valid rules with every effect, including `evaluate`, and every capability, including
  meta-capabilities.
- Optional and explicit-empty `match`/`exclude`; rule order and duplicates.
- Absent and empty `rules`; non-list `rules`; null `rules`.
- Missing/unknown capability or effect; non-map entry; unknown rule key; invalid
  `match`/`exclude` element types.
- Unknown top-level keys and `policies`: available card plus unclassified flag.
- `PolicyCardSelection.suppressGenericRulesSection`: defaults false; true for Kiro
  available and unsupported selections; false for Kiro notApplicable and other adapters.
- Help metadata and documentation URI; no mutation of the input map.

### Fixture tests (`test/fixtures/kiro_permissions_fixtures_test.dart`)

- Parse the valid staging and edge fixtures through the adapter.
- Assert malformed fixtures produce `unsupported`, not `available`.
- Assert the unclassified-top-level fixture remains available with the notice flag.
- Assert the valid fixture round-trips through a no-edit save with the map-shaped `rules`
  intact.
- Assert fixtures contain no secret-like content.

### Widget tests (`test/widgets/kiro_permissions_card_test.dart`)

- Renders rules, capability labels, effects, patterns, and the empty state.
- Shows the unclassified-content notice.
- Help dialogs and documentation launcher success/failure/no-Scaffold behavior.
- Narrow surface and 2x text scaling without overflow.
- No write/save controls and no file mutation.

### Registry and integration tests

- Extend `test/schemas/policy_card_registry_test.dart` with Kiro selection and prove a
  near-miss/manual path does not select it.
- Extend `test/widgets/policy_card_widget_registry_test.dart` with the Kiro adapter ID and
  wrong-presentation-type fallback.
- Extend or add a ConfigEditor integration test proving a valid Kiro fixture renders the
  card while a malformed fixture renders the raw fallback, and opening/interacting with
  the card never changes file bytes.
- Assert `ConfigEditor` omits the legacy generic Rules `StringListEditor` for valid and
  unsupported Kiro targets, while the card/unsupported reason and raw editor remain.
- Add a no-edit save regression proving the map-shaped Kiro `rules` survive byte-for-byte;
  the card itself never saves.
- Run the existing full suite; the new card must not change existing selection order or
  the generic Rules behavior of the Claude/Cursor/Opencode/Codex cards.

## Docs and metadata

- Update the Kiro row in `docs/supported-tools.md` with the 2026-11-26 review, the
  read-only card, `evaluate`, meta-capabilities, `policies` as unclassified, and the
  valid fixture reference; do not claim workspace-scope discovery or effective-policy
  calculation.
- Update `CHANGELOG.md` with the user-visible read-only Kiro permissions card.
- Update `CHANGELOG.dev.md` with the adapter, fixture, registry, and test changes.
- In the final pre-merge feature-branch commit, mark the Kiro portion of roadmap Phase 4
  item 3 complete and link the archived plan; keep Devin and the remaining roadmap work
  open.
- Keep a focused open entry under `TO_DO.md` → Structured configuration presentation
  until implementation, validation, review, and changelog follow-through are complete;
  the broader structured-configuration queue entry stays open.
- Complete implementation, validation, review, changelog, and other follow-through
  first. Then, in the final pre-merge commit, mark this plan complete, update the parent
  roadmap, remove the focused `TO_DO.md` entry, and move this plan to `plans/archive/` so
  the archival rides in the implementation PR. Keep the parent roadmap active with Devin
  and remaining work open. Do not archive this plan on `main` after merge.

## Validation and gates

Every implementation change must pass:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
python3 ci/scripts/check_doc_links.py --internal-only --catalog-strict
```

No analyzer/lint/check suppressions. The full suite includes the existing Claude, Cursor,
Opencode, and Codex card tests; Kiro must not regress their selection or fallback.

## Acceptance criteria

- [x] The card appears only for the catalog-discovered Kiro user
      `.kiro/settings/permissions.yaml`; manual paths and near-misses do not match.
- [x] A valid `rules` list renders every recognized rule in file order, including all
      documented effects, capabilities, and optional `match`/`exclude` lists.
- [x] Absent/empty rules show a clear empty state; malformed recognized content is
      unsupported and raw-editor-first; unknown top-level content is preserved and
      disclosed without hiding a valid rules list.
- [x] The card is read-only: no write controls, no save calls, and no file mutation from
      opening or interacting with it.
- [x] The legacy generic Rules editor is not rendered for the Kiro target; map-shaped
      capability rules survive a no-edit save unchanged.
- [x] Help and documentation are reviewed, accessible, and scoped to stored rules rather
      than Kiro's effective policy.
- [x] Fixtures, adapter/widget/registry/integration tests, docs, changelogs, and the
      roadmap update are complete.
- [x] Format, analyze, tests, docs-link, and full CI are green; the plan has been cleared
      by the two requested reviewers.

## Implementation steps

1. Re-check Kiro's permissions documentation immediately before coding; record any
   schema drift in this plan.
2. Replace the staging fixture and add the edge-case fixtures.
3. Implement the pure-Dart adapter, presentation models, help metadata, and adapter tests.
4. Implement the card widget, register it, and add widget/registry tests.
5. Add the ConfigEditor integration/raw-fallback/no-mutation tests.
6. Update `docs/supported-tools.md`, both changelogs, the parent roadmap, and `TO_DO.md`.
7. Run the complete validation and review gates; open the implementation PR.
8. After implementation, validation, review, and changelog follow-through, make the
   final pre-merge commit: update the parent roadmap, remove the focused `TO_DO.md`
   entry, and move this plan to `plans/archive/` so archival rides in the implementation
   PR. Keep the parent roadmap active. Do not archive directly on `main` after merge.

## Risks and decisions

- **Kiro documentation drift.** The current page now includes `evaluate`,
  meta-capabilities, and `policies`, which the older catalog row does not mention.
  Re-check before implementation; unknown future capability/effect values stay
  unsupported rather than guessed.
- **Scope separation.** Kiro's workspace permissions live outside the repository and are
  not registered. This card must not imply that it sees them or that it computes the
  user/workspace/agent/session merge.
- **YAML shapes.** Anchors, aliases, custom tags, and unusual mappings remain raw-only
  unless the parser has already resolved them into the documented map/list shape; do not
  add a second YAML dialect.
- **Omitted versus empty patterns.** The card shows `Not set` versus `No patterns`
  without interpreting either as "match everything"; Kiro's pattern semantics are not
  duplicated in the UI.
- **Unknown rule keys are fail-closed.** A rule with an undocumented key can change
  semantics, so the whole card falls back to raw content rather than displaying a
  partial rule. Top-level keys outside this card's presentation scope, including
  `policies`, do not invalidate a valid `rules` subtree; they trigger the
  unclassified-content notice. `policies` is semantic to Kiro, but preset expansion is
  out of scope.
- **Fixture change.** The existing staging Kiro fixture is not a valid example; replacing
  it must keep discovery tests and the recreated test-root workflow green.
- **Legacy generic Rules editor.** The pre-existing YAML `StringListEditor` drops
  map-shaped rule entries and cannot represent them. A dirty save is refused by
  `_assertYamlFieldSafe` with `StructuredEditRefusedException`, so the risk is a
  misleading, unusable editor rather than a silent overwrite. The shared suppression flag
  removes that editor for the Kiro target; test both available and unsupported selections
  and a no-edit save. Do not leave this path reachable for Kiro.
- **No write path.** The card adds no structured write behavior. The only `ConfigEditor`
  change is suppressing the unsafe legacy Rules editor for this target; the raw editor
  and existing fidelity warnings remain authoritative.

## Resolved questions

1. Should `evaluate` be accepted? Yes; it is documented and appears in current Kiro
   files. It is displayed as the weakest effect, with help text explaining the trust
   classifier dependency.
2. Should meta-capabilities be accepted? Yes; `all`, `builtin`, and `filesystem` are
   documented capability values. `sandbox_network` remains a normal capability.
3. Should `policies` be expanded? No. It is an unclassified top-level setting in this
   slice; a valid `rules` list still renders and the card tells the user to inspect raw
   content.
4. Should `rules: null` be treated as empty? No. Only an absent or empty list is the
   empty state; a null value is malformed/unsupported and stays raw-first.
5. Should `match`/`exclude` accept a scalar string? No. Current Kiro examples and
   contract use lists; a scalar is unsupported until the primary source documents it.
6. Should unknown rule keys be displayed? No. They make the rule subtree unsupported;
   unknown top-level keys alone do not suppress a valid card.
7. Should the card show default policy or effective decisions? No. It shows only what is
   stored in this file; the help text states that Kiro evaluates the effective policy.
8. Should the workspace permissions file be discovered? No, not in this slice. Its path
   is outside the repository and it is not a registered target.
9. Should the generic Rules editor remain for Kiro? No. A shared
   `PolicyCardSelection.suppressGenericRulesSection` flag lets the Kiro adapter tell
   `ConfigEditor` to omit only that legacy section; the raw editor remains. A no-edit save
   must preserve the map-shaped rules.

## Implementation record

- Implemented in PR #94. Re-checked the live Kiro permissions documentation on
  2026-11-28; the documented capabilities, effects, meta-capabilities, `match`/`exclude`,
  and `policies` behavior had not drifted from the plan.
- Shipped `KiroPermissionsAdapter`, `KiroPermissionsPresentation`/`KiroPermissionRule`,
  `KiroPermissionsCard`, registry wiring, the shared
  `PolicyCardSelection.suppressGenericRulesSection` seam, valid/malformed fixtures, and
  adapter/widget/registry/ConfigEditor coverage.
- Added a file-backed no-edit `ConfigService` save test after review to prove map-shaped
  rules survive byte-for-byte; parser-level round-trip coverage remains as well.
- Local format, analyze, full suite, docs-link, pre-commit, and CI gates passed on the
  implementation head. The final archival commit moved this plan, updated roadmap Phase 4,
  and removed the focused `TO_DO.md` entry.

## Review record

- 2026-11-28 — IMPLEMENTATION CLEARED: `opencode` / `nvidia/moonshotai/kimi-k3.1-pro`;
  optional test-hardening nits only, addressed afterward without production changes.
- 2026-11-28 — IMPLEMENTATION CLEARED: `kilo` / `baidu/ernie-5.5-flash-preview:free`;
  no blocking findings, only defensive-code/convention nits.
- 2026-11-26 — CLEARED: `opencode` / `nvidia/moonshotai/kimi-k3.1-pro`, including the
  Sourcery generic Rules-editor mitigation.
- 2026-11-26 — CLEARED: `kilo` / `baidu/ernie-5.5-flash-preview:free`, including the
  Sourcery generic Rules-editor mitigation.
- Prior clearance at revision `2f40f50` was superseded by the mitigation; both reviewers
  re-cleared revision `144ff62`.
- 2026-11-27 — post-clearance accuracy clarifications: explicit `rawSettings` detection
  for `rules: null`, precise fail-closed wording for the legacy generic Rules save path,
  and precise `policies` semantics. These do not change scope, tests, or acceptance.

## Completion

Completed and archived 2026-11-28 in PR #94. The checklist below records the final
feature-branch commit that rode in that PR:

Before merging, as the final feature-branch commit:

- complete implementation, validation, review, changelog, and other follow-through;
- mark the Kiro portion of roadmap Phase 4 item 3 complete and link the archived plan;
- remove the focused `TO_DO.md` entry and move this plan to `plans/archive/` so archival
  rides in the implementation PR;
- leave Devin, structured editing for existing schemas, workspace-scope Kiro discovery,
  and the broader structured-configuration roadmap as separate future work;
- keep the parent roadmap active. Do not archive this plan directly on `main` after
  merge.

# Plan: Shared Policy-Card Adapter Registry (Phase 0 refactor)

Last reviewed: 2026-09-06
Date: 2026-09-06
Author: maintainers
Status: in progress — shared selection interface to be extracted before Phase 4A
Linked parent: [Structured Configuration Roadmap](structured-configuration-roadmap.md)
Linked task: [TO_DO.md — Structured configuration presentation](../../TO_DO.md#structured-configuration-presentation)

## Objective

Extract the tool-branched Claude Code permissions card wiring out of `ConfigEditor`
into a shared, pure-Dart (no Flutter imports) **adapter + registry selection interface**,
so future tool cards (starting with Cursor in Phase 4A) register at one selection point
instead of adding further branches throughout `ConfigEditor`.

This delivers the roadmap Phase 0 acceptance item:

> Establish shared adapter/presentation interfaces with no Flutter dependencies and a
> single registry/selection point. — `structured-configuration-roadmap.md:59`

It is a **presentation/selection refactor only**: behavior must remain byte-for-byte
identical from the user's perspective. No saving, no patching, no new card content, and
no write-path changes are in scope.

## Scope

### In scope

- A pure-Dart adapter interface describing how a tool schema interprets a
  `ToolConfig` + `DiscoveredConfig` into a display outcome.
- A single pure-Dart selection registry that resolves which (if any) adapter matches
  the current config, and returns its outcome.
- Migration of `ClaudeCodePermissionsAdapter` onto that interface with **identical
  behavior**, and re-routing of `ConfigEditor` to the registry.
- A thin Flutter-side mapping so the registry stays Flutter-free while `ConfigEditor`
  still renders the correct card widget.
- The regression tests needed to prove the refactor did not change behavior (see
  [Test strategy](#test-strategy)).

### Out of scope

- The Cursor `permissions.json` card itself (that is Phase 4A, a follow-up plan that
  consumes this registry). This plan only ensures the Cursor adapter can be added
  without new `ConfigEditor` branches.
- Any change to the generic flat `permissions`/`rules` string-list editors, the fidelity
  notice (`FidelityAssessor`), `StructuredSaveFlow`, or the raw-editor fallback.
- Any write-path / patch / serialization changes.

## Current state (evidence)

- `lib/schemas/claude_code_permissions.dart` — already pure Dart (no Flutter imports):
  `ClaudeCodePermissionsAdapter.interpret({config, discoveredConfig})` →
  `ClaudeCodePermissionsInterpretation` with status `notApplicable | available |
  unsupported`, an optional `ClaudeCodePermissionsPresentation`, and an
  `unsupportedReason`. Clean seam, but it is a **single tool type**, not an interface.
- `lib/widgets/claude_code_permissions_card.dart` — Flutter card consuming
  `ClaudeCodePermissionsPresentation` plus an optional doc launcher. Reusable as-is.
- `lib/widgets/config_editor.dart` hardcodes the tool branch:
  - line 105: `static final _claudePermissionsAdapter = ClaudeCodePermissionsAdapter();`
  - lines 235-239: `_claudePermissions` getter calling the adapter.
  - lines 363-401: `_buildPermissionsSection(...)` rendering `ClaudeCodePermissionsCard`
    inline when `claudePermissions.isAvailable`.
  - lines 407-412: `hasUnsupportedPermissions` bool combining the Claude `isUnsupported`
    status with a generic raw `permissions`-is-a-Map check.
  - line 580: call site passing `claudePermissions` + `hasUnsupportedPermissions`.
- The generic flat `StringListEditor` fallback for non-Claude tools (lines 381-398) is
  **not** Claude-specific and must be preserved unchanged.

## Target design

### Pure-Dart interface (`lib/schemas/policy_card.dart`)

```dart
enum PolicyCardStatus { notApplicable, available, unsupported }

/// No Flutter dependencies. Base class for a schema's display payload.
abstract class PolicyCardPresentation {
  const PolicyCardPresentation();
}

/// Outcome of asking a schema adapter to interpret the current config.
class PolicyCardSelection {
  const PolicyCardSelection({
    required this.adapterId,
    required this.status,
    this.presentation,
    this.unsupportedReason,
  });

  final String adapterId;
  final PolicyCardStatus status;
  final PolicyCardPresentation? presentation;
  final String? unsupportedReason;

  bool get isAvailable => status == PolicyCardStatus.available;
  bool get isUnsupported => status == PolicyCardStatus.unsupported;
}

/// A tool schema's read-only interpretation step.
abstract class PolicyCardAdapter {
  String get id; // e.g. 'claudeCode.permissions'
  PolicyCardSelection select({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  });
}
```

### Registry (`lib/schemas/policy_card_registry.dart`)

A pure-Dart registry holding the ordered adapter list. `select(...)` iterates adapters,
returns the first non-`notApplicable` selection, or a `notApplicable` sentinel when none
match. Registration is explicit and injectable so tests can register a fake adapter.

```dart
class PolicyCardRegistry {
  PolicyCardRegistry(this._adapters);
  final List<PolicyCardAdapter> _adapters;

  PolicyCardSelection select({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) { /* first non-notApplicable, else sentinel */ }

  static PolicyCardRegistry shared = PolicyCardRegistry([
    ClaudeCodePermissionsAdapter(), // Cursor adapter registers here in Phase 4A
  ]);
}
```

### Widget mapping (`lib/widgets/policy_card_widget_registry.dart`)

Because adapters must stay Flutter-free, a separate widget registry maps
`adapterId` → `Widget Function(PolicyCardPresentation)`. `ConfigEditor` renders the card
by looking up the resolved selection's `adapterId`. The cast to the concrete presentation
is safe because the key is the adapter that produced it.

```dart
class PolicyCardWidgetRegistry {
  PolicyCardWidgetRegistry(this._builders);
  final Map<String, Widget Function(PolicyCardPresentation)> _builders;
  Widget? build(PolicyCardSelection s) =>
      s.isAvailable ? _builders[s.adapterId]?.call(s.presentation!) : null;
}
```

### ConfigEditor changes

- Remove the `_claudePermissionsAdapter` field, the `_claudePermissions` getter, the
  inline `ClaudeCodePermissionsCard` render, and the `hasUnsupportedPermissions` bool's
  Claude coupling.
- In `build`: resolve `final selection = PolicyCardRegistry.shared.select(...)`, then:
  - `selection.isAvailable` → render `PolicyCardWidgetRegistry` card (Claude card).
  - `selection.isUnsupported` → render `selection.unsupportedReason`.
  - else keep the **generic** flat-editor path, preserving the existing raw
    `permissions`-is-a-Map "nested permissions" reason (now computed from the raw config
    alone, not from Claude status).
- Behavior at every branch must match today's output exactly.

## Test strategy

This answers "how do we know nothing broke": a behavior-preserving refactor is only safe
if the pre-existing net stays green **and** we add registry-level tests for the new seam.

### Existing tests that must remain green (the primary net)

- `test/schemas/claude_code_permissions_test.dart` — adapter interpretation: nested
  values, unclassified siblings, default modes, invalid values → unsupported,
  not-applicable for manual paths / other tools. Protects the pure-Dart logic that moves
  onto the new interface.
- `test/widgets/claude_code_permissions_card_test.dart` — card rendering + doc-link
  failure handling. Protects the widget that stays as-is.
- `test/widgets/config_editor_test.dart` — end-to-end ConfigEditor integration, notably:
  - `shows a Claude card instead of the nested permissions notice` (line 311),
  - `does not offer a flat permissions editor for Claude settings without a policy`
    (line 365),
  - the flat-editor and raw-content tests (lines 34, 86, 135, 184, 237, 274, 420, 473).

These three files are the regression contract. The refactor is not complete until they
all pass unchanged against the new registry path.

### New tests to add

Pure-Dart registry unit tests (`test/schemas/policy_card_registry_test.dart`):

- Returns the Claude selection for a catalog-discovered Claude settings config.
- Returns a `notApplicable` sentinel when no adapter matches (manual path, other tool).
- Returns the first matching selection when multiple adapters are registered (with a
  fake adapter to prove first-match, order-independent selection).
- Confirms the registry delegates interpretation to the Claude adapter unchanged (assert
  a known presentation round-trips).

Widget-mapping tests (`test/widgets/policy_card_widget_registry_test.dart`):

- Maps `adapterId` → the correct card widget.
- Returns `null` for an unknown `adapterId` / non-`available` selection.

ConfigEditor integration additions (`test/widgets/config_editor_test.dart`):

- After refactor, a **non-Claude** tool with a List `permissions` still renders the
  generic flat `StringListEditor` (proves the registry did not swallow generic tools).
- A Claude config with an unsupported shape still renders the unsupported-reason text
  through the registry.

### Verification gates

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test` (full suite green)
- `python3 ci/scripts/check_doc_links.py --internal-only --strict`

## Implementation steps

1. Add `lib/schemas/policy_card.dart` (interface + selection + presentation base).
2. Add `lib/schemas/policy_card_registry.dart` (registry + injectable adapter list,
   seeding it with the existing Claude adapter).
3. Make `ClaudeCodePermissionsAdapter` implement `PolicyCardAdapter` and
   `ClaudeCodePermissionsPresentation` extend `PolicyCardPresentation`, changing
   `interpret` → `select` with **no behavior change**; keep the existing status names
   behind the new enum (or map them) so callers/tests stay aligned.
4. Add `lib/widgets/policy_card_widget_registry.dart` mapping
   `'claudeCode.permissions'` → `ClaudeCodePermissionsCard`.
5. Refactor `ConfigEditor` to the registry + widget mapping, preserving the generic
   flat-editor and nested-permissions fallback.
6. Add the new tests; run the full suite; confirm every pre-existing test passes
   **unchanged**.
7. Update docs/roadmap only if user-visible; record the seam in
   `docs/supported-tools.md` / this roadmap as part of Phase 0 progress. Keep the
   `TO_DO.md` entry open until the slice is validated.

## Acceptance criteria

- `ConfigEditor` contains no `ClaudeCodePermissionsAdapter`, `ClaudeCodePermissionsCard`,
  or Claude-specific permission branches.
- A single pure-Dart registry resolves card selection; a separate widget registry renders
  it.
- Adding a new adapter requires registering it in the registry (and a widget builder),
  with **no** new branch in `ConfigEditor`.
- All pre-existing tests pass unchanged; new registry + widget + ConfigEditor tests pass.
- Gates above are green.

## Completion steps

Per AGENTS.md, archive this plan as the last step before merging (final commit on this
feature branch, riding in the PR; never a direct-to-main post-merge step):

1. Record the seam in the parent roadmap (mark Phase 0's shared-interface box
   `[x]` after the Cursor adapter lands, or note this plan as its deliverable).
2. Keep the `TO_DO.md` "Structured configuration presentation" entry open and aligned.
3. Log the change in `CHANGELOG.dev.md` (developer-only refactor; not user-visible).
4. Move this file to `plans/archive/` as the final commit on the branch.

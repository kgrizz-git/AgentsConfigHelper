# Plan: Shared Policy-Card Adapter Registry (Phase 0 refactor)

Last reviewed: 2026-09-06
Date: 2026-09-06
Author: maintainers
Status: implementation complete (Chunks 1-5, each reviewed); pending merge + archive
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
/// Extends [Equatable] so concrete presentations keep value equality.
abstract class PolicyCardPresentation extends Equatable {
  const PolicyCardPresentation();
}

/// Outcome of asking a schema adapter to interpret the current config.
///
/// Invariant: an `available` selection MUST carry a non-null [presentation];
/// a null [presentation] on `available` is a contract violation and is treated
/// as "no card" by the widget registry.
class PolicyCardSelection extends Equatable {
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

  @override
  List<Object?> get props => [adapterId, status, presentation, unsupportedReason];
}

/// A tool schema's read-only interpretation step.
abstract class PolicyCardAdapter {
  /// Stable key used by the widget registry. The interface requires an
  /// **instance** getter; each concrete adapter also exposes a `static const
  /// adapterId` so callers reference it by name, and the instance getter
  /// forwards to it. The static const MUST be named `adapterId` (not `id`)
  /// because Dart forbids a static and an instance member sharing one name:
  /// `static const adapterId = '...'; String get id => adapterId;`
  String get id;

  /// The adapter **interprets** a config into a selection; only the registry
  /// below is named `select`. Method is `interpret` to match the existing
  /// `ClaudeCodePermissionsAdapter.interpret` and avoid renaming its callers.
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  });
}
```

### Registry (`lib/schemas/policy_card_registry.dart`)

A pure-Dart registry holding the ordered adapter list. `select(...)` iterates adapters and
returns the **first non-`notApplicable` selection** (registration order wins), or a
`notApplicable` sentinel when none match. The sentinel carries a null `unsupportedReason`
and null `presentation`, and its `adapterId` is a named constant
(`PolicyCardRegistry.noAdapterId`, value `''`) so callers and tests never rely on an
implicit default; `buildCard` looks up that id, finds no builder, and returns `null`. The
generic nested-permissions fallback string is supplied by `ConfigEditor`, not by the
registry.

`shared` is a `final`, immutable default so tests never mutate it. Tests inject a
registry (and widget registry) explicitly instead.

```dart
class PolicyCardRegistry {
  PolicyCardRegistry(this._adapters);
  final List<PolicyCardAdapter> _adapters;

  PolicyCardSelection select({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) { /* first non-notApplicable, else sentinel */ }

  static final PolicyCardRegistry shared = PolicyCardRegistry([
    ClaudeCodePermissionsAdapter(), // Cursor adapter registers here in Phase 4A
  ]);
}
```

### Widget mapping (`lib/widgets/policy_card_widget_registry.dart`)

Because adapters must stay Flutter-free, a separate widget registry maps
`adapterId` → a `Widget? Function(PolicyCardSelection)`. `ConfigEditor` resolves the
selection, then asks the widget registry to `buildCard(selection)`; a `null` return means
"no card here" and `ConfigEditor` falls back to the generic flat editor. Builders must
type-check the presentation and never use a null-bang: a non-`available` selection, an
unknown `adapterId`, or an `available` selection with a null `presentation` all return
`null` (or a fallback message) instead of throwing. The Claude builder supplies the card's
default `onOpenDocumentation` launcher (the current `ConfigEditor` relies on that default).

```dart
class PolicyCardWidgetRegistry {
  PolicyCardWidgetRegistry(this._builders);
  final Map<String, Widget? Function(PolicyCardSelection)> _builders;

  Widget? buildCard(PolicyCardSelection s) {
    if (!s.isAvailable || s.presentation == null) return null;
    final builder = _builders[s.adapterId];
    return builder == null ? null : builder(s);
  }
}
```

### ConfigEditor changes

`ConfigEditor` gains an optional injectable `registry` and `widgetRegistry`, both
defaulting to the `shared` instances (so tests pass deterministic fakes and never mutate
`shared`).

- Remove the `_claudePermissionsAdapter` field, the `_claudePermissions` getter, and the
  inline `ClaudeCodePermissionsCard` render. Replace the `hasUnsupportedPermissions`
  bool with the raw-config generic check it encodes, so the **non-Claude nested-Map path
  survives the refactor** (it applies to any tool, not just Claude):

  ```dart
  final hasNestedUnsupportedPermissions =
      _currentConfig.rawSettings['permissions'] != null &&
      _currentConfig.rawSettings['permissions'] is! List &&
      _currentConfig.rawSettings.containsKey('permissions');
  ```

- In `build`: resolve `final selection = registry.select(...)`, then:
  - `selection.isAvailable` → render `widgetRegistry.buildCard(selection)` (the Claude
    card). A `null` from `buildCard` falls through to the flat-editor path rather than
    crashing.
  - `selection.isUnsupported || hasNestedUnsupportedPermissions` → render
    `selection.unsupportedReason ?? 'Nested permissions are preserved but not editable here yet.'`.
    The OR is required: a non-Claude or manual-path config with a Map `permissions` yields
    `selection.status == notApplicable` (so `isUnsupported` is false) yet must still show
    the nested-permissions text, exactly as today. The `??` fallback string is required
    because both the generic nested-Map path and the registry's `notApplicable` sentinel
    carry a null `unsupportedReason`.
  - else keep the **generic** flat-editor path. The flat `StringListEditor` binds to the
    **parsed** `_permissions` (a different source than the raw check above), so the
    `permissions: null` case (`config_editor_test.dart:274`) still shows the flat editor.
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

These three files are the regression contract. Because the adapter's status enum is
renamed `ClaudeCodePermissionsStatus` → `PolicyCardStatus`, the adapter's return type
becomes `PolicyCardSelection`, and `ConfigEditor` now imports `policy_card.dart` /
`policy_card_registry.dart`, the schema-adapter test and ConfigEditor test files need
**mechanical** updates (status references → `PolicyCardStatus`, imports, and
`_buildPermissionsSection`'s parameter type). No assertion, fixture, test-name, or
expected-value changes. The card test passes unchanged. The refactor is not complete until
the full suite is green with only those mechanical edits applied.

### New tests to add

Pure-Dart registry unit tests (`test/schemas/policy_card_registry_test.dart`):

- Returns the Claude selection for a catalog-discovered Claude settings config.
- Returns a `notApplicable` sentinel when no adapter matches (manual path, other tool,
  and `discoveredConfig: null`); the sentinel's `adapterId` equals `noAdapterId`.
- Returns the first registered match when multiple adapters are registered; assert
  ordering explicitly with a fake adapter (first match wins — this is inherently
  order-dependent, not "order-independent").
- Confirms the registry delegates interpretation to the Claude adapter unchanged (assert
  a known presentation round-trips).

Widget-mapping tests (`test/widgets/policy_card_widget_registry_test.dart`):

- Maps a known `adapterId` → the correct card widget.
- Returns `null` for an unknown `adapterId`, a non-`available` selection, and an
  `available` selection with a null `presentation` (no crash on any of these).
- Confirms the Claude builder type-checks its presentation (rejects a wrong-type
  presentation without casting).

ConfigEditor integration additions (`test/widgets/config_editor_test.dart`):

- After refactor, a **non-Claude** tool with a List `permissions` still renders the
  generic flat `StringListEditor` (proves the registry did not swallow generic tools).
- A **non-Claude** tool whose `rawSettings['permissions']` is a Map renders the generic
  nested-permissions text **and does not** render the flat `StringListEditor`. This is the
  generic `hasNestedUnsupportedPermissions` branch (reached via the OR, not via
  `selection.isUnsupported`).
- A **manual-path Claude** config (fromCatalog false) with a Map `permissions` renders the
  nested-permissions text, not the flat editor — the same generic branch, guarding the
  behavior-transition the refactor could otherwise break.
- A Claude config with an unsupported shape still renders the unsupported-reason text
  through the registry.
- A Claude config through the registry-built card still shows the default doc-launcher
  failure feedback when the URL cannot be opened (registry supplies the default).

### Verification gates

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test` (full suite green)
- `python3 ci/scripts/check_doc_links.py --internal-only --strict`

## Implementation steps

1. Add `lib/schemas/policy_card.dart` (interface + selection + presentation base, all
   `Equatable`).
2. Add `lib/schemas/policy_card_registry.dart` (final `shared` + injectable adapter list,
   seeding it with the existing Claude adapter).
3. Make `ClaudeCodePermissionsAdapter` implement `PolicyCardAdapter`: add
   `static const adapterId = 'claudeCode.permissions'` **and** an instance getter
   `String get id => adapterId;` (required by the interface; a `static` member alone does
   not satisfy `implements`, and a static member cannot share the name `id`). Keep the
   `interpret` method name; its return type becomes `PolicyCardSelection` and
   `ClaudeCodePermissionsStatus` is renamed `PolicyCardStatus` with **no semantic change**.
   `ClaudeCodePermissionsPresentation` extends `PolicyCardPresentation`. Update the schema
   and fixture adapter tests only by the mechanical enum/return-type rename (plus a
   `presentationOf` narrowing helper, since `PolicyCardSelection.presentation` is the
   base type).
4. Add `lib/widgets/policy_card_widget_registry.dart` mapping
   `ClaudeCodePermissionsAdapter.adapterId` → `ClaudeCodePermissionsCard`, builder type-checks the
   presentation and supplies the default doc launcher.
5. Refactor `ConfigEditor` to the injectable registry + widget mapping, preserving the
   generic flat-editor and nested-permissions fallback (parsed `_permissions` for the flat
   editor, `rawSettings['permissions'] is! List` for the unsupported check).
6. Add the new tests; run the full suite; confirm the card and ConfigEditor tests pass
   unchanged and the schema-adapter test changed only by the mechanical rename.
7. Do **not** change `docs/supported-tools.md` (no user-visible change). Record the seam
   in the parent roadmap (Phase 0 shared-interface box). Keep the `TO_DO.md` entry open
   until the slice is validated.

## Acceptance criteria

- `ConfigEditor` contains no `ClaudeCodePermissionsAdapter`, `ClaudeCodePermissionsCard`,
  or Claude-specific permission branches.
- A single pure-Dart registry resolves card selection; a separate widget registry renders
  it.
- Adding a new adapter requires registering it in the registry (and a widget builder),
  with **no** new branch in `ConfigEditor`.
- All pre-existing tests pass; the schema-adapter test changes only by the mechanical
  status-enum/return-type rename, and the card + ConfigEditor tests pass unchanged. New
  registry + widget + ConfigEditor tests pass.
- Gates above are green.

## Completion steps

Per AGENTS.md, archive this plan as the last step before merging (final commit on this
feature branch, riding in the PR; never a direct-to-main post-merge step):

1. Record the seam in the parent roadmap (mark Phase 0's shared-interface box
   `[x]` after the Cursor adapter lands, or note this plan as its deliverable).
2. Keep the `TO_DO.md` "Structured configuration presentation" entry open and aligned.
3. Log the change in `CHANGELOG.dev.md` (developer-only refactor; not user-visible).
4. Move this file to `plans/archive/` as the final commit on the branch.

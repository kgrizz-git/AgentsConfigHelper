# Plan: Claude Code Permissions Vertical Slice

Last reviewed: 2026-08-24
Date: 2026-08-23
Author: maintainers
Status: complete — read-only presentation, automated coverage, and manual macOS smoke accepted
Linked issue/PR: n/a
Parent plan: [Structured Configuration Roadmap](../active/structured-configuration-roadmap.md)
Primary references: [Claude Code settings](https://code.claude.com/docs/en/settings) and
[Claude Code permissions](https://code.claude.com/docs/en/permissions)

## Goal

Display the recognized Claude Code permission policy in a clear read-only card while
preserving the existing raw editor as the source of truth. The slice must make an
`allow`/`ask`/`deny` policy easier to inspect without changing a byte of a configuration
file or implying that unsupported Claude settings are understood.

## Scope

The adapter applies only to the `claudeCode` descriptor's catalog-discovered user and project
`.claude/settings.json` targets. It reads the nested object from
`ToolConfig.rawSettings['permissions']`, not the legacy flat `ToolConfig.permissions` list.
`settings.local.json` is intentionally out of scope because it is not currently a registered
discovery target. The adapter recognizes this exact `permissions` subtree:

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Read(path/**)"],
    "ask": ["Bash(command)"],
    "deny": ["Read(private/**)"]
  }
}
```

`allow`, `ask`, and `deny` are optional arrays of strings; when present, every element
must be a string. `defaultMode` is optional and must be a string when present. The adapter
accepts only Claude Code's documented modes: `default`, `manual`, `acceptEdits`, `plan`,
`auto`, `dontAsk`, and `bypassPermissions`. It does not validate whether an individual rule is
accepted by the installed Claude Code
version, and it does not interpret hooks, environment settings, MCP settings, model
settings, or unknown permission keys.

## UX contract

| Situation | UI behavior |
| --- | --- |
| Valid recognized subtree | Show a **Claude Code permissions** read-only card: optional default mode and separate Allow, Ask, and Deny sections with counts and rule strings. Retain the raw editor below it. |
| `permissions` absent | Show a safe empty Claude permissions card that directs the user to raw content for `allow`/`ask`/`deny` changes. Do not expose the legacy flat permissions editor, which would serialize an invalid array shape. |
| `permissions` is not an object, a recognized field has an invalid type, or an array contains a non-string | Do not render a partial card. Show one concise explanation that the permissions shape is not supported for structured display and direct the user to raw content. |
| Extra, unknown keys inside `permissions` | Render the fully validated recognized fields and clearly note that additional permission settings remain available only in raw content. Do not display or edit their values. |
| Non-Claude target or format | Do not select this adapter. Existing generic behavior remains unchanged. |

The card's help copy must say that it reflects the file's declared policy; Claude Code,
not this app, evaluates permission rules. Link to the official permissions reference.

## Design and ownership

| Target | Responsibility |
| --- | --- |
| `lib/models/` or a new pure-Dart schema directory | Immutable Claude permission presentation/value objects. No Flutter imports. |
| `lib/services/` or `lib/catalog/` | Adapter selection using descriptor identity plus exact config format/target—not a display-name string. |
| `lib/widgets/` | Focused read-only card and accessible help/link affordance. It receives a presentation model and has no JSON map casts. |
| `lib/widgets/config_editor.dart` | Requests the presentation once and composes the card with the existing raw-editor fallback. It does not grow a tool-specific JSON parser. |
| `test/fixtures/` | Token-free Claude JSON and JSONC-shaped regression samples; never copied user settings. |

Choose final file names consistent with the existing layout, but keep schema extraction unit-testable
without widget pumping and keep widget tests independent of the filesystem.

## Phases and acceptance criteria

### Phase 0 — baseline and shape tests

- [x] Read the linked Claude documentation at implementation time and record any schema
      version/behavior caveat in `docs/supported-tools.md` only if the curated reference
      needs correction.
- [x] Add token-free fixtures for: complete policy, omitted optional fields, extra unknown
      permission key, invalid scalar/object field, mixed-type array, no `permissions`, and
      a JSONC/comment-preservation sample if the parser accepts that input for the target.
      Use a documented extra key such as `disableBypassPermissionsMode` rather than an
      invented setting name.
- [x] Add a pure-Dart adapter test for every fixture. Assert both extracted values and the
      explicit eligibility/fallback reason—never a silent null result.
- [x] Assert parsing itself preserves `ToolConfig.originalContent` and `rawSettings` for
      all fixtures.

### Phase 1 — read-only presentation

- [x] Add an immutable presentation model for default mode, policy groups, unknown-key
      notice, help text, and documentation URI.
- [x] Select the Claude adapter from the discovered descriptor identity. Manual files that
      are not confidently classified as Claude Code must not receive the card.
- [x] Build a read-only card with distinguishable Allow/Ask/Deny labels, a safe missing-policy
      empty state, rule counts, and sensible wrapping/scrolling for long rule strings.
- [x] Make help keyboard-accessible and expose the official documentation URI without
      forcing the app to open a browser in a widget test.
- [x] Ensure the current “nested permissions … not editable” text is replaced only for a
      recognized Claude card. Narrow the existing generic nested-permissions check so it
      does not render a conflicting notice alongside that card; unsupported nested schemas
      still get the raw fallback notice.
- [x] Do not add controls that mutate permission values, and do not change
      `JsonConfigParser.serialize` in this phase.

### Phase 2 — regression coverage and manual check

- [x] Unit-test selection, recognized extraction, malformed fallback, unknown-key notice,
      and non-Claude rejection.
- [x] Widget-test recognized and malformed card states, the unclassified-settings notice,
      documentation callback, and raw-editor fallback; assert rule text is readable rather
      than relying only on snapshot structure.
- [x] Test an unchanged-card interaction performs no save and leaves exact raw content
      intact. Retain existing parser round-trip tests.
- [x] Run the macOS test-root smoke with the Claude fixture: confirm the card appears,
      raw content remains available, no file changes occur merely from viewing, and the
      staging root can be cleaned explicitly afterward.

### Phase 3 — decision gate for editing

This plan ends after read-only acceptance. Open a separate implementation phase only when
all of the following are true:

- AST locations can target each supported nested value without rewriting unrelated text;
- fixtures prove unchanged bytes and minimal, reviewable patches for one-field edits;
- patch failure blocks structured save and preserves the raw-editor path;
- diff, backup, restore, cancellation, and failed-write behavior are covered; and
- the parent roadmap's help and safety decisions still match the shipped card.

Until then, do not expose add/remove/reorder controls for this card.

## Out of scope

- Editing any Claude setting, including `defaultMode` and permission arrays.
- Validating command glob semantics or reproducing Claude Code's precedence engine.
- Hooks, environment, MCP, model, project instruction, or `CLAUDE.md` presentation.
- Other tools' nested permission schemas.
- Whole-document JSON/JSONC reformatting as an escape hatch.

## Validation

Run before review:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
python3 ci/scripts/check_doc_links.py --internal-only --strict
```

Update `CHANGELOG.md` when the card becomes user-visible, `CHANGELOG.dev.md` for
fixture/test-only work, the parent roadmap as phases close, and `TO_DO.md` to point at the
implemented next slice. Do not bump the release version until an actual release cut.

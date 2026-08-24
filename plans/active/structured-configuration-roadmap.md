# Plan: Structured Configuration Roadmap

Last reviewed: 2026-08-24
Date: 2026-08-23
Author: maintainers
Status: active — Claude Code read-only presentation and reviewed help shipped; structured editing and further schemas remain planned
Linked issue/PR: n/a
Research: [configuration structured-editing gap](../../docs/research/config-structured-editing-gap.md)

## Goal

Evolve the app from format-level editing into an understandable, safe configuration
manager without pretending that every JSON, YAML, or TOML file has the same semantics.
For each supported tool schema, present recognized settings as focused UI, keep
unrecognized content faithfully available in the raw editor, and only permit structured
edits after their write behavior is proven by fixtures and minimal-patch tests.

## Product decisions

- A **tool schema** is identified by tool, config target, and an explicitly supported
  structure—not merely by file extension or a field named `permissions`.
- The generic parser remains responsible for syntax and retaining the original document.
  A schema adapter may interpret a known portion of its decoded settings, but it must not
  discard unknown keys, ordering, or raw content.
- The first presentation for a new schema is read-only. A structured card does not make a
  file editable; the existing raw editor remains the escape hatch for every file.
- A schema editor must fail closed: if the document shape, source AST, or patch cannot be
  proven safe, suppress structured editing and direct the user to the raw editor. Never
  silently fall back to a whole-document rewrite for a schema-aware edit.
- Plain-language help is reviewed, versioned schema metadata with an owning tool's
  authoritative documentation URL. It must label unknown settings as unclassified rather
  than infer meaning from a name.
- Synthetic and sanitized fixtures are the only committed examples. They contain neither
  secrets nor token-shaped placeholders. See [Safe Testing Foundation](safe-testing-foundation.md).

## Architecture boundary

Introduce a small pure-Dart schema-presentation layer between `ToolConfig.rawSettings` and
Flutter widgets. It should return an immutable presentation model containing:

| Concern | Contract |
| --- | --- |
| Schema identity | Tool ID, exact target/format, supported revision or shape contract. |
| Recognized data | Typed, read-only fields extracted only after validating their full claimed subtree. |
| Help metadata | Display label, plain-language explanation, and authoritative documentation URL. |
| Eligibility | Explicit reason when a card or future structured edit is unavailable. |
| Raw fidelity | Original content and unrecognized settings remain untouched and accessible. |

Do not put tool-specific conditionals throughout `ConfigEditor`, or extend `ToolConfig`
with a union of every vendor's settings. Widgets render a presentation model; adapters own
schema recognition; a later patcher owns writes.

## Delivery sequence

### Phase 0 — contracts and fixture baseline

- [ ] Record the authoritative source, target path, accepted shape, and non-goals for each
      proposed schema before implementing it.
- [ ] Establish shared adapter/presentation interfaces with no Flutter dependencies and a
      single registry/selection point.
- [ ] Add token-free fixtures for recognized, malformed, unsupported-nested, and
      comments/formatting-preservation cases. Document sanitized-regression-fixture intake
      in the safe-testing plan.
- [ ] Preserve an explicit raw-editor fallback in all tests and UX states.

### Phase 1 — Claude Code permission cards (read-only, complete)

The completed first slice is documented in the archived
[Claude permissions vertical-slice plan](../archive/claude-permissions-vertical-slice.md).
It is deliberately limited to Claude Code's `permissions.defaultMode` and `allow`/`ask`/
`deny` string arrays in user and project `settings.json` files.

Exit criteria:

- the card renders only a validated Claude subtree;
- unfamiliar or malformed forms remain raw-editor-first without data loss;
- no structured write path is added; and
- pure-Dart, parser/fixture, and widget tests pass.

### Phase 2 — Claude structured editing, only after proof

- [ ] Design an AST-aware patcher for the exact Phase 1 subtree; it may replace only the
      intended value nodes, preserving comments, ordering, and unrelated formatting.
- [ ] Prove byte-for-byte equality when no structured changes are made and a small,
      reviewable diff when one supported value changes.
- [ ] Add diff-preview, backup, restore, cancellation, and failed-write coverage for the
      structured path.
- [ ] Block editing for missing/ambiguous nodes or patch failures; offer the raw editor
      rather than full-document reserialization.
- [ ] Reassess the public UX after the read-only slice before enabling mutation.

### Phase 3 — reviewed help and documentation links (Claude Code complete)

- [x] Attach plain-language explanations and official Claude Code links to the Phase 1
      metadata, including a clear statement that the app displays configuration rather than
      determining the tool's runtime decision.
- [x] Provide accessible help affordances (keyboard reachable, tooltip/description not
      hover-only) and link-opening tests.
- [x] Establish metadata review/versioning conventions before copying help to another tool:
      keep reviewed help in the pure-Dart schema layer, cite the primary documentation in
      `docs/supported-tools.md`, and preserve a raw-editor-first fallback for unknown shapes.

### Phase 4 — expand one schema at a time

Prioritize only after a fixture and primary-source review. A likely progression is:

1. Cursor's JSON allow/deny arrays, if its exact on-disk shape is confirmed.
2. Opencode's per-tool allow/ask/deny maps, as a distinct nested-map adapter.
3. Kiro's YAML capability model and Devin's scope-based model.
4. Codex TOML profiles, only after an AST-preserving TOML edit strategy exists.

Each schema gets its own acceptance contract, fixtures, raw fallback, and focused plan or
plan section. Do not add a schema merely because the generic parser can decode it.

### Phase 5 — regression and platform confidence

- [ ] Complete the remaining safe-testing regression work: default-mode startup coverage,
      an unsupported nested-structure raw-editor fixture, and documented sanitized-fixture
      intake.
- [ ] Keep the macOS `--test-root` smoke as the manual end-to-end proof for read/write
      behavior; do not wait for Linux or Windows work to deliver macOS schema slices.
- [ ] Plan platform-native Linux/Windows containment before enabling test-root there.
- [ ] Periodically run the supported-schema fixture matrix through parsing, rendering,
      patching (where enabled), diff, backup, and restore tests.

## Non-goals

- A universal settings form, arbitrary JSON-path editor, or automatic semantic inference.
- Editing Markdown rules or raw instruction documents as structured permission schemas.
- Sending configuration content to an AI service to generate explanations.
- Replacing the raw editor, diff preview, or backup-before-write safety model.
- Linux/Windows test-root implementation; that remains in the safe-testing roadmap.

## Validation and completion

Every implementation slice must run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
python3 ci/scripts/check_doc_links.py --internal-only --strict
```

Before a schema is marked editable, additionally require fixture tests showing unchanged
files preserve exact bytes, supported changes create a minimal patch, unsupported shapes
cannot enter the structured write path, and backup/restore plus diff review work end to end.

Archive this roadmap only after the delivery sequence is either completed or split into
durable successor plans; retain completed checklist items as history.

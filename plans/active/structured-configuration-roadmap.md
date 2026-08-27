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

### Phase 0.5 — formatting-fidelity disclosure (planned before another card)

The detailed implementation plan, acceptance criteria, and open safety decisions
are in [Formatting Fidelity Disclosure](formatting-fidelity-disclosure.md). That
focused plan is authoritative for this phase; the summary below remains the parent
roadmap decision record.

Viewing a file never changes it. Saving through a structured path is different: the
current parser can preserve original text only on some paths. The editor must make
that distinction obvious *when the file is opened*, not only after the user has made
an edit or opened the review dialog.

#### Verified current baseline (2026-08-27)

| Format/path | Current behavior | User-facing implication |
| --- | --- | --- |
| Raw Markdown/text and a raw-only save with no independent structured edits | Writes the text supplied by the user; no parser serialization occurs. | No format-conversion warning is needed. |
| JSON/JSONC supported flat-field patch | `JsonConfigParser` patches known `rules`/flat `permissions` nodes using source offsets. | Comments, trailing commas, and unrelated formatting are retained on the successful patch path. |
| JSON/JSONC fallback | A failed or unsupported patch silently falls back to full JSON reserialization. | JSONC comments and formatting can be lost; strict JSON has no comments but can still be reformatted. |
| YAML supported update | `YamlEditor` updates a parsed map in place. | Existing comments and formatting are retained on the supported path. |
| YAML fallback | A failed in-place update builds a fresh YAML document. | Comments and formatting can be lost. |
| TOML structured save | `TomlConfigParser` always reconstructs a TOML document from a map. | Comments, whitespace, ordering, and layout can be lost or reformatted on every structured save. |

This means **TOML is the only unconditionally lossy structured-save format today**.
JSONC is not inherently lossy—the supported AST patch preserves comments—but it is
not a guarantee because its current fallback rewrites the document. YAML has the
same conditional fallback risk. The existing TOML notice appears only in the
review dialog after a structured edit; that is insufficient. See
[`ADR-001`](../../docs/adr/ADR-001-toml-comment-preservation.md) and the parser
tests for the baseline evidence.

#### Implementation contract

- [ ] Introduce a small, immutable fidelity assessment owned by the serialization
      layer—not tool-specific cards. Its user-facing model separates direct raw
      writes from parser serialization and assigns `none`, `caution`, or `warning`
      risk. This reconciles the four write capabilities: only direct raw writes are
      certified as preserving; JSON/JSONC/YAML advertise a possible rewrite fallback
      rather than a pre-save "supported preservation" promise; TOML is an
      unconditional structured rewrite. It must account for actual parsed content
      (for example JSONC syntax in a `.json` file), not only the filename extension.
- [ ] Render a persistent, screen-reader-accessible notice at the top of
      `ConfigEditor`, before structured controls and raw content, for every file
      with a possible or unconditional lossy structured-save path. State plainly
      that viewing is safe; identify which action can reformat the file; point to
      raw content and diff review; and do not rely on colour or the later review
      dialog alone. TOML wording must say that a structured save can discard
      comments and formatting. JSONC/YAML wording must say preservation applies
      only when the safe in-place path succeeds and must never promise otherwise.
- [ ] Keep the existing review-dialog notice as a last confirmation, but derive it
      from the same assessment so its language cannot disagree with the opening
      notice. Do not show a format-loss notice for a raw-only Markdown/text file.
- [ ] Test the notice on initial display for TOML, parsed JSONC, and YAML; test the
      no-notice raw-text case; test keyboard/screen-reader semantics; and retain
      byte-for-byte no-save/view tests. Add parser/service tests that exercise the
      advertised preservation and fallback classifications.
- [ ] Decide and document the fallback policy before enabling any additional
      structured write path. Recommended direction: a failed JSONC/YAML patch
      should fail closed and leave the raw editor available, rather than silently
      taking the lossy fallback. A warning is disclosure, not permission to make
      an unexpected whole-document rewrite.

#### Open questions / research remaining

1. Can `yaml_edit` preserve comments, anchors, aliases, block scalars, and comments
   adjacent to every proposed schema subtree, or should those shapes be classified
   as raw-editor-only before a save is offered? Create fixtures before relying on
   its current broad success-path claim.
2. Should a user explicitly be able to approve a lossy generic TOML save, or should
   the generic TOML structured controls be read-only until an AST-aware TOML patcher
   exists? The current app warns but permits the save; this is a product-safety
   decision, not an implementation detail.
3. How should an externally changed file be handled between opening the editor and
   saving it? The fidelity assessment must describe the bytes actually supplied to
   `ConfigService`, not make a stale promise about a replaced on-disk file.

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

Prioritize only after a fixture and primary-source review. The next bounded slice is
Cursor Agent `permissions.json`, defined below. A likely later progression is:

1. Opencode's per-tool allow/ask/deny maps, as a distinct nested-map adapter.
2. Kiro's YAML capability model and Devin's scope-based model.
3. Codex TOML profiles, only after an AST-preserving TOML edit strategy exists.

Each schema gets its own acceptance contract, fixtures, raw fallback, and focused plan or
plan section. Do not add a schema merely because the generic parser can decode it.

#### Phase 4A — Cursor Agent permissions card (read-only, planned)

**Goal:** Show the validated contents of a catalog-discovered Cursor Agent
`permissions.json` as one read-only policy card while preserving the raw editor as
the source of truth. This is a presentation slice only: it must not calculate the
effective Cursor permission policy or write a Cursor file.

**Primary evidence reviewed 2026-08-27:** Cursor's
[permissions.json reference](https://cursor.com/docs/reference/permissions) documents
the user path `~/.cursor/permissions.json`, project path
`<workspace>/.cursor/permissions.json`, JSONC support, and these optional fields:

| Stored field | Accepted display shape | Card meaning |
| --- | --- | --- |
| `mcpAllowlist` | `string[]` | MCP `server:tool` patterns declared in this file. |
| `terminalAllowlist` | `string[]` | Terminal command/prefix patterns declared in this file. |
| `autoRun.allow_instructions` | `string[]` | Natural-language guidance that leans Auto-review toward allowing calls. |
| `autoRun.block_instructions` | `string[]` | Natural-language guidance that leans Auto-review toward prompting. |

All four fields are optional. Unknown top-level or `autoRun` sibling keys remain
unclassified and available in raw content. The card must say that it displays this
file's stored entries, not runtime decisions: user and project arrays are combined,
and team-admin or in-app settings can take precedence. It must not encode reports of
version-specific Cursor behavior as product truth.

##### Scope and acceptance contract

- [ ] Complete Phase 0's shared pure-Dart presentation/selection interface first;
      register the Claude and Cursor adapters in one selection point without adding
      tool branches throughout `ConfigEditor`.
- [ ] Apply only to catalog-discovered `ToolId.cursor` structured targets at the two
      documented paths, never a manual path that merely has a matching JSON shape.
      Update catalog/docs format metadata to reflect that Cursor accepts JSONC even
      though the filename is `permissions.json`; the fidelity notice must follow
      parsed content rather than that filename.
- [ ] Treat a present recognized field with a non-list or a non-string entry as an
      unsupported subtree and show raw-editor-first rather than imitating Cursor's
      silent dropping of malformed entries. Unknown keys alone do not suppress an
      otherwise valid card. An empty object and omitted fields are valid empty
      policy states.
- [ ] Give each displayed field reviewed, plain-language help and a link to the
      primary reference. Explain matching and precedence only at the level the
      source documents; do not claim the app can determine whether a future action
      will run without approval.
- [ ] Add token-free user and project fixtures, including a JSONC fixture with
      comments/trailing commas, plus malformed recognized fields, unsupported
      nested shapes, unknown siblings, and an empty policy. Test the adapter,
      selection registry, card, fallback, help/link failure, and that opening or
      interacting with a read-only card never saves or changes bytes.
- [ ] Run the standard format, analysis, test, and internal-link gates. Update
      `docs/supported-tools.md`, this roadmap, and `CHANGELOG.md` only when the
      card is user-visible; keep the `TO_DO.md` entry open until the complete slice
      is validated.

##### Research complete for planning; open implementation questions

1. The official reference currently says user/project arrays are concatenated and
   settings are re-read on change. There are recent reports of version-specific
   desktop inconsistencies. The card avoids computing an effective policy, so this
   does not block read-only presentation; re-check the primary reference before
   implementation and retain the source-review date in `docs/supported-tools.md`.
2. Confirm whether the card should include all four documented fields in its first
   view (recommended) or split `autoRun` into a later card. Splitting it would make
   the initial card smaller but leaves a documented permission-adjacent object raw.
3. Decide the exact relationship between the new generic fidelity notice and a
   JSONC Cursor fixture. The notice is required on opening whenever a structured
   save could take a lossy fallback, even though this phase does not add a write
   control.

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

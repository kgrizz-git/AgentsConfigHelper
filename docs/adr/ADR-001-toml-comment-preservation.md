# ADR-001: TOML serialization is lossy (comments not preserved)

Last reviewed: 2026-08-14
Date: 2026-08-14
Status: accepted
Deciders: maintainers

## Context

`TomlConfigParser.serialize` (`lib/parsers/toml_config_parser.dart`) rebuilds the
file from the parsed map via `TomlDocument.fromMap(...).toString()`. This is
**lossy**: comments, whitespace, key ordering, and structural nuance (e.g.
arrays-of-tables syntax) are discarded and the file is reformatted from scratch.
Qodo review finding #12 flagged this drawback.

The other two structured parsers avoid this and edit **in place**, preserving
comments on untouched content:

- **YAML** (`yaml_config_parser.dart`) uses `yaml_edit`'s `YamlEditor`, which does
  surgical, source-preserving `update()`/`remove()` edits.
- **JSON/JSONC** (`json_config_parser.dart`) uses a vendored `json_ast`
  (`lib/vendor/json_ast/`) that exposes source offsets, so `serialize` splices
  replacement text into the original string and leaves everything else byte-for-byte.

TOML is the outlier **only because the Dart ecosystem has no source-preserving TOML
editor**. Other ecosystems do (Python `tomlkit`, Rust `toml_edit`); the Dart `toml`
package (v0.18) exposes no comment-preserving round-trip and no public source spans.

Scope note: this app only ever mutates two known top-level array keys — `rules` and
`permissions` — both flat lists of strings. It does not need general AST editing.

## Decision

**Defer** any comment-preserving TOML work for now. Keep the from-scratch rebuild in
`TomlConfigParser.serialize` and keep the `**WARNING:**` doc comment that documents
the lossy behavior. Revisit if comment-bearing TOML configs become a real use case.

## Consequences

### Positive

- No new dependency or vendored code to maintain.
- Simplest possible serializer for the two keys this app edits.

### Negative / tradeoffs

- Saving a TOML config discards comments, whitespace, key order, and arrays-of-tables
  layout — a real drawback for hand-authored, commented TOML files.
- TOML is inconsistent with the JSON/YAML paths, which do preserve comments.
- Any UI that saves TOML should surface that comments may be lost rather than silently
  discarding them.

### Neutral

- If TOML files in practice are machine-generated or comment-free, the loss is moot.

## Alternatives considered

| Alternative | Sketch | Why deferred (not chosen now) |
|---|---|---|
| **A. Surgical text-splice (mirror the JSON path)** | Locate the `rules = [...]` and `permissions = [...]` assignments in `originalContent` and replace only their values, leaving the rest verbatim. Falls back to the current from-scratch rebuild when a key is absent or expressed as `[[rules]]`/`[[permissions]]` arrays-of-tables. | Preserves comments on untouched content and around the edited keys, bringing TOML to JSON/YAML parity **for the keys this app edits**. But the `toml` package exposes no source spans, so the locator must be written by hand (regex/line-scan) and correctly handle multi-line arrays and quoted-bracket edge cases. Still reformats the edited arrays themselves. Medium effort; do only if commented TOML is a real use case. |
| **B. Vendor a minimal comment-preserving TOML editor** | Add a `lib/vendor/toml_ast/` analogous to the vendored `json_ast`, exposing source offsets for a full source-preserving `serialize`. | Highest fidelity (full round-trip, all keys, arrays-of-tables intact), but real build-and-maintain cost for a two-key use case. Not justified now. |
| **C. Adopt/port `tomlkit`/`toml_edit` semantics** | Bring a style-preserving TOML library to Dart. | No mature Dart package exists; porting is out of scope. |
| **D. Status quo — from-scratch rebuild + warning** (chosen) | Keep `TomlDocument.fromMap(...).toString()` and the documented warning. | Lowest cost; acceptable if commented TOML is rare. This is the deferred default. |

## Follow-up trigger

Reopen this ADR and implement **Alternative A** if any of these occur:

- Users report lost comments after saving TOML configs.
- A supported tool ships hand-authored, comment-bearing TOML as its config format.
- The `toml` Dart package gains source-span or comment-preserving support (prefer that
  over hand-rolled splicing).

## References

- `lib/parsers/toml_config_parser.dart` — the lossy `serialize` + `**WARNING:**` doc comment
- `lib/parsers/json_config_parser.dart` + `lib/vendor/json_ast/` — source-splice pattern (Alternative A/B reference)
- `lib/parsers/yaml_config_parser.dart` — `yaml_edit` source-preserving pattern
- Qodo review finding #12

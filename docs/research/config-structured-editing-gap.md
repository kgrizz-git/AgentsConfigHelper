# Research: Config Structured Editing vs. Implementation Gap

**Date:** 2026-08-22
**Author:** Gemini

## Codex assessment and recommended direction

This assessment correctly identifies the central product gap: format-level parsing is
not enough to make tool-specific permissions and settings understandable or safely
editable. The raw editor is therefore an important safety fallback, not a failed UI.

Do not attempt a universal structured editor in one rewrite. First establish a
tool-schema layer that can describe extracted sections, their source paths, editability,
and authoritative documentation links. Deliver one narrow vertical slice for a
high-value, well-documented permission schema; initially show uncertain or complex
sections read-only. Enable editing only after fixture-based round-trip tests demonstrate
that an unchanged document remains byte-for-byte intact and an intended edit produces a
minimal, reviewable patch.

Each supported structured field should have an explicit safety contract: recognized
schema and version, raw fallback when unrecognized, comment/ordering preservation where
the format supports it, diff-preview coverage, backup/restore coverage, and a link to
the owning tool's documentation. Plain-language explanations belong in the same schema
metadata, after the first cards establish what information users actually need.

This document assesses the extent to which the repo documentation states the desired functionality for structured configuration editing, and analyzes where the current Dart implementation falls short of those goals.

## 1. What the Documentation States (Desired Functionality)

The repository documentation outlines an ambitious vision for how configuration files should be presented and edited:

* **Structured Presentation:** `TO_DO.md` explicitly calls to *"Expand parsers and UI models so supported configuration formats can present discovered rules, permissions, and settings as focused widgets/cards rather than only raw syntax."*
* **Schema Diversity:** `docs/supported-tools.md` catalogs a highly diverse set of schemas. It acknowledges that tools use different permission models:
  * **Allow/Ask/Deny arrays:** Claude, Antigravity
  * **Per-tool allow/ask/deny:** Opencode
  * **Capability-based:** Kiro
  * **Scope-based:** Devin
* **Raw Editor Fallback:** Both `TO_DO.md` and `.context/project-profile.md` state that there must be a faithful raw-editor fallback for unsupported or ambiguous content.
* **Markdown Exclusion:** `docs/supported-tools.md` explicitly excludes Markdown rules (like `AGENTS.md` and `.cursorrules`) from structured editing in V1, intentionally designating them for the raw-text editor.

## 2. Where the Actual Implementation Falls Short

After reviewing the Flutter/Dart source code (specifically `lib/models/`, `lib/parsers/`, and `lib/widgets/`), it is clear that the implementation is in an early "MVP" state and significantly lags behind the documented goals.

Here is the breakdown of the gaps:

### A. Lack of Tool-Specific Schema Parsing

The implementation currently uses generic format parsers (`JsonConfigParser`, `YamlConfigParser`, `TomlConfigParser`) rather than tool-specific schema parsers.

* The `ToolConfig` model (`lib/models/tool_config.dart`) reduces all structured configuration down to two flat arrays: `List<String> rules` and `List<String> permissions`.
* It has no semantic understanding of Opencode's nested tool maps vs. Kiro's capability arrays.

### B. Nested Permissions Trigger the Raw Fallback

Because the data model only supports flat string arrays, `JsonConfigParser` explicitly checks if the `permissions` field is a `List`.

* If a tool uses a nested object for permissions (e.g., Claude's `{"allow": [], "ask": [], "deny": []}`), the parser flags it (`preservesNestedPermissions = true`) and dumps it into a generic `rawSettings` map.
* The UI (`lib/widgets/config_editor.dart`) sees this via `_hasUnsupportedPermissions` and displays the message: *"Nested permissions are preserved but not editable here yet."*
* **Result:** Almost all of the major supported tools (Claude, Opencode, Kiro, Devin) currently bypass the structured UI and force the user into the raw text editor for their permissions.

### C. Missing "Widgets/Cards" UI

`TO_DO.md` requests "focused widgets/cards". However, `lib/widgets/config_editor.dart` currently only implements a generic `StringListEditor` for flat arrays. There are no specialized UI cards for "Allow/Ask/Deny" grids, no capability dropdowns, and no scope-based builder UIs.

### D. Safe Edits (AST Patching) is Limited

While `JsonConfigParser` does an excellent job of using an AST (Abstract Syntax Tree) to surgically patch flat `rules` and `permissions` arrays to preserve comments (JSONC), it completely gives up and rewrites the file from scratch if the structural patch fails. This isn't just a cosmetic formatting concern — for JSONC it drops comments and structural ordering, creating a real **data fidelity risk**.

### E. Round-trip Safety and Backup Semantics

The repository's core safety story (backup-before-write, diff preview) is weakened by this gap. If an unsupported nested-permission edit forces a full rewrite that drops comments, the diff preview will show massive, potentially destructive changes to the user's config file, eroding trust in the app's safety guarantees.

## 3. Summary & Recommendations

The documentation accurately describes the target end-state for a robust, schema-aware configuration manager. However, the actual codebase currently only implements **Phase 1**: generic parsing with a raw text fallback and very rudimentary structured editing limited to flat string arrays.

To achieve the goals in `TO_DO.md`, the app needs a robust schema mapping layer that sits *between* the format parsers (`json_config_parser.dart`) and the UI, translating tool-specific ASTs into rich Flutter view models. This work should be scoped into a new active plan in `plans/active/` to incrementally add schema awareness tool-by-tool.

---
*Note: This research document was reviewed and improved based on feedback from the `kilo/tencent/hy3:free` model.*

# Phase 2.5: Advanced Parsers (JSONC)

**Status:** Complete
**Dependency:** Phase 2 (Completed)

**Completion record:** `JsonConfigParser` now detects JSONC, preserves comments and
trailing commas for supported surgical edits, warns on `.json` JSONC fallback, and has
parser regression coverage. Archived on 2026-08-23.

**Goal:** Fix the currently broken `.jsonc` mapping by safely parsing and writing JSONC (JSON with Comments/Trailing Commas) configuration files, specifically supporting Opencode (`opencode.json`) and other IDE tools.

## The Problem

Standard `dart:convert` `jsonDecode` fails on comments (`//`, `/* */`) AND trailing commas. Naive regex stripping breaks string literals that contain these sequences. Furthermore, simply stripping comments before parsing means we delete the user's comments when we reserialize and save the file, destroying their annotations.

## Implementation Steps

1. **Trailing Comma & Comment Neutralization (Parse Phase)**
   - Before passing the string to `jsonDecode` to build the UI's `rawSettings`, we must neutralize trailing commas and comments.
   - We must build or adopt a strict Tokenizer that understands string boundaries to avoid mangling URLs (like `https://...`) or strings containing `//`, `/*`, or commas.

2. **AST-Based Editing (Serialize Phase)**
   - A bespoke substring-offset patcher is too fragile (key collisions, multi-edit shifting).
   - We must adopt a robust AST-patching approach (similar to how `yaml_edit` works in `YamlConfigParser`). We will either find a JSONC AST editor package or build a lightweight AST that supports querying by path and emitting multi-edit patches.
   - **Diff Computation:** The serialize step must compute a diff between `rawSettings` (the edited state) and the original AST to know what nodes to patch.
   - **Fallback Strategy:** If the AST patcher fails or cannot handle a complex structural change (e.g., adding a new key), it should safely fall back to a full from-scratch serialization, warning the UI/user that comments may be lost, rather than corrupting the file.

3. **Domain Updates & Plumbing**
   - Update `ConfigService.saveConfig` to actually read and pass `originalContent` to the parsers' `serialize` methods. Currently, it does not do this, which breaks the patching workflow.
   - Re-introduce `ConfigFormat.jsonc` to the `ConfigFormat` enum.
   - Define strict `.json` vs `.jsonc` detection: attempt strict `jsonDecode`; on failure, retry as JSONC; only then treat as JSONC.

4. **Testing**
   - **Trailing Commas:** Arrays and objects.
   - **String Literals:** `https://` and `"a // b"` survive untouched.
   - **Comments:** Line, block, and comments as values.
   - **Round-Trip:** Unchanged spans remain byte-for-byte identical.
   - **Mutations:** Single-value changes, key addition, key deletion, and identical-value disambiguation.
   - **Fallback:** Verify the fallback mechanism triggers on un-patchable states without corrupting the file.

5. **Documentation**
   - Update `ARCHITECTURE.md` to correct the false claim that JSONC is handled by `dart:convert`; describe the actual AST patcher approach.
   - Update `docs/supported-tools.md` to document the trailing comma support and comment preservation.

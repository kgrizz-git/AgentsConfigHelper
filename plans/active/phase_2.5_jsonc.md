# Phase 2.5: Advanced Parsers (JSONC)

**Goal:** Safely parse and write JSONC (JSON with Comments) configuration files, specifically supporting Opencode (`opencode.json` / `opencode.jsonc`) and other IDE tools that rely heavily on comment-annotated configurations.

## The Problem

Standard `dart:convert` `jsonDecode` fails on comments (`//`, `/* */`). Naive regex stripping breaks string literals that contain these sequences (like `$schema: "https://opencode.ai/config.json"`). Furthermore, simply stripping comments before parsing means we delete the user's comments when we reserialize and save the file, destroying their annotations.

## Implementation Steps

1. **Tokenizer & AST Design**
   - The Dart ecosystem lacks a drop-in replacement for Node's `jsonc-parser`. Packages like `json5` parse into a `Map`, which completely discards comments and whitespace metadata.
   - We cannot use a `String -> Map -> String` workflow.
   - We must build a lightweight Tokenizer that produces a list of tokens (`whitespace`, `lineComment`, `blockComment`, `string`, `bracket`) with exact string offsets.

2. **Domain Updates**
   - Re-introduce `ConfigFormat.jsonc` to the `ConfigFormat` enum.
   - Update `ConfigService._getParserForPath` to map `.jsonc` to the new parser (and potentially intercept `.json` files that are known to be JSONC, like Opencode configs).

3. **Parser Implementation (String Patching)**
   - Create `JsoncConfigParser` that implements our standard parser interface.
   - **Parse**: Strip comments temporarily *only* for the purpose of loading into `rawSettings` (so the UI has a standard Map to read).
   - **Serialize**: Instead of serializing `rawSettings` back into a string, build a Path Resolver to find the exact token offset of the value being changed, and perform a direct substring replacement on the original raw JSONC string. This leaves all other comments and whitespace untouched.

4. **Testing**
   - Create test fixtures with `https://` URLs and various block/line comments.
   - Ensure round-trip serialization (`parse` -> mutate -> `serialize`) successfully preserves the original comments.

5. **Documentation**
   - Update `ARCHITECTURE.md` and `docs/supported-tools.md` to reflect full JSONC support.

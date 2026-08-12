# Phase 2.5: Advanced Parsers (JSONC)

**Goal:** Safely parse and write JSONC (JSON with Comments) configuration files, specifically supporting Opencode (`opencode.json` / `opencode.jsonc`) and other IDE tools that rely heavily on comment-annotated configurations.

## The Problem

Standard `dart:convert` `jsonDecode` fails on comments (`//`, `/* */`). Naive regex stripping breaks string literals that contain these sequences (like `$schema: "https://opencode.ai/config.json"`). Furthermore, simply stripping comments before parsing means we delete the user's comments when we reserialize and save the file, destroying their annotations.

## Implementation Steps

1. **Package Evaluation**
   - Research and test robust JSONC Dart packages that can parse JSONC into a map, and serialize a map back into JSONC *while preserving the original comments*.
   - Potential packages to evaluate: `json5`, `commented_json`, or building a small AST-based comment-preserving tokenizer if no suitable package exists that handles serialization.

2. **Domain Updates**
   - Re-introduce `ConfigFormat.jsonc` to the `ConfigFormat` enum.
   - Update `ConfigService._getParserForPath` to map `.jsonc` to the new parser (and potentially intercept `.json` files that are known to be JSONC, like Opencode configs).

3. **Parser Implementation**
   - Create `JsoncConfigParser` that implements our standard parser interface.
   - Ensure the parser reads the file safely.
   - Ensure `serialize` merges the new values back into the original AST/string structure without dropping comments.

4. **Testing**
   - Create test fixtures with `https://` URLs and various block/line comments.
   - Ensure round-trip serialization (`parse` -> mutate -> `serialize`) successfully preserves the original comments.

5. **Documentation**
   - Update `ARCHITECTURE.md` and `docs/supported-tools.md` to reflect full JSONC support.

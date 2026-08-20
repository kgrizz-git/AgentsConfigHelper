# Plan: Phase 9 — Refining Existing Tools & Parser Integration

**Status:** Not started
**Last updated:** 2026-08-19
**Owner:** (unassigned)
**Depends on:** Phase 6 complete (archived 2026-08-19).

**Exit Criteria:** Build is green (`flutter analyze --fatal-infos` + `flutter test`), `docs/supported-tools.md` and the registry reconciled, `CHANGELOG.md` updated, and the mandatory independent review scheduled and written to `tmp/`.

## Context & Goal

This phase addresses the tool-support gaps and refactoring for **existing tools** identified during the audits. The goal is to audit and expand coverage for tools already in the registry, split multi-surface tools, and hook up deferred Markdown/Starlark sources to the raw-text editor.

*(Note: Adding entirely new tools like Kilo, Cline, Copilot, and LM Studio is deferred to Phase 10 to keep PR sizes manageable).*

## Workstream A: Audit & Coverage Gaps (Existing Tools)

**Goal:** Ensure the 9 tools already in the registry are fully covered across all their config and rules locations.

*Research protocol:* Check upstream documentation, inspect default installation paths on macOS/Linux/Windows, and record findings in `.context/research/2026-08-19-discovery-targets.md`. Be sure to identify correct Windows path equivalents (e.g., `%APPDATA%`, `%LOCALAPPDATA%`, `%USERPROFILE%`).

- [ ] **Kiro:** Confirm if a project-level `permissions.yaml` or equivalent exists. Currently only `.kiro/steering/*.md` is mapped. Add it if it exists.
- [ ] **Antigravity CLI:** Confirm if a project-level settings file exists upstream.
- [ ] **Agy-ACP / Zed contradiction:** Resolve the doc/code contradiction for Zed `agent_servers`. `supported-tools.md:657` documents it as part of Agy-ACP, but the registry omits it. Either add the cross-tool target or update the docs to mark it "documented but not auto-discovered."
- [ ] **Cursor (Agent):** We currently map `~/.cursor/permissions.json`. Confirm if a global user-scope `.cursorrules` equivalent exists and map it if so.
- [ ] **Codex:** Add missing Starlark rules paths (`~/.codex/rules/default.rules` and `.codex/rules/*.rules`) to the registry targets.
- [ ] **Sync:** Update `docs/supported-tools.md` to match any path additions from this audit. Ensure it explicitly lists whether each file is handled by a structured parser or the raw editor fallback.

## Workstream B: Tool Splitting (Refining Existing Tools)

**Goal:** Separate multi-surface products into distinct tool descriptor entries so their configs are discoverable independently.

- [ ] **Cursor Agent vs Cursor IDE:** Split the single `cursor` entry.
  - Create `cursorIde` for the IDE-level editor `settings.json`.
  - Keep `cursor` for agent permissions and instructions (`.cursorrules`, `.cursor/rules/*.mdc`).
  - *UI Consideration:* Files claimed by multiple ToolIds (or duplicate user-added paths) should display both icons/labels in the UI. Explicitly verify the deduplication logic handles this cleanly.
- [ ] **Antigravity Surfaces:** Split the current `antigravity` entry.
  - Add distinct descriptors for **Antigravity IDE**, **Antigravity desktop app**, and keep the existing for the **`agy` CLI** settings.
  - Note: `agyAcp` is already modeled separately and should remain so.
- [ ] **Exhaustive Enum Check:** Grep the codebase for `switch (toolId)` or direct `ToolId` comparisons (e.g., in UI icon mappers) and extend them to handle the newly split enums.

## Workstream C: Markdown & Starlark Discovery (Parser Integration)

**Goal:** Hook the deferred sources into the discovery service and raw-text editor (which shipped in Phase 5).

- [ ] **ConfigFormat Mapping:** Change the `ConfigFormat` mapping in the registry for Starlark (`.rules`) and plain text (`.cursorrules`) to `text` so they route safely to the raw editor.
- [ ] **Markdown Rules Discovery:** Explicitly add new `ConfigTarget` entries for `GEMINI.md`, Codex `.rules`, and Devin `.devin/rules/*.md` to the registry. Note: glob patterns must match the canonical upstream filename casing.
- [ ] **Parser Registry Update:** Ensure `ToolDescriptorRegistry.catalog` reflects all supported tools and deferred sources.

## Workstream D: Verification & Migration

**Goal:** Ensure existing tool configurations continue to parse correctly after registry refactoring, and handle migration gracefully.

- [ ] **Regression Test:** Ensure existing tool configurations continue to parse correctly after registry refactoring.
- [ ] **Documentation Sync:** Run a final consistency check between `docs/supported-tools.md` and the registry.
- [ ] **Changelog:** Add an entry to `CHANGELOG.md` detailing the sidebar splits (these are user-facing changes).
- [ ] **Config Migration Check:** Since no `ToolId` is persisted to disk, migration is purely a discovery-regression issue. Verify that discovery still seamlessly picks up paths that were previously under the old unified descriptors.
- [ ] **TO_DO Cleanup:** Remove completed Phase 9 items from `TO_DO.md`.
- [ ] **Phase Review:** Spawn a fresh agent to perform the mandatory independent review. The reviewer must write its severity-rated verdict to `tmp/` (timestamped) per `AGENTS.md`.

## Implementation Notes

- All tool additions must be reflected in `lib/catalog/tool_descriptor_registry.dart`.
- Any new file formats (or non-structured files like Markdown) should route gracefully to the raw editor if no structured parser exists.

**Test Strategy:**

- Add unit tests for `ConfigTarget.isMatch` specifically covering new glob patterns (e.g., `.cursor/rules/*.mdc`, `.devin/rules/*.md`).
- Add tests to resolve case-sensitivity semantics (does `discovery_service.dart` dedup case-insensitively on Windows while `isMatch` is strictly case-sensitive?).
- Add cross-platform path tests targeting the home-path *expansion* function, verifying it returns the correct canonical string for Windows vs macOS/Linux.
- Add union/deduplication tests for split tools (e.g., if `cursor` and `cursorIde` claim the same path, ensure provenance unions safely).
- Add registry completeness invariants: (1) no two descriptors claim the same exact `(relativePath, scope, kind)` target unless intentional overlap, and (2) every structured-config target has a corresponding parser.
- Add an invariant test ensuring `ConfigFormat.markdown` and `ConfigFormat.text` are **never** routed to a structured parser.

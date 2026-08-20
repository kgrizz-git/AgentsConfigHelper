# Plan: Phase 9 — Tool Support Expansion & Ecosystem Gaps

**Status:** Not started
**Last updated:** 2026-08-19
**Owner:** (unassigned)
**Depends on:** Phase 6 complete (archived 2026-08-19).

**Exit Criteria:** Build is green (`flutter analyze --fatal-infos` + `flutter test`), `docs/supported-tools.md` and the registry reconciled, `README.md` table synced, `CHANGELOG.md` updated, Phase 9 items removed from `TO_DO.md`, and the mandatory independent review scheduled and written to `tmp/`.

## Context & Goal

This phase addresses the tool-support gaps identified during the 2026-08-16 and 2026-08-17 audits (currently tracked in `TO_DO.md`). The goal is to make the `ToolDescriptorRegistry` comprehensive for all supported tools, ensure we cover both user and project scopes completely, and introduce new requested tools.

Because the work is additive and modifies many tools, it is split into focused workstreams.

## Workstream A: Audit & Coverage Gaps (Existing Tools)

**Goal:** Ensure the 9 tools already in the registry are fully covered across all their config and rules locations.

*Research protocol:* Check upstream documentation, inspect default installation paths on macOS/Linux/Windows, and record findings in `.context/research/2026-08-19-discovery-targets.md`. Be sure to identify correct Windows path equivalents (e.g., `%APPDATA%`, `%LOCALAPPDATA%`, `%USERPROFILE%`) rather than just POSIX paths.

- [ ] **Kiro:** Confirm if a project-level `permissions.yaml` or equivalent exists. Currently only `.kiro/steering/*.md` is mapped. Add it if it exists.
- [ ] **Antigravity CLI:** Confirm if a project-level settings file exists upstream.
- [ ] **Agy-ACP / Zed contradiction:** Resolve the doc/code contradiction for Zed `agent_servers`. `supported-tools.md:657` documents it as part of Agy-ACP, but the registry omits it. Either add the cross-tool target or update the docs to mark it "documented but not auto-discovered."
- [ ] **Cursor (Agent):** We currently map `~/.cursor/permissions.json`. Confirm if a global user-scope `.cursorrules` equivalent exists and map it if so.
- [ ] **Codex:** Add missing Starlark rules paths (`~/.codex/rules/default.rules` and `.codex/rules/*.rules`) to the registry targets.
- [ ] **Re-verify:** Check each tool's paths against upstream documentation. Refresh `.context/research/2026-08-19-discovery-targets.md`.
- [ ] **Sync:** Update `docs/supported-tools.md` and the `README.md` table to match any path additions from this audit. Ensure `docs/supported-tools.md` explicitly lists whether each file is handled by a structured parser or the raw editor fallback.

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

## Workstream C: New Tools (Expansion)

**Goal:** Add first-class support for new requested tools.

- [ ] **Research/Verify:** Explicitly research documentation for these tools to replace placeholder paths with accurate metadata (including cross-platform paths). If they use unknown formats (e.g. INI, HCL), map them to the raw-text editor or define a parser requirement.
- [ ] **Kilo:** Add `ToolId` and config paths. Update `docs/supported-tools.md` and the `README.md` table.
- [ ] **Cline:** Add `ToolId` and config paths. Update `docs/supported-tools.md` and the `README.md` table.
- [ ] **LM Studio:** Add `ToolId` and config paths (local LLM runner with model management and API server settings). Update `docs/supported-tools.md` and the `README.md` table.
- [ ] **VS Code / GitHub Copilot:** Promote from deferred docs-only to a first-class `ToolDescriptor`. Add `.github/copilot-instructions.md`. Update `docs/supported-tools.md` and the `README.md` table.
- [ ] **Exhaustive Enum Check:** Grep the codebase for `switch (toolId)` or direct `ToolId` comparisons (e.g., in UI icon mappers) and extend them to handle the new enum values.
- [ ] **Parser Routing:** Verify each new tool routes to the correct format/editor (structured parser only where one exists).

## Workstream D: Markdown & Starlark Discovery (Parser Integration)

**Goal:** Hook the deferred sources into the discovery service and raw-text editor (which shipped in Phase 5).

- [ ] **ConfigFormat Mapping:** Change the `ConfigFormat` mapping in the registry for Starlark (`.rules`) and plain text (`.cursorrules`) to `text` so they route safely to the raw editor.
- [ ] **Markdown Rules Discovery:** Explicitly add new `ConfigTarget` entries for `GEMINI.md`, Codex `.rules`, and Devin `.devin/rules/*.md` to the registry. Note: glob patterns must match the canonical upstream filename casing.
- [ ] **Parser Registry Update:** Ensure `ToolDescriptorRegistry.catalog` reflects all supported tools and deferred sources.

## Workstream E: Verification & Migration

**Goal:** Ensure existing tool configurations continue to parse correctly after registry refactoring, and handle migration gracefully.

- [ ] **Regression Test:** Ensure existing tool configurations continue to parse correctly after registry refactoring.
- [ ] **Hook Integration:** Check if any of the new paths (like Kilo's or Cline's rules files) should be ignored or monitored by the `gitleaks` or `hygiene` hooks.
- [ ] **Documentation Sync:** Run a final consistency check between `docs/supported-tools.md`, the registry, and the `README.md` table.
- [ ] **Changelog:** Add an entry to `CHANGELOG.md` detailing the new tool support and sidebar splits (these are user-facing changes).
- [ ] **Config Migration Check:** Since no `ToolId` is persisted to disk, migration is purely a discovery-regression issue. Verify that discovery still seamlessly picks up paths that were previously under the old unified descriptors.
- [ ] **TO_DO Cleanup:** Remove all completed Phase 9 items from the "Tool-support gaps" section of `TO_DO.md`.
- [ ] **Phase Review:** Spawn a fresh agent to perform the mandatory independent review. The reviewer must write its severity-rated verdict to `tmp/` (timestamped) per `AGENTS.md`.

## Implementation Notes

- All tool additions must be reflected in `lib/catalog/tool_descriptor_registry.dart`.
- Any new file formats (or non-structured files like Markdown) should route gracefully to the raw editor if no structured parser exists.
- Update `docs/supported-tools.md` concurrently with registry changes.
- Cross-tool shared files (like `AGENTS.md`) are expected to be duplicated across tools at project scope; `DiscoveryService` dedups by path and unions provenance automatically.

**Test Strategy:**

- Add unit tests for `ConfigTarget.isMatch` specifically covering new glob patterns (e.g., `.cursor/rules/*.mdc`, `.devin/rules/*.md`).
- Add tests to resolve case-sensitivity semantics (e.g., does `discovery_service.dart` dedup case-insensitively on Windows while `isMatch` is strictly case-sensitive? Write a test to prove the behavior).
- Add cross-platform path tests targeting the home-path *expansion* function (not just injecting raw env vars), verifying the function returns the correct canonical string for Windows vs macOS/Linux.
- Add union/deduplication tests for split tools (e.g., if `cursor` and `cursorIde` claim the same path, ensure provenance unions safely).
- Add registry completeness invariants: (1) no two descriptors claim the same exact `(relativePath, scope, kind)` target unless intentional overlap, and (2) every structured-config target has a corresponding parser.
- Add an invariant test ensuring `ConfigFormat.markdown` and `ConfigFormat.text` are **never** routed to a structured parser.
- Add `DiscoveryService` integration tests for the newly added tools.

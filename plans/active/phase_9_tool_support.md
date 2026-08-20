# Plan: Phase 9 — Tool Support Expansion & Ecosystem Gaps

**Status:** Not started
**Last updated:** 2026-08-19
**Owner:** (unassigned)
**Depends on:** Phase 6 complete (archived 2026-08-19).

**Exit Criteria:** Build is green (`flutter analyze --fatal-infos` + `flutter test`), `docs/supported-tools.md` and the registry reconciled, and the mandatory independent review scheduled.

## Context & Goal

This phase addresses the tool-support gaps identified during the 2026-08-16 and 2026-08-17 audits (currently tracked in `TO_DO.md`). The goal is to make the `ToolDescriptorRegistry` comprehensive for all supported tools, ensure we cover both user and project scopes completely, and introduce new requested tools.

Because the work is additive and modifies many tools, it is split into focused workstreams.

## Workstream A: Audit & Coverage Gaps (Existing Tools)

**Goal:** Ensure the 9 tools already in the registry are fully covered across all their config and rules locations.

- [ ] **Kiro:** Confirm if a project-level `permissions.yaml` or equivalent exists. Currently only `.kiro/steering/*.md` is mapped. Add it if it exists.
- [ ] **Antigravity CLI:** Confirm if a project-level settings file exists upstream.
- [ ] **Agy-ACP:** Determine whether the host ACP config (e.g. Zed `agent_servers`) belongs in our config scope.
- [ ] **Cursor (Agent):** We currently map `~/.cursor/permissions.json`. Confirm if a global user-scope `.cursorrules` equivalent exists and map it if so.
- [ ] **Re-verify:** Check each tool's paths against upstream documentation. Refresh `.context/research/2026-08-13-discovery-targets.md`.
- [ ] **Sync:** Update `docs/supported-tools.md` and the `README.md` table to match any path additions from this audit.

## Workstream B: Tool Splitting (Refining Existing Tools)

**Goal:** Separate multi-surface products into distinct tool descriptor entries so their configs are discoverable independently.

- [ ] **Cursor Agent vs Cursor IDE:** Split the single `cursor` entry.
  - Create `cursorIde` for the IDE-level editor `settings.json`.
  - Keep `cursor` for agent permissions and instructions (`.cursorrules`, `.cursor/rules/*.mdc`).
- [ ] **Antigravity Surfaces:** Split the current `antigravity` entry.
  - Add distinct descriptors for **Antigravity IDE**, **Antigravity desktop app**, and keep the existing for the **`agy` CLI** settings.
  - Note: `agyAcp` is already modeled separately and should remain so.

## Workstream C: New Tools (Expansion)

**Goal:** Add first-class support for new requested tools.

- [ ] **Research/Verify:** Check upstream documentation/schemas for these tools before adding to ensure accurate paths and metadata.
- [ ] **Kilo:** Add `ToolId` and config paths. Update `docs/supported-tools.md`.
- [ ] **Cline:** Add `ToolId` and config paths. Update `docs/supported-tools.md`.
- [ ] **LM Studio:** Add `ToolId` and config paths (local LLM runner with model management and API server settings). Update `docs/supported-tools.md`.
- [ ] **VS Code / GitHub Copilot:** Promote from deferred docs-only to a first-class `ToolDescriptor`. Add `.github/copilot-instructions.md`. Update `docs/supported-tools.md`.
- [ ] **Parser Validation:** Verify each new tool routes to the correct format/editor (structured parser only where one exists) and add registry unit tests for the new targets.

## Workstream D: Markdown & Starlark Discovery (Parser Integration)

**Goal:** Hook the deferred sources into the discovery service and raw-text editor (which shipped in Phase 5).

- [ ] **Markdown Rules Discovery:** Explicitly add new `ConfigTarget` entries for `GEMINI.md`, Codex `.rules`, and Devin `.devin/rules/*.md`, alongside existing ones like `AGENTS.md`, `CLAUDE.md`, Kiro steering, and Cursor `.mdc`.
- [ ] **Starlark & Plain Text Support:** Hook Codex `.rules` and deprecated Cursor `.cursorrules` into the raw-text editor.
- [ ] **Parser Registry Update:** Ensure `ToolDescriptorRegistry.catalog` reflects all supported tools and deferred sources.

## Workstream E: Verification & Migration

**Goal:** Ensure existing tool configurations continue to parse correctly after registry refactoring, and handle migration gracefully.

- [ ] **Config Migration Path:** Define how the registry split of `antigravity` and `cursor` handles backward compatibility for discovery and display (e.g., sidebar labels and dedupe behavior). *Note: There is no persisted user state keyed by `ToolId` to migrate.*
- [ ] **Regression Test:** Ensure existing tool configurations continue to parse correctly after registry refactoring.
- [ ] **Hook Integration:** Check if any of the new paths (like Kilo's or Cline's rules files) should be ignored or monitored by the `gitleaks` or `hygiene` hooks.
- [ ] **Documentation Sync:** Run a final consistency check between `docs/supported-tools.md` and `lib/catalog/tool_descriptor_registry.dart` to ensure all paths, formats, and permissions are correctly mapped.
- [ ] **Phase Review:** Schedule the mandatory "independent review" as defined in `AGENTS.md` upon completion of this phase.

## Implementation Notes

- All tool additions must be reflected in `lib/catalog/tool_descriptor_registry.dart`.
- Any new file formats (or non-structured files like Markdown) should route gracefully to the raw editor if no structured parser exists.
- Update `docs/supported-tools.md` concurrently with registry changes.
- Add unit tests for the registry and discovery service for the newly added paths.
- Cross-tool shared files (like `AGENTS.md`) are expected to be duplicated across tools at project scope; `DiscoveryService` dedups by path and unions provenance automatically.

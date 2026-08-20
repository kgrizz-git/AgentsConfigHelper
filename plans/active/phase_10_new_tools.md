# Plan: Phase 10 — Ecosystem Expansion (New Tools)

**Status:** Not started
**Last updated:** 2026-08-19
**Owner:** (unassigned)
**Depends on:** Phase 9 complete.

**Exit Criteria:** Build is green (`flutter analyze --fatal-infos` + `flutter test`), `docs/supported-tools.md` and the registry reconciled, `README.md` table synced, `CHANGELOG.md` updated, Phase 10 items removed from `TO_DO.md`, and the mandatory independent review scheduled and written to `tmp/`.

## Context & Goal

This phase adds first-class support for new requested tools (Kilo, Cline, LM Studio, and GitHub Copilot) to the `ToolDescriptorRegistry`. This phase intentionally follows the registry refactoring and test-hardening completed in Phase 9.

## Workstream A: Research & Path Verification

**Goal:** Determine the exact cross-platform paths and formats for the new tools.

- [ ] **Kilo:** Research global and project-level config/rules paths. Identify Windows path equivalents.
- [ ] **Cline:** Research global and project-level config/rules paths. Identify Windows path equivalents.
- [ ] **LM Studio:** Research local LLM runner model management and API server settings paths.
- [ ] **GitHub Copilot:** Research `.github/copilot-instructions.md` and any global settings equivalents.
- [ ] **Record Findings:** Document the discovered paths in `.context/research/2026-08-19-new-tools-paths.md`.

## Workstream B: Tool Integration

**Goal:** Add the new tools to the registry.

- [ ] **Enum Additions:** Add `kilo`, `cline`, `lmStudio`, and `copilot` to the `ToolId` enum.
- [ ] **Exhaustive Enum Check:** Grep the codebase for `switch (toolId)` or direct `ToolId` comparisons (e.g., in UI icon mappers) and extend them to handle the new enum values.
- [ ] **Registry Update:** Add the new tools to `ToolDescriptorRegistry.catalog` using the researched paths.
- [ ] **Parser Routing:** Verify each new tool routes to the correct format/editor. If any use unknown formats (e.g. INI, HCL), map them to the raw-text editor or define a parser requirement.

## Workstream C: Verification & Migration

**Goal:** Ensure the new tools integrate smoothly into the UI and discovery pipeline.

- [ ] **Hook Integration:** Check if any of the new paths (like Kilo's or Cline's rules files) should be ignored or monitored by the `gitleaks` or `hygiene` pre-commit hooks.
- [ ] **Documentation Sync:** Update `docs/supported-tools.md` and the `README.md` table to list the newly supported tools.
- [ ] **Changelog:** Add an entry to `CHANGELOG.md` detailing the new tool support.
- [ ] **TO_DO Cleanup:** Remove completed Phase 10 items from the "Tool-support gaps" section of `TO_DO.md`.
- [ ] **Phase Review:** Spawn a fresh agent to perform the mandatory independent review. The reviewer must write its severity-rated verdict to `tmp/` (timestamped) per `AGENTS.md`.

## Implementation Notes

- All tool additions must be reflected in `lib/catalog/tool_descriptor_registry.dart`.
- Ensure new glob patterns match the canonical upstream filename casing.

**Test Strategy:**

- Update registry completeness assertions (e.g., every `ToolId` has at least one valid target).
- Add `DiscoveryService` integration tests for the newly added tools.
- Add unit tests for `ConfigTarget.isMatch` specifically covering any new glob patterns introduced by these tools.

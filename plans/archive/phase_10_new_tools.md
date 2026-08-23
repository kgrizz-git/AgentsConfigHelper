# Plan: Phase 10 — Ecosystem Expansion (New Tools)

**Status:** Complete
**Last updated:** 2026-08-23
**Owner:** (unassigned)
**Depends on:** Phase 9 complete.

**Exit Criteria:** Build is green (`flutter analyze --fatal-infos` + `flutter test`), `docs/supported-tools.md` and the registry reconciled, `README.md` table synced, `CHANGELOG.md` updated, and Phase 10 items removed from `TO_DO.md`.

**Completion record:** Exit criteria were met and the plan was archived on 2026-08-23.

## Context & Goal

This phase adds first-class support for new requested tools (Kilo, Cline, LM Studio, and GitHub Copilot) to the `ToolDescriptorRegistry`. This phase intentionally follows the registry refactoring and test-hardening completed in Phase 9.

## Workstream A: Research & Path Verification

**Goal:** Determine the exact cross-platform paths and formats for the new tools.

- [x] **Kilo:** Research global and project-level config/rules paths. Identify Windows path equivalents.
- [x] **Cline:** Research global and project-level config/rules paths. Identify Windows path equivalents.
- [x] **LM Studio:** Research local LLM runner model management and API server settings paths.
- [x] **GitHub Copilot:** Research `.github/copilot-instructions.md` and any global settings equivalents.
- [x] **Record Findings:** Document the discovered paths in `docs/research/2026-08-19-new-tools-paths.md`.

## Workstream B: Tool Integration

**Goal:** Add the new tools to the registry.

- [x] **Enum Additions:** Add `kilo`, `cline`, `lmStudio`, and `copilot` to the `ToolId` enum.
- [x] **Exhaustive Enum Check:** Grep the codebase for `switch (toolId)` or direct `ToolId` comparisons (e.g., in UI icon mappers) and extend them to handle the new enum values.
- [x] **Registry Update:** Add the new tools to `ToolDescriptorRegistry.catalog` using the researched paths.
- [x] **Parser Routing:** Verify each new tool routes to the correct format/editor. If any use unknown formats (e.g. INI, HCL), map them to the raw-text editor or define a parser requirement.

## Workstream C: Verification & Migration

**Goal:** Ensure the new tools integrate smoothly into the UI and discovery pipeline.

- [x] **Secret Handling Policy:** Define a security policy for secret-bearing files (e.g., Kilo's `kilo.jsonc` / optional `models.json`, Cline `providers.json`). Backups of secret-bearing files must be routed to the app's secure global backup directory rather than writing a `.bak` file into the project directory, to guarantee they are never accidentally committed. Add regression tests for this behavior.
- [x] **Hook Integration:** Check if any of the new paths (like Kilo's or Cline's rules files) should be ignored or monitored by the `gitleaks` or `hygiene` pre-commit hooks.
- [x] **Documentation Sync:** Update `docs/supported-tools.md` and the `README.md` table to list the newly supported tools.
- [x] **Changelog:** Add an entry to `CHANGELOG.md` detailing the new tool support.
- [x] **TO_DO Cleanup:** Remove completed Phase 10 items from the "Tool-support gaps" section of `TO_DO.md`.

## Implementation Notes

- All tool additions must be reflected in `lib/catalog/tool_descriptor_registry.dart`.
- Ensure new glob patterns match the canonical upstream filename casing.
- Review follow-ups (2026-08-20): LM Studio hub globs use `models/*/*/…` (publisher/model); Cline discovers `.clinerules/` directories; discovery glob walks use recursive listing with match + visit caps and `followLinks: false`.
- Shared project `AGENTS.md` is a separate `ToolId.agentsMd` catalog entry (not owned by Kilo/Codex/etc.).
- CodeRabbit follow-ups (2026-08-20): Copilot editable settings use `settings.json` (user + `.github/copilot/`); `config.json` kept as managed state; Windows `**/` matching canonicalizes separators; discovery caps are injectable; glob listing uses per-entry `handleError`.

**Test Strategy:**

- Update registry completeness assertions (e.g., every `ToolId` has at least one valid target).
- Add `DiscoveryService` integration tests for the newly added tools.
- Add unit tests for `ConfigTarget.isMatch` specifically covering any new glob patterns introduced by these tools.

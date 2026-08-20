# Phase 9: Audit & Coverage Gaps (Existing Tools)

**Date:** 2026-08-19

## Kiro

- **Project-Level Permissions:** Stored out-of-tree for security at `~/.kiro/workspace-roots/<hash>/permissions.yaml`. (May be difficult to auto-discover based purely on the current working directory).
- **Global Permissions:** `~/.kiro/settings/permissions.yaml`

## Antigravity CLI

- **Project-Level Config:** There is no `.agyrc` or `agy.yaml`. It strictly uses project directories like `.agents/`, `AGENTS.md`, and `mcp_config.json`.
- **Global Settings:** `~/.gemini/antigravity-cli/settings.json`

## Cursor

- **Global Rules:** There is no global `.cursorrules` file on disk. Global rules are managed in the UI ("Rules for AI") and cloud-synced. Project-level rules (`.cursor/rules/*.mdc` and `.cursorrules`) are the only ones on disk.

## Codex

- **Starlark Rules:** `~/.codex/rules/default.rules` and `.codex/rules/*.rules`

## Antigravity

- **Project Rules:** `GEMINI.md`

## Devin

- **Project Rules:** `.devin/rules/*.md`

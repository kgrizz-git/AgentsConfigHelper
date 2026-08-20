# Changelog

All notable **user-facing** changes to AgentsConfigHelper are documented here.
Developer-only changes (hooks internals, tests/CI) live in
[`CHANGELOG.dev.md`](CHANGELOG.dev.md). See [`policies/changelog-conventions.md`](policies/changelog-conventions.md).

The format follows [Keep a Changelog](https://keepachangelog.com/), and this project
uses [Semantic Versioning](https://semver.org/).

## Unreleased

### Added
- **Expanded configuration discovery:** Added auto-discovery and raw-text editing support for Antigravity's `GEMINI.md`, Codex's Starlark `.rules` files, and Devin's `.devin/rules/*.md`.
- **Tool Sidebar Refinement:** Cursor has been split into 'Cursor IDE' and 'Cursor Agent' to cleanly separate the IDE settings from the agent constraints. Antigravity has been split into 'Antigravity IDE', 'Antigravity App', and 'Antigravity CLI' to provide accurate file discovery for each distinct tool surface.

- **Corrupted-config recovery.** When a config file fails to parse, a recovery dialog
  offers: open the file in a raw text editor, view backups, skip, and (for manually-added
  files) remove. The app never auto-overwrites a corrupted on-disk file.
- **Position-accurate parse errors.** Parse failures now report the 1-based line and column
  for JSON, JSONC, YAML, and TOML (derived from the underlying parser exception).
- **JSONC fallback warning.** When a `.json` file contains comments or trailing commas and is
  silently treated as JSONC, a non-blocking banner informs the user.
- **Open Backups Folder** menu action in the sidebar that opens the app's
  timestamped backups directory in the platform file manager.

### Fixed

- **Restore safety.** Restoring a backup now preserves the current on-disk file as a new
  backup first (the existing file is backed up before the snapshot is applied), and recreates
  a missing parent directory (for example after the live config folder was deleted), matching
  `BackupService.restoreBackup`.
- Manual-path removal now works for files also discovered via catalog auto-detection
  (dual-provenance). The sidebar Remove button appears for these files, and removing
  the manual entry keeps the catalog-backed entry instead of silently no-op'ing or
  re-detecting the file after refresh.
- Removing a manual-only configuration that has unsaved edits now asks for discard
  confirmation before clearing the editor (matching load/restore behavior); cancelling
  leaves both the editor and the manual-path preference unchanged.

## [0.1.0] - 2026-08-17

### Added

- Initial release of AgentsConfigHelper.
- **Config discovery** — auto-detects agent/IDE configuration files across 9 tools
  (Claude Code, Codex, Opencode, Paseo, Cursor, Kiro, Devin, Antigravity, Agy-ACP)
  on macOS, Windows, and Linux. Users can also add custom paths manually.
- **Structured config editing** — comment-preserving edits for JSON, JSONC, YAML, and
  TOML configuration files via AST-based string patching (`json_ast`, `yaml_edit`).
- **Instruction document editing** — raw text editing for Markdown/text files
  (`CLAUDE.md`, `AGENTS.md`, `.mdc` rules, etc.) with no reformatting.
- **Diff preview** — diff view before every write, with truncation at 20 lines and an
  expand control for large files.
- **Timestamped backup and restore** — automatic backup before every write, stored in
  a centralized app-support directory. Up to 10 snapshots per original path are
  retained (older ones pruned best-effort). One-click restore from the History &
  Backups view.
- **Cross-platform desktop UI** — Flutter/Dart application targeting macOS, Windows,
  and Linux with Riverpod state management, dark/light theme, and a sidebar-driven
  shell.
- **CI quality gates** — `dart format`, `flutter analyze --fatal-infos`, 80% minimum
  line coverage, `gitleaks` secret scan, `semgrep` SAST, and a 3-OS release build
  matrix.

# AgentsConfigHelper 0.1.1 — Release Notes

> **This is a local build.** It is not a GitHub release, and is not code-signed, notarized,
> or distributed through any app store. Run from source or build locally with
> `flutter build <platform> --release`.

---

## What is AgentsConfigHelper?

A cross-platform (macOS, Windows, Linux) Flutter desktop app for visualizing, editing, and
managing configuration settings, rules, and permissions for AI agents and IDEs. Provided
"as is," without warranty. Pre-1.0, under active development.

---

## Safety model

**Backup-before-write is always on.** Every file write creates a timestamped backup
snapshot before modifying the original. Up to 10 snapshots per original path are retained
(older ones pruned best-effort). One-click restore is available from the History & Backups
view. Restoring a backup preserves the current file first (the existing file is backed up
before the snapshot is applied), so no data is lost.

---

## Supported tools (9)

AgentsConfigHelper auto-discovers and edits configuration files for the following tools,
registered in `ToolDescriptorRegistry`:

| Tool | Formats | Config model |
| --- | --- | --- |
| Claude Code | JSON, Markdown | allow/ask/deny arrays |
| Codex | TOML, Markdown | sandbox + permission profiles |
| Opencode | JSONC, Markdown | per-tool allow/ask/deny |
| Paseo | JSON | delegated to provider |
| Cursor | JSON, text, Markdown | allowlist + classifier |
| Kiro | YAML, Markdown | capability-based |
| Devin | JSON, Markdown | scope-based allow/deny |
| Antigravity | JSON, Markdown | action(target) + presets |
| Agy-ACP | JSON | ACP permission bridge |

Full config-path and format reference: [`docs/supported-tools.md`](supported-tools.md).

---

## What's new in 0.1.1

### Added

- **"Open Backups Folder"** menu action in the sidebar that opens the app's timestamped
  backups directory in the platform file manager.

### Fixed

- **Backup restore handles missing directories.** Restoring a backup now recreates the
  parent directory if it was deleted (e.g. the live config folder no longer exists).
- **Restore safety (from the History & Backups view).** Restoring a backup now preserves the
  current on-disk file as a new backup first, so the pre-restore state is never lost.

### Improved (Phase 6A — corrupted-config recovery)

- **Recovery dialog for parse failures.** When a config file fails to parse, a recovery
  dialog offers: Open raw editor, View backups, Skip, and (for manually-added files)
  Remove. The app never auto-overwrites a corrupted on-disk file.
- **Line/column error reporting.** Parse errors now include position information
  (line and column) for JSON, YAML, and TOML, derived from the underlying parser
  exceptions.
- **JSONC fallback warning.** When a `.json` file contains comments or trailing commas and
  is silently parsed as JSONC, a non-blocking banner now informs the user.

### Fixed (Phase 6B — manual-path removal)

- **Manual-path removal correctly handles dual-provenance files.** Files discovered via
  both catalog auto-detection and manual user paths can now have their manual entry removed
  independently; the catalog entry is preserved. The Remove button correctly appears for
  these dual-provenance files.

---

## Known limitations

- **TOML comment loss on raw re-serialize.** The TOML parser/serializer does not preserve
  comments on round-trip. This is a known limitation tracked separately (see ADR in
  `lib/parsers/toml_config_parser.dart`).
- **Corrupted-config recovery never auto-overwrites.** If a config file fails to parse,
  the app offers a raw editor, view-backups, or skip — it will never silently overwrite
  the on-disk file with re-serialized content.
- **Screenshot: pending** (user-captured screenshot still blocked — see
  [`TO_DO.md`](../TO_DO.md)).

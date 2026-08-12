# Phase 2: Services & Discovery

## 1. DiscoveryService

Responsible for locating supported agent config files across the host OS.

- **Dependencies**: `path_provider` (for cross-platform AppData/Home directory access).
- **Behavior**:
  - Exposes `Future<List<String>> discoverConfigs()`
  - Uses the `docs/supported-tools.md` "Detection priority" list to map out default locations:
    1. `~/.claude/settings.json` (Claude Code)
    2. `~/.codex/config.toml` (Codex)
    3. `~/.config/opencode/opencode.json` (Opencode)
    4. `~/.paseo/config.json` (Paseo)
    5. `~/.cursor/permissions.json` (Cursor)
    6. `~/.kiro/settings/permissions.yaml` (Kiro)
    7. `~/.config/devin/config.json` (Devin)
    8. `~/.gemini/antigravity-cli/settings.json` (Antigravity)
    9. `~/.openab/agy-acp/sessions.json` (agy-acp)
  - Resolves `~` to the correct platform home directory (`Platform.environment['HOME']` or `%USERPROFILE%`).

## 2. BackupService

Responsible for implementing the strict "backup-before-write" safety policy.

- **Behavior**:
  - `Future<String> createBackup(String originalPath)` (uses `File.copy()` to grab the true on-disk state)
  - `Future<void> restoreBackup(String backupPath, String targetPath)`
- **Backup Location**:
  - To avoid polluting user tool directories (which are often tracked in Git dotfiles), backups will be stored in our own centralized app data directory via `path_provider`'s `getApplicationSupportDirectory()`.
  - Directory: `<app_support_dir>/backups/`
  - Filename format: `<original_filename>_<timestamp>.bak`
  - Maintains an index/mapping of which backup belongs to which original absolute path.

## 3. ConfigService (The Facade)

Orchestrates the parsers from Phase 1 alongside discovery and backups.

- **Behavior**:
  - `Future<ToolConfig> loadConfig(String path)`: Discovers format by extension/tool, invokes parser.
  - `Future<void> saveConfig(ToolConfig config)`: Calls `BackupService.createBackup` on existing file -> Calls `parser.serialize` -> Writes safely to disk.

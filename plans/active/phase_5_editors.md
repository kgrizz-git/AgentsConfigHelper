# Phase 5: Editors, Diff Viewers, and Backups

**Status:** Active
**Goal:** Implement the raw configuration editor, line-level diffing, and wire up the Backup & Restore UI.

## Requirements

1. **Raw Text Editor Fallback:**
   - In `ConfigEditor`, there is a "Raw JSON/YAML Editor Coming Soon" placeholder or tab.
   - Replace this with a real multi-line text editor (`TextField` with `maxLines: null`) that allows users to edit the raw string content of the configuration file.
   - When saving from the raw editor, it should write the content back to disk (and trigger a backup via `ConfigService`).

2. **History & Backups View:**
   - The "History & Backups" button currently shows a "coming soon" snackbar.
   - Implement a new modal or side-panel that lists available backups for the current file using `BackupService.listBackups()`.
   - Allow the user to select a backup and restore it using `BackupService.restoreBackup()`.

3. **Visual Diffs (Git-style):**
   - The "Review Changes" modal currently shows a simple list-level add/remove view.
   - Enhance the diff viewer to support showing raw text changes (before/after) when edits are made via the raw text editor.
   - Ensure the UI looks modern, using the `AppColors` and `AppTextStyles` dark theme.

4. **Testing & Linter:**
   - Write widget tests for the raw text editor and the backup restore flow.
   - Ensure `flutter test` and `flutter analyze --fatal-infos` pass cleanly.

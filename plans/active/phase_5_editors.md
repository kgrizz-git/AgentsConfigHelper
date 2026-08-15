# Phase 5: Editors, Diff Viewers, and Backups

**Status:** Complete (PR #5)
**Goal:** Implement the raw configuration editor, line-level diffing, and wire up the Backup & Restore UI.

## Requirements

1. **Raw Text Editor Fallback — done.**
   - `lib/widgets/config_editor.dart` replaced the "Raw JSON/YAML Editor Coming Soon" placeholder with a real multi-line text editor (`TextField` with `maxLines: null`) for editing the raw string content of the configuration file.
   - Saving from the raw editor writes content back to disk and triggers a backup via `ConfigService`.

2. **History & Backups View — done.**
   - `lib/widgets/history_modal.dart` replaced the "coming soon" snackbar with a modal listing available backups for the current file via `BackupService.listBackups()`.
   - Users can select a backup and restore it via `BackupService.restoreBackup()`.

3. **Visual Diffs (Git-style) — partially done, remainder deferred.**
   - The "Review Changes" modal (`ConfigEditor._buildDiffSection`) still shows a list-level add/remove view rather than a true line-level diff for raw-text and History/Backups comparisons.
   - Remaining scope tracked under the master-plan backlog "Git-style Merging & Diffing" (`plans/active/initial_master_plan.md`), not blocking Phase 5 completion.

4. **Testing & Linter — done.**
   - Widget tests cover the raw text editor and backup restore flow.
   - `flutter test` and `flutter analyze --fatal-infos` pass in CI.

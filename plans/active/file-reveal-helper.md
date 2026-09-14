# Plan: File Reveal Helper

Last reviewed: 2026-09-14
Date: 2026-09-14
Author: maintainers
Status: in progress
Linked issue/PR: n/a

## Goal

Let users reveal an existing configuration file from its Overview report row
without opening, creating, editing, or copying that file.

## Scope and decisions

- Add one compact icon action beside the existing Open-in-editor and Copy-path
  actions in `ConfigOverviewScreen`.
- Only render the action for resolved, non-missing paths. A reveal attempt must
  never create a file or parent directory.
- Use a dedicated `revealFile(File)` helper rather than `openDirectory`, whose
  directory-creation behavior is inappropriate here.
- macOS uses `open -R <file>` to select the file in Finder; Windows uses
  `explorer /select,<file>`; Linux uses `xdg-open <parent-directory>` because
  there is no portable cross-file-manager select-file interface.
- Return a success flag and surface a concise in-app error if the platform
  launcher fails. Do not add a context menu, backup changes, or editor changes.

## Implementation

- [x] Add a non-mutating, injectable platform-launch helper with no-op handling
      for missing files and unsupported platforms.
- [x] Add a report-row reveal icon, tooltip, and failure feedback.
- [x] Unit-test macOS, Windows, and Linux launch arguments plus missing-file
      and failed-launch behavior.
- [x] Add report-screen coverage for the visible action.
- [x] Run format, analysis, targeted tests, and the full test suite (all passed
      on 2026-09-14; 527 tests in the full suite).
- [ ] Perform a manual macOS Finder smoke check from a disposable test root.

## Acceptance criteria

- Existing Overview files can be selected in Finder on macOS.
- The same control selects files in Explorer on Windows and opens the parent
  directory in Linux file managers.
- Missing and unresolved entries do not show an actionable reveal control.
- No reveal path creates or alters configuration files or directories.
- The existing Open and Copy actions retain their behavior.

## Completion steps

1. Record verification and the manual macOS result above.
2. Set status to `complete` and move this file to `plans/archive/`.
3. Remove the linked `TO_DO.md` item and retain the user-facing changelog entry.

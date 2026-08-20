# Plan: RecoveryHandler widget tests (coverage gap)

**Status:** Complete
**Last updated:** 2026-08-18
**Owner:** (unassigned)
**Depends on:** Phase 6A recovery dialog (`lib/screens/recovery_handler.dart`)
**Goal:** Cover `RecoveryHandler` so CI line coverage can pass the 80% gate
(currently ~77.44%). No user-facing behavior change.

## Why the previous attempt stalled (and why it is wrong)

The Phase 6 plan deferred this test because `File.exists()`, `File.readAsString()`,
and `BackupService.listBackups()` "don't complete in Flutter's widget test
framework." That mixed up two facts:

1. Widget tests run in a **fake-async** zone. Real `dart:io` futures do not
   complete during a normal `pump()` / `pumpAndSettle()` unless flushed with
   `tester.runAsync(...)`. That is a binding quirk, not a prohibition on I/O.
2. `pumpAndSettle()` while a dialog animation is running is fine; once the
   route is idle the test can tap actions. Do **not** treat an open dialog as
   a hang.

This repo already uses real temp directories in unit tests
(`backup_service_test.dart`, `discovery_service_test.dart`). Widget tests that
need real I/O must wrap the I/O flush in `runAsync`, then `pump` to rebuild.

Do **not** drive this through `MainShell`. Mix `RecoveryHandler` into a tiny
harness widget and call `showRecoveryDialog` from a button (or a `GlobalKey`).

## Approach (no production refactor unless runAsync is flaky)

Preferred: **no changes** to `lib/screens/recovery_handler.dart`. Use real temp
files + real `ConfigService` / `BackupService` + Riverpod overrides.

Fallback (only if `runAsync` interleaving is unworkable): inject
`Future<bool> Function(String path)` / `Future<String> Function(String path)`
with `File` defaults. That is a last resort, not the starting point.

## Test file

Create `test/screens/recovery_handler_test.dart`.

### Harness

A private `ConsumerStatefulWidget` that:

- Mixes in `RecoveryHandler`
- Implements every getter/setter the mixin requires
- Exposes `loadGeneration` so tests can bump it (stale-generation guards)
- Implements `showHistoryModal()` as a recorded callback (do not open the real
  `HistoryModal` — that is already tested in `history_modal_test.dart`)
- Wraps in `MaterialApp` → `Scaffold` (snackbars + dialogs need both)
- Overrides:
  - `configServiceProvider` — real `ConfigService` with a temp-dir
    `BackupService` and an injectable `homeDirectoryResolver` when testing `~`
  - `discoveryPreferencesStoreProvider` — fake `IDiscoveryPreferencesStore`
  - `discoveryServiceProvider` — fake that returns an empty `DiscoveryResult`
    (Remove calls `DiscoveryController.removeManualPath` → `refresh`)

Each test creates/deletes its own `Directory.systemTemp` child and tears it down.

### `runAsync` interleaving (required)

After triggering `showRecoveryDialog`:

```dart
await tester.tap(find.text('Recover'));
await tester.runAsync(() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
});
await tester.pumpAndSettle();
```

Then assert dialog contents, tap an action, `pumpAndSettle`, and if the action
does more I/O (`readAsString`), flush with `runAsync` again. If 50ms is tight
on CI, loop `runAsync` + `pump` until `find.text('Skip')` appears, with a
bounded retry count — do not spin forever.

**Implementation note (2026-08-18):** All per-test filesystem setup/tearDown
must also run inside `tester.runAsync`; bare `await file.writeAsString()` in
`testWidgets` hangs in the fake-async zone. Read-failure coverage writes a
real file so `exists()` shows **Open raw editor**, then replaces that path
with a directory before the tap so `readAsString()` throws on every platform
(`File.exists()` is false for directories, so the directory cannot be used
up front; `chmod 000` is POSIX-only).

### Cases (map to mixin branches)

| # | Case | Setup | Assert | Done |
| --- | --- | --- | --- | --- |
| 1 | Resolve-path failure | `homeDirectoryResolver: () => null`, path `~/missing.json` | Dialog shows error + **Skip** only; no raw/backups/remove; Skip clears `error` / `activeConfigId` / `activeConfig` | [x] |
| 2 | Skip on existing file | Real file on disk, no backups, not manual | **Open raw editor** present; **View backups** absent; **Remove** absent; **Skip** present; Skip clears error state | [x] |
| 3 | Open raw editor | Real readable file | After tap + I/O flush: `rawRecoveryMode == true`, `activeConfig.originalContent` matches file, `hasUnsavedChanges == false`, `error == null` | [x] |
| 4 | View backups | Real file + `backupService.createBackup` | **View backups** present; tap records `showHistoryModal`, sets raw recovery `ToolConfig` | [x] |
| 5 | Remove manual path | Path listed in fake store `manualFilePaths` | **Remove** present; tap calls `removeManualPath` on the fake store; error state cleared | [x] |
| 6 | Raw-editor read failure | File present for `exists()`, then replaced with a directory before tap so `readAsString()` throws on every OS | SnackBar with `Could not open the raw editor:`; error/active cleared; `rawRecoveryMode` stays false | [x] |
| 7 | Prefs load failure | Fake `load()` throws | Dialog still appears; **Remove** absent (degrades); Skip works | [x] |
| 8 | Stale generation | Open dialog, then bump harness `loadGeneration` before tap | Action is ignored (no raw mode, no remove, no history); no crash | [x] |
| 9 | Missing file | Path does not exist, backups empty | No **Open raw editor**; **Skip** still works | [x] |
| 10 | History with deleted file | Backup exists, original file deleted | **View backups** present; tap still sets `activeConfig` (empty or leftover content) and calls `showHistoryModal` | [x] |

Cover the `listBackups` failure branch if it can be done without a production
change (e.g. a `BackupService` subclass that throws). Same for
`removeManualPath` throwing — fake store throws; removal is non-fatal.

- [x] `listBackups` throws → View backups absent
- [x] `removeManualPath` throws → non-fatal

## Docs / changelog (after tests pass)

- [x] `CHANGELOG.dev.md` **Unreleased → Added**: widget tests for `RecoveryHandler`.
  No public `CHANGELOG.md` / `VERSION` bump (tests only).
- [x] `plans/active/phase_6_release.md`: mark A4 recovery-dialog widget test
   done; remove the "I/O doesn't complete" deferral note.
- Do not edit `TO_DO.md` unless an item explicitly names this gap.

## Verification

```bash
dart format --output=none --set-exit-if-changed test/screens/recovery_handler_test.dart
flutter analyze --fatal-infos
flutter test test/screens/recovery_handler_test.dart
flutter test --coverage
# then the same Python lcov gate as CI (exclude vendor, fail below 80%)
```

If tests fail: stop, report the failure and a proposed fix. Do not weaken
assertions, skip tests, or change production behavior to force a pass.

## Out of scope

- MainShell integration test for the parse-error → dialog path (nice-to-have;
  not required to cover the mixin).
- Refactoring save/load I/O out of widgets elsewhere.
- SonarCloud wiring (separate `TO_DO.md` item).

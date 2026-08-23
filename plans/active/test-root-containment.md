# Plan: Test-Root Containment

Last reviewed: 2026-08-22
Date: 2026-08-22
Author: maintainers
Status: in progress
Linked issue/PR: n/a
Parent plan: [Safe Testing Foundation](safe-testing-foundation.md)

## Goal

Provide one opt-in, test-only `--test-root=<absolute-path>` startup mode that confines
all app reads and writes used in a macOS staging smoke test to a freshly created fixture
root. It must cover discovery, config saves, backups, restores, and discovery preferences.
It must not present a best-effort string-prefix check as protection against symlink
escapes.

## Why this is separate

Phase 0 established that `HOME` controls user-path discovery but that backups and
preferences use `getApplicationSupportDirectory()`. A test-root boundary therefore
crosses startup, providers, config I/O, backup/restore I/O, and UI. It also needs a
platform-specific decision for final no-follow writes. Keeping that decision in a focused
plan prevents a partial redirect from being documented as safe.

## Contracts

### Activation

- Accept one exact argument: `--test-root=<absolute-path>`.
- Reject missing values, duplicate arguments, relative paths, a missing root, and a root
  that is itself a symbolic link.
- Require a marker created by the staging script (for example,
  `.agents-config-helper-test-root`) with its exact expected content before enabling test
  mode. The script creates a unique private root; the app never creates or deletes a
  caller-selected root.
- Default startup remains unchanged when the argument is absent.
- Display a persistent banner naming test mode and the selected root.

### Routing

| Concern | Test-mode route or rule |
| --- | --- |
| User-scope discovery and `~` | Override the home resolver with the canonical test root. |
| Config loading/saving | Allow only targets inside the canonical test root. |
| Backups | Use `<test-root>/application-support/backups`; allow only backup files there. |
| Restore | Require both the selected backup and target to be inside the test root. |
| Discovery preferences | Inject `<test-root>/application-support` into `DiscoveryPreferencesStore`. |
| Manual paths and project roots | Reject entries outside the test root before persisting or scanning. |
| `COPILOT_HOME` | Ignore it in test mode unless it resolves inside the test root. |

### Containment rule

The implementation must canonicalize the root once after checking it is an existing
non-symlink directory. For every target, it must reject an absolute-normalized path that
is not a component-wise descendant of that canonical root. Every existing target or
ancestor must be resolved without following links and rejected when it is a symbolic link
or resolves outside the root. Recheck before and after parent creation.

Those checks are necessary but are not sufficient against an attacker swapping a path
between the final check and a write. Before declaring this workflow safe for writes,
the implementation must use a no-follow final-operation primitive for each supported
desktop platform, or explicitly reduce the claim to non-adversarial local testing and
leave write smoke testing disabled. This is a release-blocking decision, not a comment.

## Platform primitive assessment

The current `dart:io` APIs cannot meet the final-operation requirement: Dart documents
that `File` operations follow symbolic links, and `writeAsString` opens/truncates the
path. Do not layer an allow-list check around those calls and label the result
race-resistant. [Dart `File` API](https://api.dart.dev/dart-io/File-class.html)
and [Dart `writeAsString` API](https://api.dart.dev/dart-io/File/writeAsString.html)
document that behavior.

The implementation direction is a small native method-channel bridge, not a broad production
filesystem rewrite:

| Platform | Candidate final-operation strategy | Status |
| --- | --- | --- |
| macOS | Open the test-root directory and each descendant with descriptor-relative `openat`; use `O_NOFOLLOW` for every component, write a same-directory temporary file, then replace it using the verified parent descriptor. | Viable in principle; prototype required. Apple documents `O_NOFOLLOW` as refusing a symlink final component. |
| Linux | Use the same descriptor walk as macOS for baseline compatibility; use `openat2` with `RESOLVE_BENEATH` and `RESOLVE_NO_SYMLINKS` where available as a stronger optimization, not as the only implementation. | Viable in principle; `openat2` is Linux-specific and begins with Linux 5.6. |
| Windows | Open components without following reparse points, reject `FILE_ATTRIBUTE_REPARSE_POINT`, and perform reads/writes/replaces through verified handles rather than a later path. | Requires a Windows-handle prototype; `FILE_FLAG_OPEN_REPARSE_POINT` alone is not sufficient as an unverified full-path write design. |

Primary references: [Apple `open(2)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/open.2.html),
[Linux `openat2(2)`](https://man7.org/linux/man-pages/man2/openat2.2.html), and
[Microsoft `CreateFile`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea).

**Decision:** Implement and test a macOS-native bridge first. macOS `--test-root` work may
move forward after its no-follow operations are proven. Linux and Windows do not block
that local workflow; they must reject the test-root argument until their own native
implementations and tests exist. Docker remains optional Linux validation, not a
prerequisite for macOS delivery.

### macOS implementation record

`macos/Runner/AppDelegate.swift` registers a test-only method channel used only after
startup validates `--test-root`. It opens the canonical root with
`O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC` and retains that descriptor for the native
operation object's lifetime, then opens every descendant directory with descriptor-relative
`openat` and the same no-follow flags. Empty, absolute, `.` and `..` relative-path components
are rejected before that walk. Retaining the root descriptor means a later replacement of the
root pathname cannot redirect an operation outside the original root.

Reads open the final file with `O_NOFOLLOW`; directory listings use a duplicated directory
descriptor and no-follow `fstatat` to return only regular files. A write creates a unique,
same-directory temporary file with `O_CREAT | O_EXCL | O_NOFOLLOW`, writes and fsyncs it,
renames it through the verified parent descriptor, then fsyncs that parent. Therefore a
final-component symlink is atomically replaced rather than followed. Root, descendant, file,
and listing descriptors are closed by their owning `defer` scopes; `fdopendir` owns only its
duplicated descriptor. Native errors return a `FlutterError` to Dart and abort the requested
operation.

The macOS test mode also disables the app's platform-folder-opening actions, so their ordinary
`dart:io` helper cannot create or launch an unchecked directory during a staging run.

## Phases and checklist

### Phase 0: Prove the macOS final-operation primitive

- [x] Establish that `dart:io` follows symbolic links and cannot provide the required
      no-follow final operation; record viable OS primitives above.
- [x] Prototype a macOS method-channel bridge for descriptor-relative no-follow create,
      copy, replace, and directory traversal operations. It exposes no user-facing mode.
- [x] Test normal writes plus symlinked-root, parent, and target rejection in the macOS
      Runner test target; prove that an existing target symlink is replaced rather than
      followed.
- [x] Document macOS call/error/descriptor-close behavior and atomic-replace semantics.
- [x] Keep Linux and Windows test-root startup disabled pending their own native bridges.

**macOS exit gate:** a concrete, tested operation exists for final write, backup-copy,
restore-copy, and preference atomic-replace operations below a macOS test root.

### Phase 1: Startup and dependency injection

- [x] Add a small, unit-tested argument parser/configuration object; keep it independent
      of Flutter widgets.
- [x] Create the canonical test-root guard from that configuration during startup.
- [x] Override the home resolver, `ConfigService`, `BackupService`, and
      `DiscoveryPreferencesStore` in the root `ProviderScope`.
- [ ] Ensure normal startup creates exactly the same service graph as before.
- [x] Add a persistent test-mode banner without exposing an option to enable it from the
      normal UI.

### Phase 2: Enforce paths at every I/O boundary

- [x] Apply the guard before config load, save, raw save, backup creation/listing,
      restoration, restore-as-recreate, and preferences read/write.
- [x] Validate manual paths and project roots before persistence and discovery.
- [x] Ignore or reject external discovery environment paths outside the root.
- [x] Preserve the ordinary app's unrestricted behavior when no guard is configured.

### Phase 3: Prove the boundary

- [x] Unit-test startup argument validation and marker validation; default-mode tests
      remain to be added with a startup harness.
- [x] Test normal files inside the root for save, backup-copy, restore-copy, and preference
      writes.
- [x] Test outside-root, symlinked-root, symlinked-parent, symlinked-target, and
      symlink-swap attempts. Each rejection must leave the outside path untouched.
- [x] Test that a test-mode preference file and all backup files appear below the root.
- [x] Test that test mode does not scan an external `COPILOT_HOME`.
- [x] Add widget coverage for the persistent test-mode banner.

### Phase 4: Hand off to staging fixtures

- [x] Add the fixture matrix and staging script from the parent plan after macOS Phase 3
      passes. The script must refuse unsupported platforms.
- [x] Add a thin root developer entrypoint and a concise operator reference that delegate to
      the staging and validated-cleanup scripts without duplicating their safety logic.
- [x] Record the tested macOS paths and commands in `docs/testing-strategies.md`; add
      Linux and Windows guidance only with their respective implementations.
- [ ] Update the parent plan's Phase 0/2 checkboxes with test evidence; do not call the
      workflow safe until the no-follow exit gate and platform runs pass.

## Proposed files

```text
lib/testing/test_root_configuration.dart      argument/marker validation and root metadata
lib/services/macos_test_root_file_operations.dart macOS method-channel bridge
lib/main.dart                                 parse mode and wire guarded services/providers
lib/services/config_service.dart              guard config read/write boundaries
lib/services/backup_service.dart              guard backup and restore boundaries
lib/services/discovery_preferences_store.dart inject and guard preference storage
lib/state/providers.dart                      test-mode dependency overrides/environment handling
lib/screens/main_shell.dart                   persistent test-mode banner
macos/Runner/AppDelegate.swift                macOS descriptor-relative no-follow operations
macos/RunnerTests/RunnerTests.swift           native macOS containment tests
test/testing/...                              argument, marker, and containment tests
test/services/...                             config, backup, restore, and preference tests
test/state/...                                provider and `COPILOT_HOME` containment tests
```

Linux and Windows implementations are intentionally deferred. They must not reuse a
macOS-only bridge or introduce a Dart path-string fallback.

## Verification

- [x] `flutter analyze --fatal-infos` passes.
- [x] `dart format --output=none --set-exit-if-changed .` passes.
- [x] `flutter test --coverage` passes. The configured CI floor is 80%; the local
      measured result was 81.97% on 2026-08-23.
- [x] All test-mode writes and reads are asserted inside the canonical root.
- [x] macOS symlink and swap tests prove final-operation behavior, not merely path-string
      rejection.
- [ ] Default-mode tests show existing discovery, backup, restore, and preference behavior
      remains unchanged.
- [x] A native macOS staging run uses only a script-created root and leaves no writes
      outside it. Manual smoke on 2026-08-22 confirmed the test-mode banner, staged
      discovery, raw/structured edits, backup and preference artifacts below the root, and
      rejection of an external project root.
- [ ] Linux and Windows reject test-root activation until their platform-specific
      verification is complete.

## Completion steps

1. Mark this plan complete and move it to `plans/archive/`.
2. Update the parent safe-testing plan with the verified evidence and next fixture phase.
3. Update `docs/testing-strategies.md`, `CHANGELOG.dev.md`, and `TO_DO.md` as applicable.

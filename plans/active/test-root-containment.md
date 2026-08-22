# Plan: Test-Root Containment

Last reviewed: 2026-08-22
Date: 2026-08-22
Author: maintainers
Status: ready to implement
Linked issue/PR: n/a
Parent plan: [Safe Testing Foundation](safe-testing-foundation.md)

## Goal

Provide one opt-in, test-only `--test-root=<absolute-path>` startup mode that confines
all app reads and writes used in a staging smoke test to a freshly created fixture root.
It must cover discovery, config saves, backups, restores, and discovery preferences. It
must not present a best-effort string-prefix check as protection against symlink escapes.

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
  `.agents-config-helper-test-root`) before enabling test mode. The script creates a
  unique private root; the app never creates or deletes a caller-selected root.
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

The implementation direction is a small native FFI bridge, not a broad production
filesystem rewrite:

| Platform | Candidate final-operation strategy | Status |
| --- | --- | --- |
| macOS | Open the test-root directory and each descendant with descriptor-relative `openat`; use `O_NOFOLLOW` for every component, write a same-directory temporary file, then replace it using the verified parent descriptor. | Viable in principle; prototype required. Apple documents `O_NOFOLLOW` as refusing a symlink final component. |
| Linux | Use the same descriptor walk as macOS for baseline compatibility; use `openat2` with `RESOLVE_BENEATH` and `RESOLVE_NO_SYMLINKS` where available as a stronger optimization, not as the only implementation. | Viable in principle; `openat2` is Linux-specific and begins with Linux 5.6. |
| Windows | Open components without following reparse points, reject `FILE_ATTRIBUTE_REPARSE_POINT`, and perform reads/writes/replaces through verified handles rather than a later path. | Requires a Windows-handle prototype; `FILE_FLAG_OPEN_REPARSE_POINT` alone is not sufficient as an unverified full-path write design. |

Primary references: [Apple `open(2)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/open.2.html),
[Linux `openat2(2)`](https://man7.org/linux/man-pages/man2/openat2.2.html), and
[Microsoft `CreateFile`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea).

**Decision:** Start with a contained FFI feasibility spike. Do not add a
`--test-root` write mode, fixture script, or test-mode banner until that spike proves
the primitives for all three desktop platforms. Fixture-only parser and discovery tests
remain safe work while the spike is evaluated.

## Phases and checklist

### Phase 0: Prove the final-operation primitive

- [x] Establish that `dart:io` follows symbolic links and cannot provide the required
      no-follow final operation; record viable OS primitives above.
- [ ] Prototype a minimal FFI bridge for descriptor/handle-based no-follow create, copy,
      replace, and directory traversal operations. It must expose no user-facing feature.
- [ ] Document the selected macOS/Linux and Windows calls, error mapping, ownership/close
      rules, and whether they preserve atomic-write behavior.
- [ ] If no cross-platform approach is viable in this slice, stop before exposing
      write/restore test mode; retain fixture-only discovery and unit tests instead.

**Exit gate:** a concrete, testable implementation strategy exists for final write,
backup-copy, restore-copy, and preference atomic-replace operations on all supported
desktop platforms.

### Phase 1: Startup and dependency injection

- [ ] Add a small, unit-tested argument parser/configuration object; keep it independent
      of Flutter widgets.
- [ ] Create the canonical test-root guard from that configuration during startup.
- [ ] Override the home resolver, `ConfigService`, `BackupService`, and
      `DiscoveryPreferencesStore` in the root `ProviderScope`.
- [ ] Ensure normal startup creates exactly the same service graph as before.
- [ ] Add a persistent test-mode banner without exposing an option to enable it from the
      normal UI.

### Phase 2: Enforce paths at every I/O boundary

- [ ] Apply the guard before config load, save, raw save, backup creation/listing,
      restoration, restore-as-recreate, and preferences read/write.
- [ ] Validate manual paths and project roots before persistence and discovery.
- [ ] Ignore or reject external discovery environment paths outside the root.
- [ ] Preserve the ordinary app's unrestricted behavior when no guard is configured.

### Phase 3: Prove the boundary

- [ ] Unit-test startup argument validation, marker validation, and default-mode behavior.
- [ ] Test normal files inside the root for save, raw save, backup, restore, and
      preferences.
- [ ] Test outside-root, symlinked-root, symlinked-parent, symlinked-target, and
      symlink-swap attempts. Each rejection must leave the outside path untouched.
- [ ] Test that a test-mode preference file and all backup files appear below the root.
- [ ] Test that test mode does not scan an external `COPILOT_HOME`.
- [ ] Add widget coverage for the persistent test-mode banner.

### Phase 4: Hand off to staging fixtures

- [ ] Add the fixture matrix and staging script from the parent plan only after Phase 3
      passes on all desktop platforms.
- [ ] Record the tested macOS, Linux, and Windows paths and commands in
      `docs/testing-strategies.md`.
- [ ] Update the parent plan's Phase 0/2 checkboxes with test evidence; do not call the
      workflow safe until the no-follow exit gate and platform runs pass.

## Proposed files

```text
lib/testing/test_root_configuration.dart      argument/marker validation and root metadata
lib/services/test_root_guard.dart             canonical/no-follow containment abstraction
lib/main.dart                                 parse mode and wire guarded services/providers
lib/services/config_service.dart              guard config read/write boundaries
lib/services/backup_service.dart              guard backup and restore boundaries
lib/services/discovery_preferences_store.dart inject and guard preference storage
lib/state/providers.dart                      test-mode dependency overrides/environment handling
lib/screens/main_shell.dart                   persistent test-mode banner
test/testing/...                              argument, marker, and containment tests
test/services/...                             config, backup, restore, and preference tests
test/state/...                                provider and `COPILOT_HOME` containment tests
```

The exact native bridge/package location is intentionally deferred to Phase 0; selecting
it before evaluating the platform semantics would create an artificial architecture.

## Verification

- [ ] `flutter analyze --fatal-infos` passes.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter test --coverage` passes and retains the CI coverage floor.
- [ ] All test-mode writes and reads are asserted inside the canonical root.
- [ ] Symlink and swap tests prove final-operation behavior, not merely path-string
      rejection.
- [ ] Default-mode tests show existing discovery, backup, restore, and preference behavior
      remains unchanged.
- [ ] Native macOS, Linux, and Windows staging runs use only a script-created root and
      leave no writes outside it.

## Completion steps

1. Mark this plan complete and move it to `plans/archive/`.
2. Update the parent safe-testing plan with the verified evidence and next fixture phase.
3. Update `docs/testing-strategies.md`, `CHANGELOG.dev.md`, and `TO_DO.md` as applicable.

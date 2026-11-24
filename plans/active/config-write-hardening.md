# Plan: Config Write-Safety Hardening

Last reviewed: 2026-11-24
Date: 2026-11-24
Author: maintainers
Status: active
Tracking: `TO_DO.md` → Config write-safety hardening

## Goal

Close the residual write-safety deviations recorded by the archived
[config write-safety plan](../archive/config-write-safety.md) and its review follow-ups:

- apply POSIX modes with `fchmod` on the descriptor instead of path-based `chmod`;
- fsync the parent directory after publishing a replacement;
- replace the Windows build-only assumption with runtime coverage of the atomic
  replacement primitive;
- make temporary-file ownership and cleanup deterministic to test.

The user-visible guarantee stays the same: a failed save leaves the original
untouched, and a successful save publishes the exact reviewed bytes with the
destination's mode.

## Current state

`LocalFileOperations._writeAtomically` creates a short-lived, exclusive temp in
the destination directory, opens it, applies the destination mode with a
`chmod` process call, writes/flushes, renames, and cleans up only files this
call created. Windows uses Dart's `File.rename` as the replace primitive and
does not use POSIX modes. The macOS test-root bridge already uses
`openat` + `fchmod` + `fsync` + `renameat` + parent `fsync`.

The archived plan's deviations are the source of this work:

- no `fchmod` in `dart:io`, so the production path has a small window where a
  different file could be present at the temp path when `chmod` runs;
- no directory `fsync`, so a power loss after rename can lose the update;
- Windows replacement is build-verified only;
- review nits around deterministic temp naming and a non-`FileSystemException`
  close path that can skip cleanup.

## Scope

### H1 — Windows atomic-replace runtime proof

- Establish whether Dart's `File.rename` on Windows already uses a
  replace-existing OS primitive. If it does, document that and test it; if it
  does not, add a native `MoveFileExW`/`ReplaceFileW` path behind the same
  `FileOperations` boundary. Never delete the live file to make replacement
  easier.
- Add Windows test execution (the Windows build job may run the focused atomic
  test, or a dedicated `tests-windows` job will). Cover:
  - replacing an existing destination;
  - a destination that cannot be replaced while open/locked: abort, keep the
    original bytes, remove only this call's temp;
  - no temporary leftovers after success or failure.
- Keep Windows out of POSIX mode/fsync claims.

### H2 — POSIX descriptor-relative mode and directory fsync

- Add a small FFI-backed POSIX atomic writer behind the existing
  `FileOperations` boundary; Windows keeps the Dart path.
- Open the exclusive temp with the platform's `O_EXCL | O_NOFOLLOW | O_CLOEXEC`
  flags, apply the destination mode with `fchmod` on the descriptor before
  writing, write all bytes (EINTR/partial-write safe), `fsync` the descriptor,
  close, rename onto the resolved target, then open/`fsync`/close the parent
  directory.
- New files still default to `0600`. Existing destination modes are read before
  the write and applied verbatim. Symlink-target resolution stays in Dart; the
  temp lives in the resolved target's directory.
- Use libc's `__error` (macOS) / `__errno_location` (Linux) for error codes and
  map failures to `FileSystemException`. A failure before publication removes
  only the temp this call created. A directory-fsync failure after publication
  is logged rather than reported as a failed save, because the bytes are
  already in place and cannot be rolled back; state that policy.
- Keep an injectable native seam so unit tests can assert call order, partial
  writes, EINTR retry, mode application, close-on-error, and fsync failures.
  Exercise the real path in integration tests on macOS and Linux, including
  mode `0400`/`0664`, symlink targets, and failed replacements.
- Add macOS test execution for the FFI path (the current Tests job is Ubuntu
  only); Linux continues to run the same tests in CI.
- Add `ffi` as a direct dependency if it is not already declared.

### H3 — Cleanup and deterministic test seams

- Inject the temporary-name factory into `LocalFileOperations` for tests; keep
  the production PID/timestamp/random default.
- Add the deterministic foreign-file test: a pre-existing file at the would-be
  temp path that this call did not create must not be deleted on cleanup.
- Widen the fallback close handler to catch all close failures so temp cleanup
  cannot be skipped by a non-`FileSystemException`.
- Optionally render the changed path in the conflict dialog; this is clarity,
  not a data-safety requirement.

### H4 — Documentation and completion

- Update `CHANGELOG.dev.md` with the native/CI details; update `CHANGELOG.md`
  only for behavior users can observe (mode/directory durability semantics).
- Update the archived plan's deviations or add a short follow-up note so the
  record matches the shipped hardening.
- Archive this plan on the final hardening branch and remove its `TO_DO.md`
  entry when implementation, review, CI, and the recorded follow-through are
  complete.

## Non-goals

- Cross-instance locking; concurrent instances remain last-writer-wins.
- Windows ACL/owner preservation; Windows has no POSIX mode equivalent in this
  app, and the plan only claims replace-abort semantics there.
- Changing backup naming, pruning, or the backup directory layout.
- Replacing the macOS test-root bridge.

## Risks and decisions to confirm

1. **FFI portability.** POSIX flag values and errno access differ between macOS
   and Linux. Keep constants and the errno lookup platform-scoped and test both
   platforms in CI.
2. **Directory-fsync failure policy.** Logging after publication avoids
   reporting a failed save for bytes already written; the plan does not claim a
   rollback that POSIX cannot provide.
3. **Windows primitive.** If Dart's rename is not the replace-existing OS
   primitive, the native replacement is a larger change; do not ship H1 by
   weakening the no-delete rule.
4. **Tests on Windows.** The current suite runs on Ubuntu only; the targeted
   Windows run must not be flaky on locked-file tests. If a reliable lock test
   is not possible, record that gap rather than asserting a behavior the test
   does not prove.
5. **CI cost.** A macOS test job/step and a Windows test run add CI minutes;
   keep both focused on the atomic-write tests rather than the full suite on
   every platform.

## Checks

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test --coverage` + 80% gate
- macOS release build
- Linux and Windows builds
- New Windows atomic tests and macOS POSIX integration tests
- `dart_code_linter` metrics
- Docs link check

## Acceptance

- [ ] POSIX saves apply the destination mode with `fchmod` on the descriptor
      and fsync the parent directory after replace.
- [ ] New files remain owner-only; existing modes are preserved.
- [ ] A pre-publication failure leaves the original untouched and removes only
      this call's temp.
- [ ] Windows replacement has runtime coverage or a clearly recorded,
      approved gap; no delete-then-rename fallback exists.
- [ ] A pre-existing foreign temp file is never deleted by cleanup.
- [ ] macOS and Linux exercise the native path in CI.
- [ ] Both changelogs and the archived plan's deviation record match the
      shipped behavior.

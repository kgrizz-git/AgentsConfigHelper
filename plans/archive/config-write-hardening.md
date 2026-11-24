# Plan: Config Write-Safety Hardening

Last reviewed: 2026-11-24
Date: 2026-11-24
Author: maintainers
Status: archived
Tracking: completed

## Goal

Close the residual write-safety deviations recorded by the archived
[config write-safety plan](config-write-safety.md) and its review
follow-ups:

- apply POSIX modes with `fchmod` on the descriptor instead of path-based `chmod`;
- fsync the parent directory after publishing a replacement;
- replace the Windows build-only assumption with runtime evidence that Dart's
  replace primitive is atomic for regular files;
- make temporary-file ownership and cleanup deterministic to test.

**Save guarantee.** A failure before publication leaves the original untouched.
Once the temporary file has been renamed onto the destination, the save is
published: remaining directory maintenance is best-effort and logged, never
reported as a failed save and never rolled back.

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

Dart SDK 3.14.0's `runtime/bin/file_win.cc` implements regular-file rename with
`MoveFileExW(..., MOVEFILE_WRITE_THROUGH | MOVEFILE_REPLACE_EXISTING)`. Because
the temp and destination are in the same directory, no cross-volume copy
fallback is involved. H1 therefore needs runtime proof, not a native Windows
replacement.

## Scope

### H3 — Deterministic temp ownership and cleanup (first)

Land this before the FFI writer so the native path starts from the finished
ownership seam.

- Inject the temporary-name factory into `LocalFileOperations` for tests; keep
  the production PID/timestamp/random default.
- Track ownership with the existing `created` flag: set it only after the
  exclusive create succeeds and never delete a file this call did not create.
- Add a deterministic foreign-file test: pre-create a file at the would-be temp
  path, force the create to collide, and assert the foreign file is untouched.
- Widen the fallback close catch to `Object` so an exceptional close cannot
  skip cleanup. Preserve abort semantics: a close failure before publication
  still aborts the save after cleanup and rethrows the original error; it must
  not be converted to success.
- Add an injected close failure of type `StateError` (not only
  `FileSystemException`) and assert cleanup runs and the save fails.

### H1 — Windows replace proof (no native code)

- Add a dedicated atomic-write test file for Windows and run it from the
  existing Windows build job; keep the broader suite and its symlink-privilege
  variability out of that focused run.
- Cover:
  - replacing an existing destination;
  - no temporary leftovers after success;
  - a destination held with a sharing mode that omits `FILE_SHARE_DELETE`
    (a PowerShell/.NET `FileShare.None` holder is the intended mechanism; a
    byte-range `File.lockSync` is not sufficient): the save aborts, the
    original bytes remain, and only this call's temp is removed.
- Do not add a native Windows replacement path. If the pinned Dart SDK changes
  the implementation, revisit; an FFI `MoveFileExW` contingency would stay
  in-Dart, not become a plugin.
- If the deny-share holder cannot be made reliable on the hosted runner, record
  the locked-file gap explicitly rather than weakening the test.

### H2 — POSIX native writer with descriptor mode and directory fsync

- Add a small libc-FFI writer behind `FileOperations`; Windows keeps the Dart
  path. Use plain `open`, not `openat`: the production path resolves symlinks
  in Dart and creates a fresh random temp in the target's directory, so there
  is no pinned parent descriptor to be relative to. Only the post-rename parent
  `fsync` needs a directory open.
- FFI contract:
  - `open` is variadic; bind the mode argument with `VarArgs<(Int,)>`.
  - Use the platform-correct `mode_t` for `fchmod`; return types for `write`
    use the platform `ssize_t` width.
  - Read errno immediately after a failure via `__error` (macOS) or
    `__errno_location` (Linux). If the errno symbol cannot be resolved, fail
    closed: abort, clean this call's temp, and do not write.
- Open the exclusive temp with `O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW |
  O_CLOEXEC`, initial mode `0600`.
- Apply the destination mode with `fchmod` **before** writing. Preserve
  `st_mode & 0777` only; do not pass file-type bits or newly preserve
  setuid/setgid/sticky bits.
- Write all bytes with a loop: a zero-byte write before completion is an error;
  retry `write`/`fsync` on `EINTR` as appropriate; do not blindly retry
  `close` on an unknown descriptor state.
- `fsync` the temp descriptor, close it, then open the parent directory
  **before** publication with read-only directory semantics (`O_RDONLY`, plus
  `O_DIRECTORY` where the platform defines it; verify the descriptor is a
  directory if not). Hold that descriptor across the rename for the
  post-rename `fsync`; the rename itself remains path-based and no second
  parent open happens after publication. A parent-open failure other than
  permission denial aborts pre-publication with the original untouched and the
  temp removed; `EACCES`/`EPERM` skips the optional directory fsync, logs it,
  and still publishes the save.
- Rename onto the resolved target, then `fsync` and close the parent directory.
  Every operation after the successful rename is best-effort and logged,
  including parent `fsync` and `close` failures; the save reports success, the
  destination keeps the new bytes, and no rollback or destination unlink is
  attempted.
- Keep symlink resolution in Dart. This closes the temp-path `chmod` race, not
  hostile parent/path replacement races; those remain explicitly outside the
  durability claim.
- Tests:
  - injectable native seam: call order, partial writes, `EINTR`, zero-byte
    write, `fchmod`, file `fsync`, parent-open failure pre-publication, and
    parent `fsync`/`close` failure post-publication;
  - real macOS/Linux integration: mode `0400`/`0664`, new-file `0600`, symlink
    targets, failed replacement leaves the original and removes the temp;
  - post-publication failures: new bytes remain, no failed-save result, no
    temp, no rollback;
  - path-resolution TOCTOU is documented as out of scope.

### H4 — Documentation and completion

- `CHANGELOG.dev.md` always records the native/CI details. `CHANGELOG.md` gets
  an entry only for observable behavior changes.
- Do not rewrite the archived plan; it is read-only history. Record that this
  work resolves its `fchmod`/directory-`fsync`/Windows-verification deviations
  in this plan and in `CHANGELOG.dev.md`.
- Archive this plan on the final hardening branch and remove its `TO_DO.md`
  entry when implementation, review, CI, and follow-through are complete.

## Non-goals

- Cross-instance locking; concurrent instances remain last-writer-wins.
- Windows ACL/owner preservation; H1 claims replace-abort semantics only.
- Changing backup naming, pruning, or the backup directory layout.
- Replacing the macOS test-root bridge.
- `F_FULLFSYNC`/hardware-cache flushing claims beyond POSIX `fsync`.
- Defending against hostile parent-directory/path replacement races.

## Risks and decisions

1. **FFI portability.** Flags, `mode_t`, `ssize_t`, and errno access differ
   between macOS and Linux. Keep them platform-scoped and test both platforms.
2. **Post-publication policy.** Parent open happens before publication; after
   rename, `fsync`/`close` are logged and the save succeeds. This is the only
   policy consistent with "published bytes are not rolled back".
3. **Windows holder.** The deny-share holder must omit `FILE_SHARE_DELETE`;
   byte-range locks do not model rename sharing. Hosted-runner reliability is a
   test-infrastructure risk; record the gap if it cannot be made reliable.
4. **CI cost.** Use focused test steps in the existing macOS and Windows build
   jobs, not new jobs. Linux keeps the full suite and coverage gate.
5. **Close semantics.** A pre-publication close failure aborts; a
   post-publication parent close failure is logged. Do not retry a descriptor
   whose close state is unknown.

## Checks

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test --coverage` + 80% gate on Linux
- Focused atomic-write tests on macOS and Windows in their existing build jobs
- macOS release build
- `dart_code_linter` metrics
- Docs link check

## Acceptance

- [x] POSIX saves apply `st_mode & 0777` with `fchmod` on the descriptor before
      writing content.
- [x] New files are owner-only; existing modes, including `0400` and `0664`,
      are preserved without file-type or special bits.
- [x] The parent directory is opened before publication; a non-permission
      open failure leaves the original untouched and removes this call's temp.
      Permission denial skips directory fsync, logs, and still publishes.
- [x] Post-publication parent `fsync`/`close` failures are logged, the save
      succeeds, the new bytes remain, and no rollback/cleanup of the
      destination is attempted.
- [x] A pre-publication failure leaves the original untouched and removes only
      this call's temp; a foreign temp at a deterministic collided path is
      never deleted.
- [x] Windows runtime tests prove replace-existing and deny-share abort
      behavior, or the locked-file gap is explicitly recorded rather than
      claimed.
- [x] macOS and Linux exercise the FFI path in CI.
- [x] `CHANGELOG.dev.md` and the new plan record the resolved deviations;
      `CHANGELOG.md` is updated only for observable behavior.

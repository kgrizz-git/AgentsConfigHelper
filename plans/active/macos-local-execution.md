# Plan: macOS Local Execution

Last reviewed: 2026-08-21
Date: 2026-08-20
Author: maintainers
Status: in progress
Linked issue/PR: n/a

> This plan replaces the macOS portion of
> `macos-execution-and-dependency-upgrades.md`. Dependency work now lives in
> `plans/active/dependency-upgrades.md` so it cannot delay the local macOS fix.

## Goal

Make a local, source-built macOS app discover, edit, and back up the user's
real configuration files. The app is not distributed as a prebuilt macOS
binary in this cycle.

## Decision and scope

ADR-002 accepts an **unsandboxed, source-build-only** workflow. Removing the
Flutter template's App Sandbox entitlement lets the existing normal-home
resolver read and write the real user home, which is sufficient for local
builds.

Removing App Sandbox does not grant Full Disk Access. Normal macOS file
permissions and privacy controls can still deny discovery or writes in
protected locations.

This is deliberately small:

- Do not add `getpwuid_r` FFI, container-path rewriting, security-scoped
  bookmarks, temporary exceptions, or a preferences-data migration.
- Do not add Developer ID signing, Hardened Runtime, notarization, a release
  workflow, or a public binary artifact.
- Do not change Windows/Linux discovery.
- Do not promise the Mac App Store as a future-compatible path. Revisit
  ADR-002 before distributing a macOS `.app`, `.dmg`, `.pkg`, or release zip.

Existing local source builders who have saved manual paths or in-app backup
history may need to re-add those paths after this change. Their original config
files are unaffected; legacy backups remain under the old sandbox container.

## Phase 0: Record the current local baseline

- [x] Run `flutter run -d macos` before the entitlement change. On 2026-08-21,
      the Debug app built, stayed alive, and exposed a Dart VM service despite
      `Failed to foreground app; open returned 1`.
- [x] Record the effective `HOME` and sandbox state. On 2026-08-21, the app
      process retained `HOME=$HOME`; its signed Debug
      entitlements included `com.apple.security.app-sandbox`, and the
      corresponding container existed under `~/Library/Containers/`.
- [x] Record the sandboxed discovery evidence gap. The pre-change process
      stayed alive, but the sidebar was not visually observed; the real `HOME`
      value means its state cannot be inferred from the environment alone.
      Reproducing the old sidebar state would require reverting the completed
      entitlement change and is not needed to validate the source-build fix.
- [x] Record whether the developer has existing discovery preferences or
      in-app backup history in the old container. On 2026-08-21, neither the
      preferences file nor backup directory existed under the template bundle
      ID's old container, so no recovery action is needed for this checkout.
- [ ] Verify the app process stays alive when `Failed to foreground app; open
      returned 1` is seen. The upstream Flutter issue is still open, so treat
      it as tracked toolchain noise only when the app paints and the VM service
      connects.

## Phase 1: Remove the sandbox for source builds

- [x] Delete `com.apple.security.app-sandbox` from
      `macos/Runner/DebugProfile.entitlements` and
      `macos/Runner/Release.entitlements`. Delete the keys; do not set them to
      `false`.
- [x] Retain the existing Debug/Profile `com.apple.security.cs.allow-jit` and
      `com.apple.security.network.server` entries needed by Flutter tooling.
- [x] Remove the corresponding `com.apple.Sandbox` Xcode project capability
      metadata so Signing & Capabilities does not contradict the entitlements.
- [x] Leave `PRODUCT_BUNDLE_IDENTIFIER` unchanged. It is a signing/distribution
      decision, not a blocker for a local source build.
- [x] Add a lightweight macOS CI assertion that both entitlement files and
      Xcode project metadata omit App Sandbox, then retain the existing macOS
      release-build check.

## Phase 2: Validate the local workflow

- [x] Run `flutter run -d macos`; the Debug app built, stayed live, and exposed
      its Dart VM service with sandbox-free Debug entitlements. The foreground
      warning remains tracked separately in Phase 3.
- [x] Automated discovery tests cover a user-scope config, project root, and
      absolute manual path. The entitlement-only change does not alter that
      Dart discovery code.
- [x] Automated `ConfigService` and backup tests cover the diff/save/backup
      workflow using disposable fixtures.
- [ ] Confirm hot reload manually in Debug/Profile when working interactively.
- [x] Existing provider/widget tests cover warnings for genuinely unresolved
      homes and manual-path errors; no native home-resolution code was added.
- [x] Run the local gates: `flutter analyze --fatal-infos`, `flutter test`,
      `dart format --output=none --set-exit-if-changed .`, and the configured
      code-linter metrics command. Pull-request CI remains the release-matrix
      check after this branch is pushed.

## Phase 3: Triage the remaining macOS messages

- [ ] Issue B (`Failed to foreground app; open returned 1`): record the local
      evidence from Phase 0. If the app is alive and renders, document it as
      “track upstream,” including the verified Flutter version and the current
      status of flutter/flutter#176850. Do not block the file-access fix on it.
- [ ] Issue C (Xcode Run Script warning): retain `alwaysOutOfDate = 1` and
      `ENABLE_USER_SCRIPT_SANDBOXING = NO` in Flutter-owned build phases. Do
      not add synthetic output files or edit Flutter assemble/embed semantics.

## Documentation

- [x] Update `README.md` and `ARCHITECTURE.md` to say that macOS is currently
      supported by local source builds only, with full user-session filesystem
      access required for the product's discovery/edit workflow.
- [x] Add a user-facing `CHANGELOG.md` entry describing the local-source-build
      scope and that old sandboxed preferences/backup history are not migrated.
      Choose a version bump when this unreleased change is cut.
- [x] Update `CHANGELOG.dev.md` for the implementation and CI assertion.

## Acceptance criteria

- [ ] A local Debug macOS run discovers known user-scope configs from the
      actual home directory.
- [ ] Project roots and manual paths can be discovered, edited, and backed up.
- [ ] Debug hot reload continues to work.
- [ ] Both entitlement files omit `com.apple.security.app-sandbox`.
- [ ] No prebuilt macOS binary is published or represented as signed/notarized.
- [ ] Windows/Linux behavior and the normal quality gates remain green.

## Deferred until binary distribution or sandbox requirements exist

- Final bundle identifier and migration from the template container.
- Developer ID signing, Hardened Runtime, notarization, stapling, Gatekeeper
  verification, and release secrets/workflow.
- Sandboxed alternatives: temporary exceptions and security-scoped bookmarks.
- Native `getpwuid_r` real-home resolution, container heuristics, and
  macOS-host FFI tests.
- Parser fuzzing and a dedicated “writes outside discovered set” confirmation
  design. Existing diff preview and backup-before-write protections remain in
  force for this local-use scope.

## Completion steps

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Log shipped user-facing and developer-facing changes in the appropriate
   changelog.
4. Remove related `TO_DO.md` items if any.

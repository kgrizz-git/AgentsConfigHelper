# Plan: Dependency Upgrades

Last reviewed: 2026-08-21
Date: 2026-08-21
Author: maintainers
Status: draft
Linked issue/PR: n/a

## Goal

Update Dart/Flutter package dependencies safely, with small, reversible
commits and the same checks enforced by CI.

## Scope and boundaries

- This plan updates packages and `pubspec.lock`; it does **not** change the
  Flutter SDK. A Flutter SDK update is a separate task because CI, developer
  prerequisites, generated platform scaffolding, and the toolchain issues in
  the macOS plan must move together.
- Do not combine an upgrade family with unrelated product work.
- Do not use an unbounded `--major-versions` sweep.

## Phase 0: Baseline and targets

- [ ] Run `flutter pub outdated` and record the direct-package target versions
      in this plan or the implementation PR before changing constraints.
- [ ] Confirm the current Flutter/Dart versions used locally and in CI remain
      compatible with each proposed target.
- [ ] Create a rollback commit before every upgrade family.

## Phase 1: Compatible updates

- [ ] Run `flutter pub upgrade` while retaining existing direct dependency
      constraints.
- [ ] Review the complete `pubspec.lock` diff; keep only solver changes
      explained by the compatible update.
- [ ] Commit the lockfile-only update separately after the verification gates
      pass.

## Phase 2: Major-version families

- [ ] Widen and upgrade one direct-package family at a time; inspect
      `pubspec.yaml`, `pubspec.lock`, source, and generated-file diffs before
      proceeding.
- [ ] Upgrade the Riverpod family in lockstep: `flutter_riverpod`,
      `riverpod_annotation`, and `riverpod_generator`. Run
      `dart run build_runner build --delete-conflicting-outputs`, review all
      generated `.g.dart` changes, then repeat the format gate.
- [ ] Upgrade analyzer-coupled tooling last, after any future SDK decision:
      `very_good_analysis`, then `dart_code_linter` and its custom-lint
      ecosystem.
- [ ] Upgrade other direct packages singly unless pub.dev documents a required
      compatibility family.

## Verification for every stage

- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test`
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `dart run dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning`
- [ ] Pull-request CI, including the macOS/Linux/Windows release-build matrix
- [ ] Check whether the upgrade changes runtime behavior or security posture;
      update `CHANGELOG.md` when it does, otherwise use `CHANGELOG.dev.md`.

## Acceptance criteria

- [ ] Each commit is independently revertible and names its upgraded family.
- [ ] Dependency constraints, lockfile, code generation, and docs agree.
- [ ] All local gates and CI pass after each stage.
- [ ] No Flutter SDK change is smuggled into a package-only upgrade.

## Completion steps

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Log the completed dependency work in the appropriate changelog.

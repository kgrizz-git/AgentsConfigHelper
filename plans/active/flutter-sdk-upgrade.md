# Plan: Flutter SDK Upgrade

Last reviewed: 2026-08-21
Date: 2026-08-21
Author: maintainers
Status: in progress — local verification complete; CI pending
Linked issue/PR: n/a

## Goal

Move the project and CI from Flutter 3.44.9 / Dart 3.12.2 to Flutter 3.47.1 /
Dart 3.13.1. The newer toolchain also unlocks the previously deferred analyzer and
Riverpod family, so this change includes that coupled migration.

## Scope and boundaries

- Pin CI to the exact tested stable Flutter release.
- Refresh dependencies and commit resulting lockfile changes only when the
  solver explains them.
- Do not use dependency overrides to force an incompatible analyzer graph.
- Keep unrelated product changes out of this toolchain migration.
- Do not regenerate platform scaffolding unless Flutter identifies a required
  migration.

## Implementation

- [x] Upgrade the local stable SDK to Flutter 3.47.1 / Dart 3.13.1.
- [x] Pin all CI jobs to Flutter 3.47.1.
- [x] Update the app SDK floor to Dart 3.13 and inspect the resolved lockfile diff.
- [x] Upgrade the now-compatible Riverpod/analyzer toolchain family and regenerate
  Riverpod output.
- [x] Run format, analyze, tests, metrics, and a local macOS release build.
- [ ] Confirm the Linux and Windows CI release builds pass on the new pin.
- [x] Reassess the Riverpod/analyzer upgrade family after the SDK gates pass.

## Outcome

- Flutter 3.47.1 bundles Dart 3.13.1; `pubspec.yaml` now declares `sdk: ^3.13.0`.
- Flutter 3.47's flexible `meta` constraint permits the analyzer versions required by
  `build_runner 2.16.0`, `dart_code_linter 4.2.1`, and the Riverpod 3.4 / annotation
  and generator 4.0 family. No dependency overrides were required.
- The migration refreshes generated providers, raises the macOS deployment target to
  12.0 as required by current Flutter tooling, and applies Flutter's recommended
  platform-directory analyzer exclusions.
- `flutter pub outdated` reports all direct and development dependencies up to date.

## Acceptance criteria

- [x] Local Flutter and CI use the same exact stable version.
- [x] No unexplained dependency, generated-code, or platform-scaffold diff.
- [x] Local quality gates and macOS release build pass.
- [ ] CI release-build matrix passes.
- [x] The coupled analyzer/Riverpod migration is documented in the dependency-upgrades
  plan; unrelated future upgrades remain separate.

## Completion steps

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Record the SDK/toolchain change in `CHANGELOG.dev.md`.

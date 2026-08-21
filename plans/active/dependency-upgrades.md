# Plan: Dependency Upgrades

Last reviewed: 2026-08-21
Date: 2026-08-21
Author: maintainers
Status: in progress (Phase 0 and Phase 1 complete; Phase 2 not started)
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

- [x] Run `flutter pub outdated` and record the direct-package target versions
      in this plan or the implementation PR before changing constraints.
- [x] Confirm the current Flutter/Dart versions used locally and in CI remain
      compatible with each proposed target.
- [x] Record the current HEAD as the rollback point before every upgrade family.

Baseline toolchain (2026-08-21): Flutter 3.44.9 stable, Dart 3.12.2,
`pubspec.yaml` `environment.sdk: ^3.12.2`. Baseline gates were all green before
any change: `flutter analyze --fatal-infos` clean, `flutter test` 192/192
passing, `dart format` 0 changed, `dart_code_linter:metrics` no issues.

### Direct-package target inventory (Phase 2 candidates)

Recorded from `flutter pub outdated` at baseline. No constraint in
`pubspec.yaml` was changed in Phase 1, so every entry below is still pending.

| Package | Current | Resolvable | Latest | Notes |
| --- | --- | --- | --- | --- |
| `flutter_riverpod` | 2.6.1 | 3.3.2 | 3.4.2 | Major; upgrade in lockstep with the Riverpod family |
| `riverpod_annotation` | 2.6.1 | 4.0.3 | 4.0.6 | Major; Riverpod family |
| `riverpod_generator` (dev) | 2.6.5 | 4.0.4 | 4.0.8 | Major; Riverpod family, requires `build_runner` re-run |
| `build_runner` (dev) | 2.5.4 | 2.15.1 | 2.16.0 | Minor-range but blocked by the `build`/`source_gen` family |
| `dart_code_linter` (dev) | 3.1.1 | 4.2.1 | 4.2.1 | Major; analyzer-coupled, upgrade last |
| `very_good_analysis` (dev) | 10.3.0 | — | 10.3.0 | Already current; analyzer-coupled |

Other direct dependencies (`cupertino_icons`, `equatable`, `grapheme_splitter`,
`multi_split_view`, `path`, `path_provider`, `toml`, `url_launcher`, `yaml`,
`yaml_edit`) were already at their latest resolvable versions.

Also noted for Phase 2 sequencing: `build_resolvers` and `build_runner_core`
are transitive dev packages now marked **discontinued** on pub.dev; the
`build_runner`/`source_gen` family upgrade should retire them.

## Phase 1: Compatible updates

- [x] Run `flutter pub upgrade` while retaining existing direct dependency
      constraints.
- [x] Review the complete `pubspec.lock` diff; keep only solver changes
      explained by the compatible update.
- [x] Commit the lockfile-only update separately after the verification gates
      pass.

Outcome: `flutter pub upgrade` changed exactly one package and `pubspec.yaml`
was not modified. The entire `pubspec.lock` diff was 2 lines:

- `vm_service` 15.2.0 → 15.3.0 (transitive, with updated `sha256`)

`vm_service` reaches the graph only through `flutter_test`/test tooling and does
not appear in the non-dev dependency tree, so this update carries no runtime or
security posture change for the shipped app. It was the only package reported as
`Upgradable` at baseline; the remaining 29 need constraint widening and are
deferred to Phase 2. No solver churn, no SDK constraint change, and no
generated-code changes were produced. All Phase 1 verification gates passed
again after the upgrade (analyze clean, 192/192 tests, format clean, metrics
clean).

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

### Current Phase 2 blocker (2026-08-21)

Do not use `dependency_overrides` to force the Riverpod major upgrade under the
current Flutter SDK. Dry-run resolution established that Flutter 3.44.9's
`meta` 1.17.0 pin prevents the analyzer versions required by
`riverpod_generator` 4.0.6+ and `dart_code_linter` 4.x. The Riverpod 3/4 family
therefore needs a compatible Flutter/analyzer toolchain decision first; that is
outside this package-only plan. When it is unblocked, upgrade `build_runner`,
`source_gen`, `dart_code_linter`, and the Riverpod family in separately reviewed
commits, regenerate `lib/state/providers.g.dart`, then run the full gate.

## Verification for every stage

- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test`
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `dart run dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning`
- [ ] Pull-request CI, including the macOS/Linux/Windows release-build matrix
- [ ] Check whether the upgrade changes runtime behavior or security posture;
      update `CHANGELOG.md` when it does, otherwise use `CHANGELOG.dev.md`.

Phase 1 verification (2026-08-21): the four local gates were run before and
after `flutter pub upgrade` and all passed both times. The `vm_service` bump is
dev-only tooling with no runtime/security posture change, so it was recorded in
`CHANGELOG.dev.md`. PR CI (the release-build matrix) still runs on the pull
request and is not something the local Phase 1 commit can tick off on its own.

## Acceptance criteria

- [ ] Each commit is independently revertible and names its upgraded family.
- [ ] Dependency constraints, lockfile, code generation, and docs agree.
- [ ] All local gates and CI pass after each stage.
- [ ] No Flutter SDK change is smuggled into a package-only upgrade.

## Completion steps

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Log the completed dependency work in the appropriate changelog.

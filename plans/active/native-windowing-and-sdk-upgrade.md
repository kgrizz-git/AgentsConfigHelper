# Plan: Native Windowing Migration and Flutter 3.50 Upgrade

Last reviewed: 2026-11-22
Date: 2026-11-22
Author: maintainers
Status: active
Tracking: `TO_DO.md` → Windowing and toolchain upgrade

## Goal

Move the desktop windowing layer from the deprecated federated plugins (`window_manager`
0.5.2, `screen_retriever` 0.2.2) to the nativeapi-based releases (0.7.1 / 0.4.1), which
requires Flutter 3.50 / Dart 3.14; and stop Dependabot from folding that upgrade into the
shared pub group where it cannot resolve.

## Background

Dependabot PR #87 (`build(deps): bump the pub-minor-patch group with 2 updates`) fails CI.
It proposes `window_manager ^0.7.0` and `screen_retriever ^0.4.0`, which declare
`sdk: ^3.14.0` / `flutter: >=3.50.0`. CI pins Flutter 3.47.1 (Dart 3.13.1) at
`.github/workflows/ci.yml:22`, so `flutter pub get` fails at dependency resolution in the
Analyze, Tests, and Build (ubuntu) jobs; the macOS and Windows build jobs are cancelled by
fail-fast rather than failing independently.

Three constraints shape this plan:

1. **The two packages cannot be split.** `window_manager 0.5.2` itself declares
   `screen_retriever: ^0.2.2` (`pubspec.yaml:32` of that package), so `screen_retriever`
   cannot move first. After `window_manager 0.7.1` the dependency is gone, so the pair is
   only coupled by the single function in `lib/main.dart` that uses both.
2. **`legacy.dart` is not a shipping option.** Both packages moved the 0.5.x/0.2.x API to
   `package:<pkg>/legacy.dart` and marked it `@Deprecated`. Switching only the imports
   compiles but produces 16 `deprecated_member_use` infos, and CI runs
   `flutter analyze --fatal-infos` (`.github/workflows/ci.yml:27`).
3. **The 0.6.0/0.3.1 interim is rejected.** It resolves on Dart 3.13 through
   `nativeapi 0.5.x`, but `WindowManager.getCurrent()` in that line resolves only an
   *active* window on Windows and the legacy bridge caches the first result:

   ```dart
   // window_manager 0.6.0, lib/src/legacy/window_manager.dart:77-81
   nativeapi.Window? get _target {
     return _window ??= tryNative<WindowApi.Window?>(
       () => nativeapi.WindowManager.instance.getCurrent(),
     );
   }
   ```

   This app configures its window before `runApp()` (`lib/main.dart:227-236`) while the
   Windows runner shows the window only from the first-frame callback
   (`windows/runner/flutter_window.cpp:30-32`). Every call would therefore no-op silently,
   losing the restored bounds. `window_manager 0.7.1` fixes exactly this
   (`_findHiddenWindowOnWindows()`, "resolve a hidden startup window") and requires
   `nativeapi ^0.6.2`.

## Scope and boundaries

### In scope

- Contain the Dependabot noise for the coupled windowing pair.
- Raise the pinned toolchain to Flutter 3.50.x / Dart 3.14.
- Migrate `lib/main.dart` to the native windowing and display APIs.
- Regenerate the committed platform plugin registrants.
- Give Linux CI jobs that build native assets their system prerequisites.
- Keep the changelogs and this plan in step with what actually ships.

### Out of scope

- Any `window_manager 0.6.0` / `screen_retriever 0.3.1` intermediate release.
- New windowing features (multi-window, custom captions, visual effects).
- Prebuilt macOS artifacts, Developer ID signing, or notarization
  (see `docs/adr/ADR-002-macos-file-access.md`).
- Bulk transitive upgrades unrelated to the toolchain or the windowing packages.

## Pull-request map

Each row is an independent PR against `main`. Only Phase 0 lives on this branch.

| PR | Branch | Contents | Depends on |
| --- | --- | --- | --- |
| 1 | `plan/windowing-and-sdk-upgrade` (this branch) | This plan, the `TO_DO.md` entry, `CHANGELOG.dev.md`, the `.github/dependabot.yml` carve-out, and the stale-lockfile correction | — |
| 2 | `chore/flutter-350-upgrade` | Toolchain only: CI pins, SDK floor, lockfile, formatting/analyzer/scaffolding fallout | PR 1 |
| 3 | `feat/native-windowing-migration` | `window_manager 0.7.1` + `screen_retriever 0.4.1`, native rewrite, regenerated registrants, Linux CI prerequisites | PR 2 |
| 4 | `test/window-layer-coverage` | Testable seam plus unit tests for the window/display decisions | PR 3 |

Phase 3 is optional but strongly recommended: after Phase 2 the window layer has zero
automated coverage, and the Windows defect above is precisely the class of bug a silent
no-op produces.

## Phase 0 — Dependabot containment and lockfile consistency (PR 1)

### Phase 0 changes

- Add `exclude-patterns` for `window_manager` and `screen_retriever` to the broad group and
  add a dedicated group that keeps the pair together:

  ```yaml
      groups:
        pub-minor-patch:
          applies-to: version-updates
          patterns:
            - "*"
          exclude-patterns:
            - "window_manager"
            - "screen_retriever"
          update-types:
            - "minor"
            - "patch"
        pub-windowing-nativeapi:
          applies-to: version-updates
          patterns:
            - "window_manager"
            - "screen_retriever"
          update-types:
            - "minor"
            - "patch"
  ```

- Add this plan to `plans/active/` and its single linked entry to `TO_DO.md`.
- Record the developer-only config change in `CHANGELOG.dev.md`.
- Correct the stale `pubspec.lock` entry: the committed lock was resolved under
  Flutter 3.44 (`sdks.flutter: >=3.44.0`, `test_api 0.7.14`), so `flutter pub get` on the
  pinned 3.47.1 toolchain rewrites it to `>=3.47.0` / `test_api 0.7.12`. This is a
  pre-existing inconsistency, not a dependency change: the pre-commit `dart-code-linter`
  hook runs `flutter pub get` on every commit, so leaving it out makes every commit on the
  pinned SDK fail the hook. Phase 1 regenerates the lock again on the 3.50.x toolchain.

### Why this mechanism

`exclude-patterns` only un-groups a dependency; it still gets a PR. That is intended: the
windowing pair must stay visible until it is migrated, but it must not drag unrelated patch
bumps into an un-mergeable grouped PR (`open-pull-requests-limit: 5`,
`.github/dependabot.yml:9`). `ignore` was rejected because it suppresses the update
entirely, including after Phase 2 when the pair should become mergeable again.

### Phase 0 checks

- `python3 -c "import yaml,sys; yaml.safe_load(open('.github/dependabot.yml'))"` — valid YAML.
- Pre-commit hooks: `markdownlint` on the new plan and `TO_DO.md`.
- Docs integrity CI job: internal link checker and its unit tests.
- Manual: grep `plans/active/` against `TO_DO.md` and confirm a one-to-one mapping.
- Confirm no Dart or dependency change: `git diff --stat` touches only docs,
  `.github/dependabot.yml`, and the two SDK-pinned lockfile fields.

### Phase 0 acceptance

- [ ] The broad group no longer matches either windowing package.
- [ ] The dedicated group matches exactly those two packages.
- [ ] This plan has one open `TO_DO.md` entry that links back to it.
- [ ] Docs integrity and markdownlint pass.
- [ ] The only `pubspec.lock` change is the SDK-pinned `test_api` version and the
      `sdks.flutter` floor.

### Follow-up check after merge

Confirm the grouping on the next scheduled Dependabot run (the 20th of the month, per
`.github/dependabot.yml:7`) or via the repository's Dependabot "check for updates" control
if available. Expect one isolated `pub-windowing-nativeapi` PR and a separately mergeable
broad group.

## Phase 1 — Flutter 3.50.x pin only (PR 2)

This PR changes the toolchain and nothing else. Keeping the SDK bump separate makes any
Phase 2 regression unambiguously attributable to the windowing migration.

### Phase 1 changes

- `pubspec.yaml:22`: `sdk: ^3.13.0` → `^3.14.0`.
- `.github/workflows/ci.yml:22`, `:40`, `:228`: `flutter-version: "3.47.1"` → the tested
  3.50.x release, pinned exactly in all three jobs.
- Regenerate `pubspec.lock` on the exact pinned toolchain and review every entry.
- Apply whatever the new SDK requires: formatting reflow, analyzer fixes, Riverpod output
  regeneration (`lib/state/providers.g.dart`), or a Flutter-recommended platform
  scaffolding migration.

### Phase 1 checks

- `flutter --version` matches the CI pin locally before starting.
- `flutter pub get`, then review the lockfile diff: every change must be explainable by
  the new SDK constraint or a package's SDK floor, never a bulk transitive drift.
- `dart format --output=none --set-exit-if-changed .` — a formatter change is expected to
  be possible on an SDK bump; if it reflows files, keep it as its own commit.
- `flutter analyze --fatal-infos`.
- `flutter pub run dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning`.
- `flutter test --coverage`, then the existing 80% coverage gate (excluding vendor).
- `flutter build macos --release` locally.
- CI release builds on macOS, Linux (`ninja-build libgtk-3-dev` already installed at
  `.github/workflows/ci.yml:236-240`), and Windows.
- macOS entitlements job: App Sandbox must remain absent.
- `flutter pub outdated` review; record any deliberately deferred major in this plan.

### Phase 1 acceptance

- [ ] All CI jobs green on the new pin.
- [ ] No `window_manager` or `screen_retriever` constraint change in this PR.
- [ ] No unexplained lockfile or platform-scaffold diff.
- [ ] No new analyzer, formatter, or metrics suppressions.

## Phase 2 — Windowing migration (PR 3)

### Phase 2 changes

- `pubspec.yaml:42` → `screen_retriever: ^0.4.1`, `pubspec.yaml:45` →
  `window_manager: ^0.7.1` (which pulls `nativeapi ^0.6.2`).
- Rewrite the window and display setup in `lib/main.dart` (`:128-179` configuration,
  `:186-222` bounds listener) against the native API:
  - `DisplayManager.instance.getPrimary()` is nullable and `getAll()` is synchronous;
    drop the `await`s and route a null primary through the existing fallback in
    `lib/services/desktop_window_configuration.dart:15-23`.
  - Map the work area via `Display.workArea` and the exported `RectangleToRect`
    conversion; copy geometry out of any `Display` before disposing it.
  - Resolve the window through `WindowManager`, tolerating a not-yet-visible window, and
    reproduce the `waitUntilReadyToShow` ordering explicitly (minimum size, bounds, show,
    focus) without flicker or a flash at the default size.
  - Replace the `WindowListener` mixin with the native event listener and keep the
    debounced bounds save. Treat close as a close *request*: snapshot bounds, then let the
    close proceed — never veto it accidentally.
  - Native state getters are synchronous, so the save path no longer `await`s
    `isMaximized` / `isMinimized` / `isFullScreen` / `getBounds`.
- Regenerate the committed platform registrants and delete stale plugin references:
  `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`,
  `linux/flutter/generated_plugin_registrant.cc`.
- Give the Linux **Tests** job the native build prerequisites. `cnativeapi`'s build hook
  compiles C++ and calls `pkg-config` for `gtk+-3.0 x11 xi`; the Tests job currently goes
  straight from `flutter pub get` to `flutter test --coverage`
  (`.github/workflows/ci.yml:30-44`) and has no apt step. Add
  `sudo apt-get install -y ninja-build libgtk-3-dev libx11-dev libxi-dev pkg-config`
  before the test run, and install the same set explicitly in the Build job rather than
  relying on transitive pulls.
- Changelogs: `CHANGELOG.md` for the user-visible geometry corrections (display work area
  and identifiers are now correct on every platform); `CHANGELOG.dev.md` for the
  toolchain/CI side.

### Phase 2 checks

- Static gates: `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`,
  `dart_code_linter` metrics.
- **Legacy-import gate:** assert no `legacy.dart` import survives, e.g.
  `rg -n "window_manager/legacy|screen_retriever/legacy" lib test` returns nothing.
- **Deprecation gate:** the analyze output contains no `deprecated_member_use`.
- `flutter test --coverage` plus the coverage gate.
- `flutter build macos --release`, `flutter build linux --release`,
  `flutter build windows --release`.
- macOS entitlements job.
- Confirm no stale plugin symbols remain: `rg -n "window_manager|screen_retriever"` over
  `macos/`, `windows/`, `linux/` should match only intentionally retained text.

### Manual smoke matrix

Required, because no test covers this layer. Run on real or CI-provisioned builds.

| # | Scenario | Expected |
| --- | --- | --- |
| 1 | First launch, no stored bounds | 75% of the work area, centered, never below 800x600 |
| 2 | Stored bounds inside a connected display | Restored exactly, no default-size flash |
| 3 | Stored bounds on a disconnected display | Clamped to a usable display or discarded |
| 4 | Multi-monitor with mixed DPI | Correct placement and size on the intended display |
| 5 | Move and resize | Persisted after the ~400 ms debounce |
| 6 | Close window | Final bounds persisted before exit; close not vetoed |
| 7 | Maximize, minimize, full screen | No bounds save while in those states |
| 8 | Windows cold start | Window configured despite being hidden at startup |
| 9 | Linux X11 | Move, resize, and close persistence all work |
| 10 | Linux Wayland | No crash; document any move-reporting limitation |
| 11 | App icon and taskbar | Unchanged from the previous release |

### Phase 2 acceptance

- [ ] All CI jobs green, including the Linux Tests job with the new prerequisites.
- [ ] Zero legacy imports and zero deprecation infos.
- [ ] Smoke matrix signed off on macOS, Windows, Linux X11, and Linux Wayland.
- [ ] No silent failure path: a window that cannot be resolved must log rather than no-op.

## Phase 3 — Automated coverage for the window layer (PR 4)

### Phase 3 changes

- Extract the startup decisions from `lib/main.dart` into a service that accepts an
  injectable adapter for the window and displays, so the logic is testable without native
  calls. Keep the widget/entrypoint thin.
- Add unit tests for: null primary display fallback, restored-bounds clamping across
  displays, geometry mapping from the native work area, and the close-save ordering.
- Record any residual platform behaviour that stays manual (Wayland move reporting).

### Phase 3 checks

- Standard gates: format, `flutter analyze --fatal-infos`, metrics, tests, coverage gate.
- The new tests must fail if the fallback or clamping is removed (mutation spot-check).
- `flutter build macos --release` as a compile proof.

### Phase 3 acceptance

- [ ] The window/display decision logic is covered by tests that do not require a display.
- [ ] Coverage does not regress; the new files are exercised.
- [ ] `lib/main.dart` remains a thin composition root.

## Check matrix

| Check | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- |
| markdownlint / docs integrity | yes | — | — | — |
| `flutter pub get` + lockfile review | — | yes | yes | yes |
| `dart format --set-exit-if-changed` | — | yes | yes | yes |
| `flutter analyze --fatal-infos` | — | yes | yes | yes |
| `dart_code_linter` metrics | — | yes | yes | yes |
| `flutter test --coverage` + 80% gate | — | yes | yes | yes |
| Legacy-import / deprecation gates | — | — | yes | yes |
| macOS release build | — | yes | yes | yes |
| Linux release build | — | CI | CI | CI |
| Windows release build | — | CI | CI | CI |
| macOS entitlements (no sandbox) | — | yes | yes | yes |
| Manual smoke matrix | — | — | yes | — |

## Risks and open questions

1. **Windows hidden startup.** The regression this plan exists to avoid. Phase 2 must
   explicitly verify scenario 8; a silent no-op is the failure mode, not an exception.
2. **Linux Tests job.** Unproven whether `flutter test` builds native code assets eagerly
   or on first FFI use. Installing the prerequisites is cheap and removes the question.
3. **Wayland.** Window-move reporting is documented as incomplete upstream, so bounds
   persistence may degrade there. This is not a Phase 2 blocker, but it must be measured
   and recorded rather than assumed equivalent to X11.
4. **nativeapi youth.** 0.6.x is a young native core with frequent fixes. Consider whether
   `^0.6.2` is an acceptable range or whether the pair should be pinned exactly and
   upgraded deliberately.
5. **Build cost.** All three platforms now compile a C++ core at build time. CI build
   duration increases and Windows gains a normal MSVC requirement.
6. **Formatter churn.** A Dart 3.14 formatter may reflow files unrelated to this work.
   Keep that as its own commit so review stays honest.
7. **`material_ui` arrives transitively.** `window_manager 0.7.x` depends on it for caption
   widgets this app does not use; it lands in the lockfile regardless.
8. **Unknown Flutter 3.50 scaffolding changes.** Phase 1 includes a discovery step; if a
   platform migration is required, apply it there rather than in Phase 2.

## Rejected and deferred options

- **`window_manager 0.6.0` + `screen_retriever 0.3.1` now**: rejected for the Windows
  hidden-window defect above; it would add a second native-core QA cycle for no gain.
- **A separate `screen_retriever` PR**: impossible while `window_manager` is 0.5.2.
- **Dependabot `ignore` for these packages**: rejected in favour of the dedicated group;
  see Phase 0.
- **Prebuilt/notarized macOS distribution**: remains out of scope per ADR-002.

## Acceptance criteria

- [ ] Dependabot keeps the windowing pair isolated from the broad group.
- [ ] Flutter and CI use the same exact pinned stable version at 3.50.x.
- [ ] The windowing packages are on 0.7.1 / 0.4.1 with no `legacy.dart` imports and no
      deprecation infos.
- [ ] The regenerated platform registrants contain no stale plugin entries.
- [ ] Linux CI jobs that build native assets install their prerequisites explicitly.
- [ ] Release builds pass on macOS, Linux, and Windows.
- [ ] The manual smoke matrix passes on all four targets.
- [ ] Both changelogs describe what actually shipped.

## Completion steps

Archive this plan as the final commit on the Phase 3 branch (or the Phase 2 branch if
Phase 3 is dropped by decision recorded here), not as a post-merge step on `main`. Remove
the `TO_DO.md` entry at the same time, and confirm the public and developer changelogs
match the shipped state.

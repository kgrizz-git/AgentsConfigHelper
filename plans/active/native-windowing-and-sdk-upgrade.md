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
`.github/workflows/ci.yml:22`, `:40`, and `:228`, so `flutter pub get` fails at dependency
resolution in the Analyze, Tests, and Build (ubuntu) jobs; the macOS and Windows build jobs
are cancelled by fail-fast rather than failing independently.

Three constraints shape this plan:

1. **The two packages cannot be split.** `window_manager 0.5.2` itself declares
   `screen_retriever: ^0.2.2` (`pubspec.yaml:32` of that package), so `screen_retriever`
   cannot move first. After `window_manager 0.7.1` the dependency is gone, so the pair is
   only coupled by the single function in `lib/main.dart` that uses both.
2. **`legacy.dart` is not a shipping option.** Both packages moved the 0.5.x/0.2.x API to
   `package:<pkg>/legacy.dart` and marked it `@Deprecated`. Switching only the imports
   compiles but produced 16 `deprecated_member_use` infos when measured locally against both
   packages, and CI runs `flutter analyze --fatal-infos`
   (`.github/workflows/ci.yml:27`).
3. **The 0.6.0/0.3.1 interim is rejected.** It resolves on Dart 3.13 through
   `nativeapi 0.5.x`, whose `WindowManager.getCurrent()` returns only an *active* window on
   Windows. This app configures its window before `runApp()` (`lib/main.dart:226-242`) while
   the Windows runner shows the window only from the first-frame callback
   (`windows/runner/flutter_window.cpp:30-32`), so every call made during that hidden window
   no-ops: the restored bounds are lost and the runner shows its default geometry. A later
   call can succeed once the window is visible, but this startup path only calls once.
   `window_manager 0.6.0`'s legacy bridge re-queries on each access but still returns null
   for the whole hidden period:

   ```dart
   // window_manager 0.6.0, lib/src/legacy/window_manager.dart:77-81
   nativeapi.Window? get _target {
     return _window ??= tryNative<nativeapi.Window?>(
       () => nativeapi.WindowManager.instance.getCurrent(),
     );
   }
   ```

   `??=` caches only a non-null result, so the bridge retries and keeps failing. The durable
   fix is `nativeapi 0.6.2`, which resolves the current process window across isolate threads
   and hidden startup windows, including after a hot restart. `window_manager 0.7.1` requires
   it and adds a `_findHiddenWindowOnWindows()` workaround in its *legacy* bridge, which
   Phase 2 does not use because `legacy.dart` is excluded. Phase 2 must therefore exercise
   the **native** resolution path (`getCurrent()`), not the bridge.

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
| 2 | `chore/flutter-350-upgrade` | Toolchain: CI pins, SDK floor, lockfile, and the SDK-mandated import/analyzer fallout | PR 1 |
| 3 | `feat/native-windowing-migration` | `window_manager 0.7.1` + `screen_retriever 0.4.1`, native rewrite with the final adapter seam, regenerated registrants, Linux CI prerequisites | PR 2 |
| 4 | `test/window-layer-coverage` | Unit tests against the Phase 2 adapter seam; no restructuring of the migrated code | PR 3 |

Phase 3 is required, not optional. After Phase 2 the native adapter, the startup
orchestration, and the event/listener wiring have no automated coverage, and the Windows
defect above is exactly the class of bug a silent no-op produces. Phase 2 must land the
final adapter architecture; Phase 3 then adds tests rather than re-extracting the same code.

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
  Flutter 3.44 (`sdks.flutter: >=3.44.0`, `test_api 0.7.14`), while Flutter 3.47.1's
  `flutter_test` pins `test_api 0.7.12` exactly, so any resolution on the pinned toolchain
  rewrites the version, its checksum, and the SDK floor. This is a pre-existing
  inconsistency, not an SDK incompatibility or a direct dependency change. The pre-commit
  `dart-code-linter` hook runs `flutter pub run dart_code_linter:metrics`; that implicit
  package resolution rewrites the stale lock, and pre-commit then fails because a hook
  modified a tracked file — so leaving it out blocks every commit on the pinned SDK.
  Phase 1 regenerates the lock again on the 3.50.x toolchain.
- Close Dependabot PR #87 as superseded when this PR lands: it targets 0.7.0/0.4.0, which
  cannot resolve on the pinned SDK, and current releases are 0.7.1/0.4.1. Dependabot may
  re-propose the pair on its next scheduled run; once this carve-out is on `main` that
  becomes a single `pub-windowing-nativeapi` PR instead of a poisoned broad group.

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
- Prove the lockfile correction is harmless: `flutter pub get` (a second run must leave the
  lock unchanged), `flutter analyze --fatal-infos`, and `flutter test --coverage` plus the
  coverage gate.
- Generated-drift gate: `git diff --exit-code` after the Dart checks, so nothing produced
  during verification is accidentally left out of the PR.
- Confirm no direct dependency change: `git diff --stat` touches only docs,
  `.github/dependabot.yml`, and the three SDK-pinned lockfile fields (the `test_api`
  version, its regenerated checksum, and the `sdks.flutter` floor).

### Phase 0 acceptance

- [ ] The broad group no longer matches either windowing package.
- [ ] The dedicated group matches exactly those two packages.
- [ ] This plan has one open `TO_DO.md` entry that links back to it.
- [ ] Docs integrity and markdownlint pass.
- [ ] The only `pubspec.lock` change is the SDK-pinned `test_api` version, its regenerated
      checksum, and the `sdks.flutter` floor.
- [ ] Dependabot PR #87 is closed as superseded as part of landing this PR.

### Follow-up check after merge

Confirm the grouping on the next scheduled Dependabot run (the 20th of the month, per
`.github/dependabot.yml:7`) or via the repository's Dependabot "check for updates" control
if available. Validate two things: any broad-group PR excludes both windowing packages, and
the pair appears only in `pub-windowing-nativeapi`. Do not require both PRs to exist — a
month with no other updates should produce only the dedicated group, or nothing at all.

## Phase 1 — Flutter 3.50.x pin only (PR 2)

This PR changes the toolchain and the code changes that toolchain forces (Material imports,
analyzer-plugin syntax, new lints), but not the windowing packages. Keeping the SDK bump
separate still makes any Phase 2 regression unambiguously attributable to the windowing
migration.

### Phase 1 changes

- `pubspec.yaml:22`: `sdk: ^3.13.0` → `^3.14.0`.
- `.github/workflows/ci.yml:22`, `:40`, `:228`: `flutter-version: "3.47.1"` → the tested
  3.50.x release, pinned exactly in all three jobs.
- Regenerate `pubspec.lock` on the exact pinned toolchain and review every entry.
- Apply whatever the new SDK requires: formatting reflow, analyzer fixes, Riverpod output
  regeneration (`dart run build_runner build --delete-conflicting-outputs`, then review
  `lib/state/providers.g.dart`), or a Flutter-recommended platform scaffolding migration.
  In practice Flutter 3.50 forced three of these:
  - `package:flutter/material.dart` is deprecated, so every import moves to
    `package:material_ui/material_ui.dart` (42 files) and `material_ui` becomes a direct
    dependency; it was already transitive through `flutter_riverpod`.
  - Dart 3.14 deprecates the legacy analyzer-plugin declaration, so `dart_code_linter`
    moves from `analyzer: plugins: [...]` to the top-level `plugins:` map.
  - New lints must be cleared: `unnecessary_unawaited` (`showDialog` is
    `@awaitNotRequired` in 3.50) and `avoid_types_on_closure_parameters`.
- Update the toolchain versions advertised outside the changelogs: `README.md:12`
  (Flutter badge) and `README.md:99-100` (Flutter/Dart minimums).

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
- No legacy Material import remains:
  `if rg -n "package:flutter/material.dart" lib test; then exit 1; fi`.
- Generated-drift gate: after all gates, `git diff --exit-code` must pass, and a second
  `flutter pub get` must leave `pubspec.lock` and the committed platform generated files
  unchanged. CI regenerates these on the runner but does not fail for a dirty checkout, so
  this is the only check that catches a generated file omitted from the PR.

### Phase 1 acceptance

- [ ] All CI jobs green on the new pin.
- [ ] No `window_manager` or `screen_retriever` constraint change in this PR.
- [ ] No unexplained lockfile or platform-scaffold diff.
- [ ] No new analyzer, formatter, or metrics suppressions.

## Phase 2 — Windowing migration (PR 3)

### Phase 2 changes

- `pubspec.yaml:42` → `screen_retriever: ^0.4.1`, `pubspec.yaml:45` →
  `window_manager: ^0.7.1` (which pulls `nativeapi ^0.6.2`).
- Rewrite the window and display setup in `lib/main.dart` (`:121-183` configuration,
  `:186-222` bounds listener) against the native API:
  - `DisplayManager.instance.getPrimary()` is nullable and `getAll()` is synchronous;
    drop the `await`s and route a null primary through the existing fallback in
    `lib/services/desktop_window_configuration.dart:15-23`. Do not force-unwrap.
  - Map the work area via `Display.workArea` and the exported `RectangleToRect`
    conversion. `getPrimary()` and `getAll()` return owned native handles
    (`Display.fromHandle`), and `Display` exposes a public `dispose()`. Copy the geometry
    into plain Dart values, then dispose those handles deterministically — preferably in a
    `finally` — rather than relying on the finalizer.
  - Reproduce the full startup sequence, not just "minimum size, bounds, show, focus".
    Today `WindowOptions` and `waitUntilReadyToShow` also supply the initial `size`, the
    title, centering when nothing was restored, and normalization of
    fullscreen/maximized/minimized state (`lib/main.dart:151-183`). Specify the complete
    order — state reset, size, minimum size, bounds when restored (otherwise center), title,
    listener registration, show, focus — and keep the window hidden until the final geometry
    is applied so there is no flash at the runner's default size. Register the listener
    *before* `show()` so a move or close during startup is not missed.
  - Gate only *geometry* persistence during startup, never lifecycle events. Ignore
    move/resize until a startup-complete flag is set by our own `show()` call completing —
    not by polling an OS `isVisible` — and always process close requests from registration
    onward, even while the window is hidden. If the window never becomes visible, a bounded
    timeout must begin processing geometry so the listener cannot stay inert forever.
  - Resolve the window through nativeapi's `WindowManager.getCurrent()` (the nativeapi
    0.6.2 fix this plan depends on), never through the `legacy.dart` bridge. A transient
    null must have a defined recovery: wait for `WindowCreatedEvent` or retry on a
    post-frame callback and apply the pending geometry then. Do not treat "log and return"
    as sufficient; the geometry and the listener still have to be applied, and an
    unrecoverable case must log loudly.
  - Replace the `WindowListener` mixin with the window-scoped native listener
    (`window.addListener(...)`). Keep the debounced bounds save, and handle close as a
    close *request* with durability:
    - serialize bounds writes through a single FIFO chain, and state which request wins:
      the close save is appended to the chain and the handler awaits the **whole chain to
      drain**, not only the currently executing write. Awaiting just the in-flight save is
      insufficient, because a debounce save that already fired but is still queued would
      land after the final write and restore stale geometry;
    - set a `closing` latch before enqueuing the final save. The latch rejects any new
      move/resize save, so no older snapshot can be queued behind it. (Equivalently, stamp
      each save with a monotonically increasing generation and have the store discard
      obsolete writes; pick one invariant and state it. The latch plus a full chain drain
      needs no sequence number.)
    - on close: set the latch, cancel the debounce timer, capture the current bounds, append
      the final save, and await the chain before returning;
    - never reject the close — return normally. Do not call `EventDecision.cancel()`;
    - catch persistence failures and log them, so a failed save cannot accidentally veto
      the close through an escaping exception.
  - Native state getters are synchronous, so the save path no longer `await`s
    `isMaximized` / `isMinimized` / `isFullScreen` / `getBounds`.
- Regenerate the committed platform registrants and delete stale plugin references:
  `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`,
  `linux/flutter/generated_plugin_registrant.cc`, and
  `linux/flutter/generated_plugins.cmake` (which currently lists both old plugins at
  `:7` and `:9`).
- Give the Linux **Tests** job the native build prerequisites. `cnativeapi`'s build hook
  compiles C++ and calls `pkg-config` for `gtk+-3.0 x11 xi`; the Tests job currently goes
  straight from `flutter pub get` to `flutter test --coverage`
  (`.github/workflows/ci.yml:30-44`) and has no apt step. Add `sudo apt-get update` followed
  by `sudo apt-get install -y ninja-build libgtk-3-dev libx11-dev libxi-dev pkg-config`
  before the test run, and install the same set explicitly in the Build job rather than
  relying on transitive pulls.
- Changelogs: `CHANGELOG.md` for the geometry behaviour actually exercised and signed off in
  the smoke matrix (restored-bounds placement across work areas); `CHANGELOG.dev.md` for the
  toolchain/CI side. Do not claim broader platform corrections than were verified — display
  identifiers are not consumed by this app, and Wayland remains unverified.

### Implementation status (2026-11-24)

Phase 2 and Phase 3 are implemented on `fix/native-windowing`: the dependencies resolve
nativeapi 0.6.2, `lib/main.dart` delegates to the adapter/startup/bounds coordinator, the
platform registrants are regenerated, and the Phase 3 unit tests cover the adapter seam.
macOS smoke verified the centered 75% first-launch geometry, exact restored bounds, and
close-time bounds persistence. Windows and Linux X11/Wayland smoke, multi-monitor mixing,
and the full matrix remain before Phase 2 acceptance and plan archival.

### Phase 2 checks

- Static gates: `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze --fatal-infos`, `dart_code_linter` metrics.
- **Legacy-import gate:** assert no `legacy.dart` import survives. A bare `rg` exits 1 when
  it finds nothing, so write it as a positive failure, e.g.
  `if rg -n "window_manager/legacy|screen_retriever/legacy" lib test; then exit 1; fi`.
- **Deprecation gate:** the analyze output contains no `deprecated_member_use`.
- `flutter test --coverage` plus the coverage gate.
- `flutter build macos --release` locally; the Linux and Windows release builds run on their
  own CI runners, not on the macOS development host.
- macOS entitlements job.
- Confirm no stale plugin symbols remain: search `macos/`, `windows/`, and `linux/` for
  `window_manager` and `screen_retriever` and require that every remaining match is
  intentionally retained text.
- Generated-drift gate: a second `flutter pub get` leaves `pubspec.lock` and all five
  generated platform files unchanged, and `git diff --exit-code` is clean after the full
  gate run. CI regenerates these on the runner and will not fail for a dirty checkout, so
  this is what catches a generated file omitted from the PR.

### Manual smoke matrix

Required, because no test covers the native adapter, the startup orchestration, or the
event/listener wiring. Run on real or CI-provisioned builds.

| # | Scenario | Expected |
| --- | --- | --- |
| 1 | First launch, no stored bounds | 75% of the work area, centered, at least 800x600 where the work area allows it |
| 2 | Stored bounds inside a connected display | Restored exactly, no default-size flash |
| 3 | Stored bounds on a disconnected display | Clamped to a usable display or discarded |
| 4 | Multi-monitor with mixed DPI | Correct placement and size on the intended display |
| 5 | Move and resize | Persisted after the ~400 ms debounce |
| 6 | Close the window | Debounce cancelled, bounds write completes before destruction, close not vetoed |
| 7 | Maximize, minimize, full screen | No bounds save while in those states |
| 8 | Windows cold start | Window configured through the native path despite being hidden at startup |
| 9 | Windows hot restart | Window re-resolved after a Flutter hot restart; geometry still applied |
| 10 | Linux X11 | Move, resize, and close persistence all work |
| 11 | Linux Wayland | No crash; document any move-reporting limitation |
| 12 | App icon and taskbar | Unchanged from the previous release |
| 13 | Close immediately after launch, before the window is visible | Close processed; final bounds saved |
| 14 | Move during startup, before the window is shown | Geometry ignored until startup completes, then tracked |
| 15 | Close while a debounce save is already in flight | Final bounds win; the older write does not land last |
| 16 | Close with a debounce save queued behind an in-flight one | Chain drains in order; final bounds are the last write |

### Phase 2 acceptance

- [ ] All CI jobs green, including the Linux Tests job with the new prerequisites.
- [ ] Zero legacy imports and zero deprecation infos.
- [ ] Smoke matrix signed off on macOS, Windows, Linux X11, and Linux Wayland.
- [ ] No silent failure path: an unresolved window is retried or deferred, and the geometry
      and listener are still applied once it resolves; an unrecoverable case logs loudly
      instead of quietly abandoning setup.

## Phase 3 — Automated coverage for the window layer (PR 4)

Phase 2 must land the final adapter architecture. This phase adds tests only; it must not
re-extract or restructure the same code a second time.

### Phase 3 changes

- Add unit tests against the adapter seam introduced in Phase 2, without native calls:
  null primary display fallback, geometry mapping from the native work area, and
  unresolved-window retry/deferral.
- Extend the existing geometry tests rather than duplicating them:
  `test/services/desktop_window_configuration_test.dart` already covers fallback sizing and
  restored-bounds clamping, and `test/services/desktop_window_bounds_store_test.dart`
  covers persistence.
- Cover the behaviour that has no tests today: the bounds write completing before the close
  proceeds and no veto on save failure, debounce cancellation on close, the closing latch and
  a full chain drain covering both an in-flight save and one queued behind it (newest
  snapshot must win), suppression of post-close geometry events, a close request arriving
  before the window is visible, suppression while maximized/minimized/full screen, and
  native event routing to the bounds save.
- Record any residual platform behaviour that stays manual (Wayland move reporting).

### Phase 3 checks

- Standard gates: format, `flutter analyze --fatal-infos`, metrics, tests, coverage gate.
- The new tests must fail if the retry, fallback, or close-ordering logic is removed
  (mutation spot-check).
- `flutter build macos --release` as a compile proof.
- Generated-drift gate: `git diff --exit-code` after the full run.

### Phase 3 acceptance

- [ ] The adapter seam from Phase 2 is covered by tests that do not require a display.
- [ ] Coverage does not regress; the retry, close-ordering, and event-routing paths are
      exercised.
- [ ] `lib/main.dart` remains a thin composition root.

## Check matrix

| Check | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- |
| markdownlint / docs integrity | yes | — | — | — |
| Dependabot grouping re-check | yes | — | — | — |
| `flutter pub get` + lockfile review | yes | yes | yes | yes |
| `dart format --output=none --set-exit-if-changed .` | — | yes | yes | yes |
| `flutter analyze --fatal-infos` | yes | yes | yes | yes |
| `dart_code_linter` metrics | — | yes | yes | yes |
| `flutter test --coverage` + 80% gate | yes | yes | yes | yes |
| Generated-drift gate (`git diff --exit-code`) | yes | yes | yes | yes |
| Platform registrant regeneration review | — | — | yes | — |
| Legacy-import / deprecation gates | — | — | yes | yes |
| macOS release build | — | yes | yes | yes |
| Linux release build | — | CI | CI | CI |
| Windows release build | — | CI | CI | CI |
| macOS entitlements (no sandbox) | — | yes | yes | yes |
| Manual smoke matrix | — | — | yes | — |

## Risks and open questions

1. **Windows hidden startup.** The regression this plan exists to avoid. Phase 2 must
   resolve the window through nativeapi 0.6.2's `getCurrent()` and verify scenarios 8 and 9;
   a silent no-op is the failure mode, not an exception.
2. **Linux Tests job.** Unproven whether `flutter test` builds native code assets eagerly
   or on first FFI use. Installing the prerequisites is cheap and removes the question.
3. **Wayland.** Window-move reporting is documented as incomplete upstream, so bounds
   persistence may degrade there. This is not a Phase 2 blocker, but it must be measured
   and recorded rather than assumed equivalent to X11.
4. **nativeapi youth — decided policy.** Keep the caret ranges in `pubspec.yaml`
   (`window_manager ^0.7.1`, `screen_retriever ^0.4.1`) and rely on `pubspec.lock` to pin the
   transitive `nativeapi` exactly for reproducible builds. Do not add a dependency override.
   Because `nativeapi` is transitive, Dependabot will never surface it directly; review it
   during each Phase 2/3 follow-up and at every `flutter pub outdated` pass, and upgrade it
   deliberately rather than by widening the direct constraints.
5. **Build cost.** All three platforms now compile a C++ core at build time. CI build
   duration increases and Windows gains a normal MSVC requirement.
6. **Formatter churn.** A Dart 3.14 formatter may reflow files unrelated to this work.
   Keep that as its own commit so review stays honest.
7. **`material_ui` remains transitively required.** It is already in the lockfile
   (`pubspec.lock:536-543`); `window_manager 0.7.x` requires it for caption widgets this app
   does not use, so the dependency does not newly "arrive" with this migration.
8. **Unknown Flutter 3.50 scaffolding changes.** Phase 1 includes a discovery step; if a
   platform migration is required, apply it there rather than in Phase 2.
9. **Material namespace split.** Flutter 3.50's `material_ui` is a separate library from the
   deprecated `flutter/material.dart`, so `material_ui`'s `Theme` is a distinct type.
   Third-party widgets that still import `flutter/material.dart` and call `Theme.of(context)`
   will not see this app's `ThemeData` and will fall back to a default. Audit UI
   dependencies when upgrading; `multi_split_view` is unaffected because it uses its own
   `MultiSplitViewTheme`.

## Rejected and deferred options

- **`window_manager 0.6.0` + `screen_retriever 0.3.1` now**: rejected for the Windows
  hidden-window defect above; it would add a second native-core QA cycle for no gain.
- **A separate `screen_retriever` PR**: impossible while `window_manager` is 0.5.2.
- **Dependabot `ignore` for these packages**: rejected in favour of the dedicated group;
  see Phase 0.
- **Prebuilt/notarized macOS distribution**: remains out of scope per ADR-002.

## Acceptance criteria

- [ ] Dependabot keeps the windowing pair isolated from the broad group, and #87 is closed.
- [ ] Flutter and CI use the same exact pinned stable version at 3.50.x.
- [ ] The windowing packages are on 0.7.1 / 0.4.1, resolving `nativeapi 0.6.2` or later,
      with no `legacy.dart` imports and no deprecation infos.
- [ ] All five generated platform files are regenerated with no stale plugin entries.
- [ ] Linux CI jobs that build native assets install their prerequisites explicitly,
      including `apt-get update`.
- [ ] Release builds pass on macOS, Linux, and Windows.
- [ ] The manual smoke matrix passes on all four targets.
- [ ] Both changelogs describe what actually shipped, with no unverified platform claims.

## Completion steps

Archive this plan as the final commit on the Phase 3 branch, not as a post-merge step on
`main`. Remove the `TO_DO.md` entry at the same time, and confirm the public and developer
changelogs match the shipped state.

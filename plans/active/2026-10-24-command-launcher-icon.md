# Plan: macOS Double-Click Launcher and App Icon Association

Last reviewed: 2026-10-24
Date: 2026-10-24
Author: MiMo (agent), maintainer requirements
Status: in-progress (Phases 1-4 implemented and per-phase reviewed; human visual checks open)
Linked issue/PR: n/a
Branch: `feat/command-launcher-icon`

## Goal

Make the source-built macOS app launchable by double-clicking a repo-root
`Launch_AgentsConfigHelper.command` file that Finder displays with the app icon.
Icon association happens on first use of the launcher or `scripts/setup.sh`, is
re-checked (and repaired when missing) on every `dev.sh` run, and the app icon
should also appear in the Dock when the app is run from source, if possible.

## Requirements (maintainer-specified)

1. A `.command` file at the repo root launches the app on double-click. Agreed
   behavior: open the built `.app` — prefer the Release build, fall back to
   Debug, and when neither exists run `flutter build macos --release` first,
   then open the result. Agreed filename: `Launch_AgentsConfigHelper.command`.
2. The first time the launcher **or** `scripts/setup.sh` runs, associate the
   app icon with the `.command` file. `dev.sh` must also associate the icon on
   its runs when it is not already associated.
3. The app icon should appear in the Dock ("taskbar") when run from source,
   if possible.

## Out of scope

- Windows/Linux launchers (Linux already registers a `.desktop` entry via
  `scripts/install_linux_desktop_entry.sh`).
- Distribution, signing, notarization, or any prebuilt macOS artifact
  (ADR-002 keeps macOS source-build-only).
- Custom icons for files other than the launcher.
- Changing `--test-root` smoke semantics.

## Approach

All three entry points share one idempotent helper, so the "first time" and
"if not already associated" requirements unify into a single rule:
**associate whenever the association is missing, otherwise do nothing.** The
first run associates; every later run is a cheap read-only check.

### Icon association mechanism (empirically verified 2026-10-24)

A scratch probe in `tmp/` on this machine established the exact mechanism
(re-run after review with the corrected invocation; same result):

- `osascript -l JavaScript` with the AppKit bridge sets a custom icon in one
  call: `$.NSWorkspace.sharedWorkspace.setIconForFileOptions(icon, path, 0)`
  returned `icon-set-ok` for a PNG source icon.
- macOS stores the icon in the target file's own `com.apple.ResourceFork`
  xattr and flags the file in `com.apple.FinderInfo`. No `Icon\r` sidecar is
  created for a single file (`Icon?` is already in `.gitignore` regardless).
- Detection of "already associated" requires **both** signals: the icon
  payload (`xattr -p com.apple.ResourceFork` succeeds) and the Finder flag
  (`com.apple.FinderInfo` byte 8 = `04`, the `kHasCustomIcon` (0x0400) bit
  in the big-endian finder flags; probe: 32-byte blob). Any partial state —
  flag without payload (exactly what `SetFile -a C` produces) or payload
  without flag — re-associates, so a failed or half-applied attempt can
  never look done and the earlier "flag set, fork gone" limitation is gone.
- Consequence: association is **machine-local state**. A fresh clone (or a
  copy that drops xattrs) shows the generic script icon until the helper runs
  once — which the launcher, `setup.sh`, and `dev.sh` all do automatically.

Invocation details (review corrections; `man osascript` plus measured
behavior on this machine):

- Proven call form (the SpotiBye production launcher, owner-confirmed
  visible in Finder): `osascript -l JavaScript -e '<script>' "$icon"
  "$target"` with `run(argv)` reading `argv[0]`/`argv[1]`, result captured
  as `RESULT=$(...) || true`, success iff `RESULT` is `true`. Paths passed
  after the script become `run`'s argv; `osascript` has no end-of-options
  marker — a `--` argument lands in `argv` as `argv[0]` (measured:
  `osascript -l JavaScript - -- a b` → `["--","a","b"]`), which would make
  `argv[0]`-as-icon-path load a file named `--`. (The stdin form
  `osascript -l JavaScript - "$icon" "$target"` passes paths identically.)
- `NSImage` loaded from the icon path must be checked before calling
  `setIcon`: the API treats a nil image as *remove the custom icon*
  (`NSWorkspace.h`), so a failed icon load must not reach the call.
- A missing `com.apple.FinderInfo` attribute makes `xattr -px` exit 1
  (measured). The read must be explicitly non-failing; see Phase 1.

### Prior art: the SpotiBye launcher

The sibling project ships this exact pattern (repo-root `SpotiBye.command`;
completed plan `2026-10-18-app-icon-and-source-launcher.md`), so its lessons
are imported rather than re-derived:

- `SetFile -a C` is a confirmed dead end: it sets the Finder flag but
  attaches no icon data (measured there), which is why detection above keys
  on the resource fork as well as the flag. It is never a mechanism rung.
- The JXA `NSWorkspace` rung brands a `.command` with the app icon; the
  owner confirmed the icon visibly appears in Finder (2026-10-20).
- A failed attempt writes a **gitignored sentinel** (there:
  `.spotibye-launcher-icon-failed`) so later runs warn once instead of
  nagging; deleting the sentinel retries. Adopted here as
  `.agents-config-helper-launcher-icon-failed`.
- Static pytest checks pin launcher invariants (there:
  `scripts/tests/test_spotibye_command.py` — LF-only, git mode `100755`,
  guard ordered before `setIconForFileOptions`, no `SetFile`). Mirrored
  here as a `tests/` check (Phase 2).
- Running from source must set the icon explicitly at runtime because no
  bundle metadata applies (there: `App.icon` from the rounded PNG); the
  Flutter analog is Phase 3's `applicationIconImage`.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| `Rez`/`SetFile -a C` (Classic tools) | Deprecated and CLT-only; SpotiBye testing confirmed `SetFile -a C` sets the flag with no icon data — never a rung |
| `fileicon` (Homebrew) | Adds an external dependency for one xattr write |
| Finder AppleScript (`set icon of`) | Needs Finder automation (TCC prompts), slow |
| Re-set the icon on every run unconditionally | Touches xattrs needlessly; contradicts the requested one-time semantics |
| Ship a `.app` in `/Applications` with an alias | Out of scope (ADR-002 source-build-only) |
| Dock fix by relaunching via `open` instead of `flutter run` | Loses hot reload; changes the dev workflow for a cosmetic fix |

## Proposed file changes

```text
Launch_AgentsConfigHelper.command  — new double-click launcher (repo root, executable bit set)
scripts/ensure_launcher_icon.sh    — new shared idempotent icon-association helper (macOS-only)
scripts/setup.sh                   — call the helper as a setup step (macOS-only, non-fatal)
dev.sh                             — call the helper at startup (macOS-only, non-fatal)
macos/Runner/AppDelegate.swift     — Dock icon for source runs (Phase 3 only, spike-gated)
README.md                          — "macOS double-click launcher" section (mirror of the
                                     "Linux taskbar icon" section)
CHANGELOG.md                       — user-visible launcher + Dock icon entries
CHANGELOG.dev.md                   — helper wiring in setup.sh/dev.sh
tests/                             — static launcher checks (stdlib unittest)
.gitignore                         — failed-attempt sentinel entry
```

## Phases & checklist

### Phase 1: shared icon-association helper

- [x] `scripts/ensure_launcher_icon.sh`:
      resolve the repo root from `BASH_SOURCE` using the `cd --` / `pwd -P`
      form used by `dev.sh`, with `CDPATH` cleared on that `cd` (a set
      `CDPATH` makes `cd` print the path, which corrupts the captured root
      and aborts the helper under `set -e`); accept an optional target path
      argument used only by validation (default: repo-root
      `Launch_AgentsConfigHelper.command`); exit 0 silently when not on
      macOS, when the target is absent, or when the gitignored sentinel
      `.agents-config-helper-launcher-icon-failed` is present (a previous
      attempt failed; delete the sentinel to retry). Association check must
      be non-failing under `set -euo pipefail`: read `com.apple.ResourceFork`
      presence and `com.apple.FinderInfo` with `xattr ... || true`; a
      missing attribute or a FinderInfo blob shorter than 9 bytes counts as
      not associated; exit 0 silently only when the payload exists **and**
      byte 8 has the `0x04` bit. Otherwise pick the icon source in order —
      `build/macos/Build/Products/Release/agents_config_helper.app/Contents/Resources/AppIcon.icns`,
      the Debug equivalent, then the checked-in
      `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` —
      and set it via the JXA `NSWorkspace` call in the proven `-e` form with
      `run(argv)` path passing, the nil-image guard above, and
      `RESULT=$(...) || true` captured against `true`; then re-check and
      report success or a warning. On failure, write the gitignored
      sentinel `.agents-config-helper-launcher-icon-failed` (add the name to
      `.gitignore` with a one-line comment) so later runs skip silently.
      **The helper must exit 0 in every outcome** (warning text on failure),
      including unexpected errors: an `EXIT` trap forces status 0 when
      `set -e` or `set -u` aborts the script before `main` returns, so
      callers under `set -e` can never be aborted and icon failure can
      never block the app launch.
      Shell style matches `scripts/install_linux_desktop_entry.sh` (header
      comment, `set -euo pipefail`, `uname` guard); shellcheck-clean
      (pre-commit runs shellcheck over files `identify` tags as shell).
- [x] Validate the helper with its target override: run twice against a
      scratch file in `tmp/` (first run associates, second is a no-op), then
      `xattr -d com.apple.FinderInfo` and confirm the next run re-associates.

### Phase 2: launcher and wiring

- [x] `Launch_AgentsConfigHelper.command` (committed with executable bit —
      `git ls-files -s` must show `100755`, which is also what makes
      `identify` tag it as shell so shellcheck covers it, and what makes
      Finder run it at all): `#!/usr/bin/env bash`, `set -euo pipefail`;
      resolve the repo root from `BASH_SOURCE` (`cd --` / `pwd -P`); refuse
      non-macOS; run the Phase 1 helper defensively (helper exits 0 by
      design, but a helper failure must still be downgraded to a warning so
      it can never block the launch). Locate the built app by its real
      product name `agents_config_helper.app` under
      `build/macos/Build/Products/Release/` first, then `Debug/` (the same
      paths `scripts/run_macos_staging_smoke.sh` uses). When neither exists,
      require `flutter` on PATH and run `flutter build macos --release` with
      the repo root as cwd, then `open` the Release bundle. Print what was
      opened. Because `set -e` exits before a trailing pause, install an
      `ERR`/`EXIT` trap (or explicit error returns) so any failure —
      missing `flutter`, failed build, failed `open` — still reaches
      "Press Return to close" with the reason printed. The `flutter` error
      text should note the double-click PATH caveat: a Finder-launched
      `.command` sees the login PATH (this machine's
      `/usr/libexec/path_helper` already exposes Homebrew `flutter`), so an
      SDK added only in `~/.zshrc` will not be found.
- [x] `scripts/setup.sh`: add a numbered, non-fatal macOS step invoking
      `scripts/ensure_launcher_icon.sh` (setup.sh may run on Linux; the
      helper no-ops there).
- [x] `dev.sh`: invoke the helper once at startup (macOS-only, non-fatal,
      silent when already associated). This intentionally runs for every
      dev.sh invocation including `--help`/`--check`, matching "associate
      when dev.sh runs"; the call is one cheap `xattr` read when already
      associated.
- [x] Static unittest checks under `tests/` mirroring SpotiBye's launcher
      test: launcher exists at the repo root, LF-only, git mode `100755`,
      the resource-fork guard is ordered before `setIconForFileOptions`,
      no `SetFile` anywhere, and the helper script contains no `exit 1`.
- [x] Review follow-up (PR 77): a bundle counts only when its product
      executable exists and `Contents/Info.plist` is a valid plist for that
      executable; one build lock covers the shared Release build, published
      as a symlink so a waiter cannot delete a replacement lock;
      icon candidates are tried in order and the failure sentinel is skipped
      when the target is already associated; the repo launcher stores a
      resource-fork hash so an unrelated custom icon is replaced.

### Phase 3: Dock icon when run from source (spike-gated, "if possible")

- [x] Spike (2026-10-24). Programmatic half: direct-exec of the Debug
      bundle binary (what `desktop_device.dart` does — `Process.start` on
      the bundle executable) shows `lsappinfo` resolving `LSBundlePath` to
      the `.app` with `CFBundleIdentifier` `com.example.agentsConfigHelper`
      registered. That **refutes** "direct exec bypasses LaunchServices
      registration." `lsappinfo` did not show icon pixels, so a generic or
      stale tile is still possible. Visual half (humans-only) is open —
      see Verification.
- [x] Bundle inspection (built Debug and Release products; app not
      launched). Both `Info.plist` files set `CFBundleIconFile` and
      `CFBundleIconName` to `AppIcon`. Debug `Assets.car` lists AppIcon
      renditions from 16 through 1024. `AppIcon.icns` is actool's partial
      file for this macOS 12 deployment target (16pt and 128pt only;
      `NSImage(contentsOf:)` stops at 256px). `URLForImageResource("AppIcon")`
      is that icns. `Bundle.image(forResource: "AppIcon")` on the same
      bundles returns representations through 1024, while point `size`
      stays 128. `LSBundlePath` is reasonable evidence the Dock looks up
      this bundle's declared icon: on macOS 10.13+ `CFBundleIconName`
      (the catalog) takes precedence over `CFBundleIconFile`. It is not
      evidence for assigning the partial icns. Residual failure mode:
      LaunchServices icon-cache staleness. Dock appearance is not
      confirmed.
- [x] Defensive fix, adjusted after that inspection. In
      `applicationDidFinishLaunching`, after test-root channel registration
      and before `super` (main thread; `FlutterAppDelegate` does not set
      the icon, and `MainFlutterWindow` is the window, not the Dock tile):
      set `NSApp.applicationIconImage` only from
      `Bundle.main.image(forResource: "AppIcon")` when the image `isValid`
      and has a representation at least 512px on a side. Otherwise assign
      nothing — a nil or partial image must not replace the catalog icon.
      The `AppIcon.icns` fallback is gone. The block does not read
      arguments or perform test-root I/O; Debug and Release share it.
      Compiles (`flutter build macos --debug`). The Dock tile is not
      visually confirmed, and this does not prove a stale cache was
      repaired.
- [ ] Verify the tile visually after the fix for a debug `flutter run`, a
      `--smoke` run, and a Release `open` (human eye; Dock is not
      inspectable programmatically on this machine).
- [x] Residual limitation recorded: icon-cache staleness can still show
      the wrong tile, and the running Dock has not been checked. If no
      full-size rendition loads, the code leaves Launch Services alone
      rather than painting the partial icns.

### Phase 4: docs, changelog, validation

- [x] README "macOS double-click launcher" section next to the Linux taskbar
      section (SpotiBye one-liner style: "double-click
      `Launch_AgentsConfigHelper.command` — the first run brands it with the
      app icon"), plus: build-if-missing behavior, that icon association is
      machine-local and repaired automatically on the next run of the
      launcher/`setup.sh`/`dev.sh` (including after a checkout that
      rewrites the file and drops xattrs), the failed-attempt sentinel
      (delete to retry), the Finder icon-cache fallback (`killall Finder` or
      re-login if the icon looks stale), that Release is preferred even when
      a newer Debug build exists, and the double-click PATH caveat for
      `flutter`.
- [x] Changelog split per `policies/changelog-conventions.md` (decision, not
      an open question): `CHANGELOG.md` gets the user-visible launcher entry
      and — only if Phase 3 actually ships the fix — the Dock icon entry
      (otherwise record the limitation instead); `CHANGELOG.dev.md` gets the
      `setup.sh`/`dev.sh` helper wiring. Entries go under `Unreleased`;
      leave `VERSION` at `0.2.0` for the release step to bump.
- [x] `pre-commit run --all-files` and `./dev.sh --check` pass.
- [ ] Manual macOS double-click checklist under Verification completed.

## Verification

- [ ] Double-clicking `Launch_AgentsConfigHelper.command` in Finder opens the
      built app (Release preferred, Debug fallback).
      Not verified in Finder. A stand-in `open` that does not launch the app
      shows the script selects the Release bundle when both Release and Debug
      exist.
- [ ] With no build present, a Finder double-click builds Release then opens
      it (verify with `flutter` visible under the login PATH, and confirm the
      failure path prints the PATH caveat when `flutter` is unreachable).
- [x] `git ls-files -s Launch_AgentsConfigHelper.command` shows `100755`
      (executable; required for double-click and for shellcheck coverage).
- [x] Finder shows the app icon on the `.command` file after the first
      association; `xattr -p com.apple.ResourceFork` succeeds and
      `xattr -px com.apple.FinderInfo` shows byte 8 with the `0x04` bit
      (both xattr signals are the pass criteria; Finder may lag — see the
      icon-cache fallback in README). Re-checked 2026-10-24: both xattrs
      were present on the repo-root launcher (byte 8 was `04`). The Finder
      window itself was not inspected.
- [x] When the icon is already associated, the helper prints nothing and does
      not rewrite it. A second `dev.sh` run adds no icon output. `setup.sh`
      still prints its step line, like its other steps, and the helper does
      not re-apply the icon. The launcher still calls `open` (observed with a
      stand-in that does not launch the app) and does not repeat the icon
      message. After `xattr -d com.apple.ResourceFork` or
      `xattr -d com.apple.FinderInfo`, the next `dev.sh` run re-associates.
      Partial states (flag without payload, or payload without the flag)
      count as not associated. A missing `FinderInfo` attribute counts as
      not associated. The helper also treats a blob shorter than 9 bytes as
      not associated; this macOS rejects a short `com.apple.FinderInfo` write
      (`xattr` returns ERANGE), so that branch was reviewed in the script
      rather than executed.
- [x] A forced icon failure (e.g. temporarily rename the icon sources)
      prints one warning, writes the sentinel, and later runs skip silently;
      deleting `.agents-config-helper-launcher-icon-failed` retries.
- [x] Helper failure path is non-fatal end to end: with the icon source
      removed, the helper warns and exits 0 and the launcher still reaches
      `open` (observed with a stand-in `open` that does not launch the app).
- [x] The failure pause is reachable under `set -e` (e.g. temporarily hide
      the bundles and `flutter`; "Press Return to close" appears with the
      reason).
- [x] Repeat the launcher and helper once from a checkout path containing a
      space (e.g. a `tmp/` copy of the repo named with a space).
- [x] `git status` stays clean before and after association.
- [x] Dock icon outcome recorded per Phase 3 (fixed, or limitation documented).
- [x] Static launcher checks pass
      (`python3 -m unittest tests.test_launcher_command -v`).
- [x] `pre-commit run --all-files` (shellcheck, gitleaks, markdownlint,
      absolute-path check) and `./dev.sh --check` pass.

## Open questions

- [ ] Phase 3 visual confirmation (humans-only): registration bypass is
      refuted, and the built bundle declares a full catalog icon. Confirm
      by eye that a debug `flutter run`, a `--smoke` run, and a Release
      `open` show the app icon, including after a rebuild (stale-cache
      case). Not done.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| osascript/AppKit bridge unavailable or TCC-restricted on some machines | low | med | Helper exits 0 after a warning by design; the launcher still opens the app without the icon |
| Finder shows a stale icon cache after association | low | low | Xattr bit is the pass signal; `killall Finder`/re-login fallback documented in README |
| Stale LaunchServices icon cache, or a partial `AppIcon.icns` override | med | low | Assign `applicationIconImage` only when `image(forResource:)` has a ≥512px rendition; otherwise leave the `CFBundleIconName` icon alone. Visual check stays humans-only |
| Path quoting breaks JXA with spaces in the checkout path | med | med | Paths pass via `run(argv)` (no `--`); tested once from a spaced path |
| `flutter` unreachable from a double-clicked login PATH | med | low | Clear error plus reachable pause; README documents the PATH caveat |
| Detection bit parsing drifts across macOS versions | low | med | Parsing is a plain byte read of a documented Finder flag; short/missing blob counts as not associated; re-probe on failure |

## Completion steps (when status = complete)

1. Set status to `complete` and mark checklists only after verification.
2. Move this file to `plans/archive/` in the final commit on the feature branch.
3. Log completion in `CHANGELOG.md` / `CHANGELOG.dev.md` per the split above.
4. Remove the linked `TO_DO.md` entry.
5. Reference the completing PR/commits here before archiving.

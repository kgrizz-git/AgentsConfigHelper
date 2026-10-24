# Plan: macOS Double-Click Launcher and App Icon Association

Last reviewed: 2026-10-24
Date: 2026-10-24
Author: MiMo (agent), maintainer requirements
Status: approved (cursor/grok-4.7 review 2026-10-24: APPROVE-WITH-CHANGES; corrections applied; implementation not started)
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
- Detection of "already associated" is exact: `xattr -px com.apple.FinderInfo
  <file>` returned byte 8 = `04`, the `kHasCustomIcon` (0x0400) flag bit in
  the big-endian finder flags (32-byte blob). Probe was cleaned up
  afterwards; `git status` stayed clean because git does not track xattrs.
- Consequence: association is **machine-local state**. A fresh clone (or a
  copy that drops xattrs) shows the generic script icon until the helper runs
  once — which the launcher, `setup.sh`, and `dev.sh` all do automatically.

Invocation details (review corrections; `man osascript` plus measured
behavior on this machine):

- Pass paths **after `-` (stdin script), with no `--`**: `osascript -l
  JavaScript - "$icon" "$target"` plus `run(argv)`. `osascript` has no
  end-of-options marker — a `--` argument lands in `argv` as `argv[0]`
  (measured: `osascript -l JavaScript - -- a b` → `["--","a","b"]`), which
  would make `argv[0]`-as-icon-path load a file named `--`.
- `NSImage` loaded from the icon path must be checked before calling
  `setIcon`: the API treats a nil image as *remove the custom icon*
  (`NSWorkspace.h`), so a failed icon load must not reach the call.
- A missing `com.apple.FinderInfo` attribute makes `xattr -px` exit 1
  (measured). The read must be explicitly non-failing; see Phase 1.
- Known limitation: if the flag is set but the resource fork is gone, the
  bit check treats the file as associated and skips repair. Reset with
  `xattr -d com.apple.FinderInfo` to force re-association.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| `Rez`/`SetFile -a C` (Classic tools) | Not shipped with modern Xcode CLT; deprecated |
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
```

## Phases & checklist

### Phase 1: shared icon-association helper

- [ ] `scripts/ensure_launcher_icon.sh`:
      resolve the repo root from `BASH_SOURCE` using the `cd --` / `pwd -P`
      form used by `dev.sh`; accept an optional target path argument used
      only by validation (default: repo-root
      `Launch_AgentsConfigHelper.command`); exit 0 silently when not on
      macOS or when the target is absent. Association check must be
      non-failing under `set -euo pipefail`: read `com.apple.FinderInfo` with
      `xattr -px ... || true`; a missing attribute or a blob shorter than 9
      bytes counts as not associated; when byte 8 already has the `0x04` bit,
      exit 0 silently. Otherwise pick the icon source in order —
      `build/macos/Build/Products/Release/agents_config_helper.app/Contents/Resources/AppIcon.icns`,
      the Debug equivalent, then the checked-in
      `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png` —
      and set it via the JXA `NSWorkspace` call from the stdin script with
      `run(argv)` path passing and the nil-image guard above; then re-read
      the flag and report success or a warning. **The helper must exit 0 in
      every outcome** (warning text on failure) so callers under `set -e`
      can never be aborted and icon failure can never block the app launch.
      Shell style matches `scripts/install_linux_desktop_entry.sh` (header
      comment, `set -euo pipefail`, `uname` guard); shellcheck-clean
      (pre-commit runs shellcheck over files `identify` tags as shell).
- [ ] Validate the helper with its target override: run twice against a
      scratch file in `tmp/` (first run associates, second is a no-op), then
      `xattr -d com.apple.FinderInfo` and confirm the next run re-associates.

### Phase 2: launcher and wiring

- [ ] `Launch_AgentsConfigHelper.command` (committed with executable bit —
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
- [ ] `scripts/setup.sh`: add a numbered, non-fatal macOS step invoking
      `scripts/ensure_launcher_icon.sh` (setup.sh may run on Linux; the
      helper no-ops there).
- [ ] `dev.sh`: invoke the helper once at startup (macOS-only, non-fatal,
      silent when already associated). This intentionally runs for every
      dev.sh invocation including `--help`/`--check`, matching "associate
      when dev.sh runs"; the call is one cheap `xattr` read when already
      associated.

### Phase 3: Dock icon when run from source (spike-gated, "if possible")

- [ ] Spike first and record findings under "Open questions" or here:
      run `./dev.sh --run` and observe the Dock tile (app icon vs generic),
      then compare with `open` on the Debug bundle and with the `--smoke`
      launch. The Flutter tool execs the bundle's binary directly, bypassing
      LaunchServices registration, which is the suspected cause of a generic
      tile.
- [ ] If the tile is generic or missing: set
      `NSApplication.shared.applicationIconImage` from the bundle's `AppIcon`
      (`NSImage(named: "AppIcon")`, falling back to `AppIcon.icns` from
      bundle resources) in `AppDelegate.applicationDidFinishLaunching`.
- [ ] Verify the tile after the fix for a debug `flutter run`, a `--smoke`
      run, and a Release `open`.
- [ ] If the icon still cannot appear (macOS behavior for direct exec),
      record the residual limitation in README and close the phase honestly
      rather than claiming success.

### Phase 4: docs, changelog, validation

- [ ] README "macOS double-click launcher" section next to the Linux taskbar
      section: double-click usage, build-if-missing behavior, that icon
      association is machine-local and repaired automatically on the next
      run of the launcher/`setup.sh`/`dev.sh` (including after a checkout
      that rewrites the file and drops xattrs), the Finder icon-cache
      fallback (`killall Finder` or re-login if the icon looks stale), that
      Release is preferred even when a newer Debug build exists, and the
      double-click PATH caveat for `flutter`.
- [ ] Changelog split per `policies/changelog-conventions.md` (decision, not
      an open question): `CHANGELOG.md` gets the user-visible launcher entry
      and — only if Phase 3 actually ships the fix — the Dock icon entry
      (otherwise record the limitation instead); `CHANGELOG.dev.md` gets the
      `setup.sh`/`dev.sh` helper wiring. Entries go under `Unreleased`;
      leave `VERSION` at `0.2.0` for the release step to bump.
- [ ] `pre-commit run --all-files` and `./dev.sh --check` pass.
- [ ] Manual macOS double-click checklist under Verification completed.

## Verification

- [ ] Double-clicking `Launch_AgentsConfigHelper.command` in Finder opens the
      built app (Release preferred, Debug fallback).
- [ ] With no build present, a Finder double-click builds Release then opens
      it (verify with `flutter` visible under the login PATH, and confirm the
      failure path prints the PATH caveat when `flutter` is unreachable).
- [ ] `git ls-files -s Launch_AgentsConfigHelper.command` shows `100755`
      (executable; required for double-click and for shellcheck coverage).
- [ ] Finder shows the app icon on the `.command` file after the first
      association; `xattr -px com.apple.FinderInfo` shows byte 8 with the
      `0x04` bit (the xattr bit is the pass signal; Finder may lag — see the
      icon-cache fallback in README).
- [ ] Second runs of the launcher, `setup.sh`, and `dev.sh` are silent
      no-ops; after `xattr -d com.apple.FinderInfo`, the next `dev.sh` run
      re-associates; a short/missing `FinderInfo` blob counts as not
      associated.
- [ ] Helper failure path is non-fatal end to end: with the icon source
      removed, the helper warns and exits 0 and the launcher still reaches
      `open`.
- [ ] The failure pause is reachable under `set -e` (e.g. temporarily hide
      the bundles and `flutter`; "Press Return to close" appears with the
      reason).
- [ ] Repeat the launcher and helper once from a checkout path containing a
      space (e.g. a `tmp/` copy of the repo named with a space).
- [ ] `git status` stays clean before and after association.
- [ ] Dock icon outcome recorded per Phase 3 (fixed, or limitation documented).
- [ ] `pre-commit run --all-files` (shellcheck, gitleaks, markdownlint,
      absolute-path check) and `./dev.sh --check` pass.

## Open questions

- [ ] Phase 3 spike outcome: confirm whether a direct-exec source run shows a
      generic Dock tile before choosing the `applicationIconImage` fix.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| osascript/AppKit bridge unavailable or TCC-restricted on some machines | low | med | Helper exits 0 after a warning by design; the launcher still opens the app without the icon |
| Finder shows a stale icon cache after association | low | low | Xattr bit is the pass signal; `killall Finder`/re-login fallback documented in README |
| Direct-exec Dock tile is unfixable on some macOS versions | med | low | Phase 3 is "if possible"; document the residual limitation |
| Path quoting breaks JXA with spaces in the checkout path | med | med | Paths pass via `run(argv)` (no `--`); tested once from a spaced path |
| `flutter` unreachable from a double-clicked login PATH | med | low | Clear error plus reachable pause; README documents the PATH caveat |
| Detection bit parsing drifts across macOS versions | low | med | Parsing is a plain byte read of a documented Finder flag; short/missing blob counts as not associated; re-probe on failure |

## Completion steps (when status = complete)

1. Set status to `complete` and mark checklists only after verification.
2. Move this file to `plans/archive/` in the final commit on the feature branch.
3. Log completion in `CHANGELOG.md` / `CHANGELOG.dev.md` per the split above.
4. Remove the linked `TO_DO.md` entry.
5. Reference the completing PR/commits here before archiving.

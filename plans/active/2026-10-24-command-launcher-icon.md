# Plan: macOS Double-Click Launcher and App Icon Association

Last reviewed: 2026-10-24
Date: 2026-10-24
Author: MiMo (agent), maintainer requirements
Status: draft (pending external review)
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

A scratch probe in `tmp/` on this machine established the exact mechanism:

- `osascript -l JavaScript` with the AppKit bridge sets a custom icon in one
  call: `$.NSWorkspace.sharedWorkspace.setIconForFileOptions(icon, path, 0)`
  returned `icon-set-ok` for a PNG source icon.
- macOS stores the icon in the target file's own `com.apple.ResourceFork`
  xattr and flags the file in `com.apple.FinderInfo`. No `Icon\r` sidecar is
  created for a single file (`Icon?` is already in `.gitignore` regardless).
- Detection of "already associated" is exact: `xattr -px com.apple.FinderInfo
  <file>` returned byte 8 = `04`, the `kHasCustomIcon` (0x0400) flag bit in
  the big-endian finder flags. Probe was cleaned up afterwards; `git status`
  stayed clean because git does not track xattrs.
- Consequence: association is **machine-local state**. A fresh clone (or a
  copy that drops xattrs) shows the generic script icon until the helper runs
  once — which the launcher, `setup.sh`, and `dev.sh` all do automatically.

Paths passed to the JXA script must go through `osascript ... -- "$icon"
"$target"` and `run(argv)` so spaces and quoting cannot break the call.

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
      resolve the repo root from `BASH_SOURCE`; exit 0 silently when not on
      macOS or when `Launch_AgentsConfigHelper.command` is absent; when
      `com.apple.FinderInfo` byte 8 already has the `0x04` bit, exit 0
      silently; otherwise pick the icon source (built `AppIcon.icns` from the
      Release bundle, then Debug, then the checked-in
      `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`),
      set it via the JXA `NSWorkspace` call with `run(argv)` path passing,
      then re-read the flag and report success or a non-fatal warning.
      `set -euo pipefail`, shellcheck-clean (pre-commit runs shellcheck).
- [ ] Validate the helper manually: run twice against a scratch target (first
      run associates, second is a no-op), and confirm detection survives an
      `xattr -d com.apple.FinderInfo` reset.

### Phase 2: launcher and wiring

- [ ] `Launch_AgentsConfigHelper.command` (committed executable):
      `#!/usr/bin/env bash`, `set -euo pipefail`; resolve repo root from
      `BASH_SOURCE`; refuse non-macOS; run the Phase 1 helper; locate the
      built app (Release first, then Debug); when neither exists, require
      `flutter` on PATH, run `flutter build macos --release`, then open the
      Release bundle with `open`; print what was opened. On any failure print
      the reason and pause with "Press Return to close" so double-click
      errors are readable before Terminal exits.
- [ ] `scripts/setup.sh`: add a numbered, non-fatal macOS step invoking
      `scripts/ensure_launcher_icon.sh` (setup.sh may run on Linux; the
      helper no-ops there).
- [ ] `dev.sh`: invoke the helper once at startup (macOS-only, non-fatal,
      silent when already associated).

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
      section: double-click usage, build-if-missing behavior, and that icon
      association is machine-local and repaired automatically.
- [ ] `CHANGELOG.md`: user-visible launcher and Dock icon entries;
      `CHANGELOG.dev.md`: helper wiring in `setup.sh`/`dev.sh`.
- [ ] `pre-commit run --all-files` and `./dev.sh --check` pass.
- [ ] Manual macOS double-click checklist under Verification completed.

## Verification

- [ ] Double-clicking `Launch_AgentsConfigHelper.command` in Finder opens the
      built app (Release preferred, Debug fallback).
- [ ] With no build present, the launcher builds Release then opens it.
- [ ] Finder shows the app icon on the `.command` file after the first
      association; `xattr -px com.apple.FinderInfo` shows byte 8 with the
      `0x04` bit.
- [ ] Second runs of the launcher, `setup.sh`, and `dev.sh` are silent
      no-ops; after `xattr -d com.apple.FinderInfo`, the next `dev.sh` run
      re-associates.
- [ ] `git status` stays clean before and after association.
- [ ] Dock icon outcome recorded per Phase 3 (fixed, or limitation documented).
- [ ] `pre-commit run --all-files` (shellcheck, gitleaks, markdownlint,
      absolute-path check) and `./dev.sh --check` pass.

## Open questions

- [ ] Phase 3 spike outcome: confirm whether a direct-exec source run shows a
      generic Dock tile before choosing the `applicationIconImage` fix.
- [ ] Changelog split confirmation: launcher + Dock icon in `CHANGELOG.md`,
      helper wiring in `CHANGELOG.dev.md`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| osascript/AppKit bridge unavailable or TCC-restricted on some machines | low | med | Helper is non-fatal; the launcher still opens the app without the icon |
| Finder shows a stale icon cache after association | low | low | Note `killall Finder`/re-login fallback in README |
| Direct-exec Dock tile is unfixable on some macOS versions | med | low | Phase 3 is "if possible"; document the residual limitation |
| Path quoting breaks JXA with spaces in the checkout path | med | med | Pass paths via `run(argv)`; test once from a spaced path |
| `flutter` missing when no build exists | low | low | Clear error plus pause in the launcher |
| Detection bit parsing drifts across macOS versions | low | med | Parsing is a plain byte read of a documented Finder flag; re-probe on failure and fall back to unconditional association |

## Completion steps (when status = complete)

1. Set status to `complete` and mark checklists only after verification.
2. Move this file to `plans/archive/` in the final commit on the feature branch.
3. Log completion in `CHANGELOG.md` / `CHANGELOG.dev.md` per the split above.
4. Remove the linked `TO_DO.md` entry.
5. Reference the completing PR/commits here before archiving.

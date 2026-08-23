# macOS Test-Root Mode

`--test-root=<absolute-path>` is an opt-in, development-only macOS startup mode for
exercising discovery and edits against repository-owned, token-free fixtures. It is not a
general safe mode and it does not change a normal launch. Linux and Windows reject the flag
until they have their own native containment implementations.

The detailed engineering decision and evidence live in the active
[test-root containment plan](../plans/active/test-root-containment.md). This page is the
operator reference for the scripts and manual smoke workflow.

## Safety contract

Test-root mode starts only when its argument names an existing, non-symlink directory with
the exact staging marker created by the launcher. The app canonicalizes that root and routes
its config I/O, backups, restores, discovery preferences, and remembered window bounds through a macOS native bridge.
The bridge retains the opened root descriptor and uses descriptor-relative no-follow operations
for descendants, so a symlink or later pathname swap cannot redirect an operation outside the
opened root.

The mode disables glob discovery and folder-opening actions because those paths do not use the
native bridge. It is a test harness, not a production feature: never use a personal config,
credential, or arbitrary directory as its root.

If startup validation fails, the app displays the reason instead of continuing with normal
configuration access. Quit it, create a new root with `./dev.sh --smoke`, and try again.

## Developer entrypoint

From the repository root, use the interactive menu:

```bash
./dev.sh
```

The same actions are available to automation or experienced contributors:

```bash
./dev.sh --run                 # ordinary macOS app launch
./dev.sh --build-macos         # debug build
./dev.sh --smoke               # build and launch a disposable staging root
./dev.sh --check               # format, analyze, and test
./dev.sh --cleanup /path/to/root
```

`--smoke` delegates root creation and app launch to
[`scripts/run_macos_staging_smoke.sh`](../scripts/run_macos_staging_smoke.sh). `--cleanup`
requires confirmation and delegates deletion to
[`scripts/cleanup_macos_staging_root.sh`](../scripts/cleanup_macos_staging_root.sh), which
independently validates the temporary-root prefix and exact marker before removing anything.

## Manual smoke checklist

1. Launch `./dev.sh --smoke` on a local macOS machine.
2. Confirm the app visibly displays `TEST ROOT MODE` and the printed root path. If it does not,
   quit immediately and do not edit anything.
3. Confirm the fixture entries for Claude Code, Codex, Opencode, Kiro, and shared `AGENTS.md`
   appear. Add the printed root's `workspace` directory and confirm its project entries appear.
4. Perform one raw edit and one structured edit. Inspect their diffs.
5. Confirm the generated backup, restored output, discovery-preference file, and window-bounds
   preference file all remain below the printed root.
6. Quit the app, then run `./dev.sh --cleanup <printed-root>`.
7. Record the result in the active [Safe Testing Foundation plan](../plans/active/safe-testing-foundation.md).

The initial interactive smoke was completed on 2026-08-22: staged discovery, edits, backups,
preferences, and external-project-root rejection behaved as intended. Repeat this checklist
when changing test-root I/O or the staging launcher; Linux and Windows remain unsupported.

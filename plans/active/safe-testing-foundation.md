# Plan: Safe Testing Foundation

Last reviewed: 2026-08-22
Date: 2026-08-22
Author: maintainers
Status: in progress
Linked issue/PR: n/a

## Goal

Make discovery, parsing, editing, backup, and restore safe to exercise end-to-end with
token-free representative files. Contributors should be able to run a native desktop
smoke test without accessing their real agent/IDE configurations or writing application
state outside a disposable test root.

## Decision and scope

The first slice combines a fixture matrix with a disposable staging-home workflow:

- Synthetic fixtures cover representative catalog paths and syntax edge cases in
  automated tests.
- A native staging smoke workflow uses a fresh, absolute test root and the built app to
  exercise automatic discovery, edit, diff, backup, and restore.
- The workflow is safe only when **every** app write location is either below the test
  root or positively blocked. This includes the edited files, backups, and persisted
  manual-path/project-root preferences.

`HOME` already controls the Dart home-directory resolver, so it is useful for testing
user-path discovery. It is not by itself proof that macOS `path_provider` or preference
storage uses the same directory. Phase 0 must establish that behavior before the command
is documented as a safe-write procedure.

## Phase 0 evidence and decision

The source trace on 2026-08-22 establishes the following:

| Concern | Current path | Phase 0 conclusion |
| --- | --- | --- |
| User-scope discovery and `~` expansion | `ConfigService` uses `resolveHomeDirectory()`, which reads `HOME`/Windows equivalents. | A process-level `HOME` override is useful for discovery only. |
| Config save | `ConfigService.saveConfig` and `saveRawConfig` write the resolved target directly. | An explicit test root must reject manual or project paths outside the root before loading or writing. |
| Backups and restore | `main.dart` obtains the backup directory with `getApplicationSupportDirectory()`; `BackupService` copies/restores files directly. | `HOME` does not provide a cross-platform proof of backup or restore containment. |
| Discovery preferences | `DiscoveryPreferencesStore` defaults to `getApplicationSupportDirectory()` and atomically writes a JSON file there. | Preferences must be injected below the test root, not left to the platform default. |
| Copilot discovery | `DiscoveryController` separately honors absolute `COPILOT_HOME`. | Test mode must ignore or constrain that environment variable. |

**Decision:** Do not publish a routine `HOME=...` write/smoke command. A coherent
`--test-root` boundary is required before Phase 2. Its detailed implementation plan is
[`test-root-containment.md`](test-root-containment.md).

**Implementation update (macOS):** The focused plan now has a descriptor-relative,
no-follow `--test-root` implementation with native symlink tests. It routes config I/O,
backups, restores, preferences, and discovery below a marked root; Linux and Windows reject
the flag until they gain their own primitives. The first manual macOS staging run on
2026-08-22 confirmed staged discovery, edit/backup/preference containment, and rejection of
an external project root; it remains a macOS-only workflow while other platforms are pending.

## Out of scope

- A general user-facing read-only, dry-run, or safe-mode product feature.
- Copying, committing, or transmitting real configuration files, tokens, or credentials.
- Docker/VNC desktop infrastructure, cloud desktops, or full VM automation.
- Broad migration from `dart:io` to an in-memory filesystem abstraction.
- Schema-aware permission cards or changes to production parser behavior.
- Replacing normal backup-before-write or diff-preview behavior.

## Approach

Use a layered test strategy, from cheapest to most realistic:

1. Add token-free fixtures and focused parser/service/widget tests for the paths and
   formats selected in this slice.
2. Build a staging root from those fixtures and launch the already-built app with an
   explicit test-root configuration. Confirm that automatic discovery sees expected user
   targets and that every write is confined.
3. Document a repeatable manual smoke checklist with teardown and evidence capture.
4. Treat dedicated OS users and VM snapshots as later platform-validation layers, not
   prerequisites for daily development.

If Phase 0 finds that `$HOME` does not confine application-support or preference paths,
introduce a narrowly scoped, development/test-only `--test-root=<absolute-path>` option.
It must override the home resolver, backup directory, and preference storage together,
display a persistent test-mode banner, and reject config writes/restores outside that
root. Do not add a partial write-redirection switch.

### Alternatives considered

| Option | Why not chosen for this slice |
| --- | --- |
| VM per developer workflow | Valuable final validation, but too slow and costly for routine parser/UI iteration. |
| Docker or Docker/VNC | Useful only for Linux-specific work; it cannot validate native macOS/Windows behavior. |
| Manual paths only | Does not exercise catalog-based automatic user-path discovery. |
| Git branches for copied configs | Does not prevent writes and risks committing sensitive content. |
| Generic in-memory filesystem refactor | High churn that still cannot validate desktop path-provider and permission behavior. |

## Proposed file changes

```text
test/fixtures/staging_home/          token-free representative user/project config trees
test/fixtures/edge_cases/            parser regressions: JSONC, YAML, TOML, Markdown, and schema variants
test/..._test.dart                   parser, discovery, ConfigService, backup/restore, and widget assertions
lib/main.dart                        only if needed: parse and apply one test-root configuration at startup
lib/services/...                     only if needed: injectable/constrained backup and preference locations
lib/widgets/...                      only if needed: persistent test-mode indicator
scripts/run_staging_smoke.sh         create/seed/dispose a staging root and launch a built local app
docs/testing-strategies.md           exact supported setup, smoke checklist, and teardown guidance
docs/NAVIGATION.md                   link the finalized workflow when it is actionable
```

The script and fixtures must use obvious non-secret placeholders such as
`example.invalid`, never token-shaped strings that could trigger secret scanners or be
mistaken for credentials.

## Phases and checklist

### Phase 0: Establish write-boundary evidence

- [x] Trace startup's home, application-support, preference, and environment-controlled
      locations from source. The evidence is recorded above.
- [x] Record that a `HOME`-only staging run is intentionally not a safety procedure. The
      macOS `--test-root` smoke run on 2026-08-22 instead verified config, backup, and
      preference containment below the script-created root.
- [x] Decide whether `HOME` alone confines all writes. It is insufficient as a documented
      cross-platform safety boundary; use the explicit test-root design instead.
- [x] Implement the macOS canonical/no-follow containment boundary and its symlink-escape tests
      under [`test-root-containment.md`](test-root-containment.md). Do not claim
      race-resistance from normalized Dart paths alone.

### Phase 1: Build the fixture matrix

- [x] Inventory the smallest representative set of supported paths and formats: JSON/JSONC,
      YAML, TOML, Markdown/text, a nested-permission example, and a project-scoped target.
- [x] Add synthetic fixture trees that use catalog-recognized paths and contain no real
      user data, token-shaped values, or copied configuration comments.
- [x] Add parser tests for valid content, comments/trailing commas, and nested structures.
      Malformed-content and raw-editor-fallback fixture coverage remain open.
- [x] Add discovery tests proving the fixture home finds expected user targets, while a
      fixture project root finds expected project targets.
- [ ] Add service tests that verify save creates a backup, restore creates parent folders
      when needed, and all configured test-mode writes remain contained.

### Phase 2: Make staging smoke testing deterministic

- [x] Add the macOS test-root plumbing defined in
      [`test-root-containment.md`](test-root-containment.md), including blocked saves,
      restores, preferences, and external discovery paths.
- [x] Add a persistent, unambiguous test-mode indicator when test-root plumbing exists.
- [x] Add a script that creates a unique staging root, seeds it from
      fixtures, launches the already-built app, and reports the root for inspection.
- [x] Ensure teardown is explicit and never recursively deletes a caller-supplied path;
      only delete a path the script itself created and validated.
- [x] Write a manual checklist: expected discovered entries, one raw edit, one structured
      edit where supported, diff inspection, backup inspection, restore, and teardown.

### Phase 3: Automate the regression layer

- [x] Run fixture parser, discovery, service, and widget tests in the existing CI test job
      through the existing `flutter test --coverage` command.
- [x] Use Dart fixture tests for syntax and catalog mapping; a separate fixture validator is
      not needed at this stage.
- [x] Document when a bug report may add a sanitized regression fixture and require a
      source/secret review before it is committed. `docs/testing-strategies.md` now records
      provenance, synthetic replacement, minimization, raw-fallback, and reviewer checks.

### Next bounded slice — normal-mode parity and raw fallback

The next implementation slice is deliberately regression-focused; it does not expand a
tool schema or add a structured write path.

- [x] Add a startup composition harness that builds the application dependencies with no
  `--test-root` argument. It must prove that no `TestRootGuard` is installed and that
  `ConfigService`, `BackupService`, and `DiscoveryPreferencesStore` retain their normal
  locations/behavior. Prefer observable injected factories or dependency values over
  brittle assertions about private provider implementation details.
- [x] Cover one token-free, catalog-recognized configuration containing an unsupported nested
  permissions shape. Its editor test must assert raw-editor-first rendering: no supported
  structured card, no flat permissions editor, and no structured-only save path. The raw
  content must remain available unchanged until a user intentionally edits it.
- [ ] Keep fixture-boundary coverage distinct from the existing primitive/containment tests.
  The fixture-level service test should exercise save → backup and restore-as-recreate
  through the configured test-root services; it complements (rather than duplicates) the
  no-follow and symlink tests in `test-root-containment.md`.
- [x] Document sanitized-fixture intake before adding a bug-derived fixture: provenance or
  reproducible shape, removal of user content and credentials, synthetic replacement of
  values/comments, and a reviewer check that the fixture exercises a specific regression.

**Exit criteria:** default startup has one focused parity test; the unsupported fixture has
parser/widget coverage and preserves raw fallback; configured test-root fixture services prove
backup and restore-as-recreate behavior; fixture-intake guidance is published. Run
`flutter analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed .`, and
`flutter test --coverage` after the slice.

## Verification

- [x] `flutter analyze --fatal-infos` passes.
- [x] `dart format --output=none --set-exit-if-changed .` passes.
- [x] `flutter test --coverage` passes. The configured CI floor is 80%; the local
      measured result was 81.97% on 2026-08-23.
- [x] Fixture files are token-free and pass all existing secret, path, and documentation
      hooks.
- [x] Automated tests prove user-scope and project-scope discovery against the synthetic
      tree.
- [x] Add an unsupported nested-structure fixture and prove its raw-editor fallback. The
      Claude permissions fixture has a nested `allow` map; fixture and widget tests confirm
      it remains raw-editor-first with no Claude permissions card.
- [x] An automated or manual containment test proves test-mode save, backup, and restore
      do not modify paths outside the disposable root. Native no-follow tests plus the
      2026-08-22 macOS smoke cover the tested path.
- [x] A manual macOS staging smoke run confirms the sidebar populates from the staged
      catalog paths and records the inspected backup/restore result (2026-08-22).
- [ ] Existing Linux, Windows, and macOS CI jobs pass.

## Open questions

- [ ] What platform-native primitives can provide the macOS no-follow guarantee on Linux and
      Windows? Those platforms currently reject `--test-root`; do not infer their behavior from
      a process-level `HOME` override.
- [ ] Which catalog targets provide the smallest useful fixture set without turning the
      fixtures into a second copy of every vendor's documentation?
- [ ] Should a future user-facing dry-run feature build on this containment boundary, or
      remain a separately designed product capability?

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| A platform service writes outside `HOME` | medium | high | Trace and test all write locations; add a single test-root override if needed. |
| A fixture contains a secret or looks like one | low | high | Use synthetic values, review fixtures, and retain existing secret scans. |
| A teardown command deletes an unintended directory | low | high | Only remove a script-created, validated temporary root; never accept an arbitrary deletion target. |
| Fixtures diverge from real-world syntax | medium | medium | Add sanitized regressions from confirmed bugs and retain raw-editor fallback. |
| Test-only plumbing leaks into normal production behavior | low | medium | Make it opt-in, visibly indicated, and covered by default-mode tests. |

## Completion steps

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Record implementation work in `CHANGELOG.dev.md` and user-facing behavior in
   `CHANGELOG.md` when applicable.
4. Remove or update the related safe-testing item in `TO_DO.md`.
5. Archive temporary staging roots and ensure no fixture contains sensitive data.

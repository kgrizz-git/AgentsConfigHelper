# Plan: Safe Testing Foundation

Last reviewed: 2026-08-22
Date: 2026-08-22
Author: maintainers
Status: ready to implement
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

- [ ] Trace startup's home, application-support, and preference locations on macOS, Linux,
      and Windows from code and targeted local runs.
- [ ] Run the built macOS app with a fresh `HOME` staging directory and record where the
      edited config, backup, and preference files are actually written.
- [ ] Decide whether `HOME` alone confines all writes. If it does not, design the single
      test-root override before creating a routine smoke command.
- [ ] Define the test-root containment rule using normalized absolute paths and
      platform-aware separators; avoid prefix-only path checks.

### Phase 1: Build the fixture matrix

- [ ] Inventory the smallest representative set of supported paths and formats: JSON/JSONC,
      YAML, TOML, Markdown/text, a nested-permission example, and a project-scoped target.
- [ ] Add synthetic fixture trees that use catalog-recognized paths and contain no real
      user data, token-shaped values, or copied configuration comments.
- [ ] Add parser tests for valid content, malformed content, comments/trailing commas,
      nested/unsupported structures, and raw-editor fallback behavior.
- [ ] Add discovery tests proving the fixture home finds expected user targets, while a
      fixture project root finds expected project targets.
- [ ] Add service tests that verify save creates a backup, restore creates parent folders
      when needed, and all configured test-mode writes remain contained.

### Phase 2: Make staging smoke testing deterministic

- [ ] Add the minimal test-root plumbing identified by Phase 0, if required, and reject
      saves/restores outside the root while it is active.
- [ ] Add a persistent, unambiguous test-mode indicator when test-root plumbing exists.
- [ ] Add a script or documented command that creates a unique staging root, seeds it from
      fixtures, launches the already-built app, and reports the root for inspection.
- [ ] Ensure teardown is explicit and never recursively deletes a caller-supplied path;
      only delete a path the script itself created and validated.
- [ ] Write a manual checklist: expected discovered entries, one raw edit, one structured
      edit where supported, diff inspection, backup inspection, restore, and teardown.

### Phase 3: Automate the regression layer

- [ ] Run fixture parser, discovery, service, and widget tests in the existing CI test job.
- [ ] Add a fixture validity/coverage check only if the Dart tests cannot already validate
      the relevant syntax and catalog mapping; avoid a redundant external validator.
- [ ] Document when a bug report may add a sanitized regression fixture and require a
      source/secret review before it is committed.

## Verification

- [ ] `flutter analyze --fatal-infos` passes.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter test --coverage` passes and retains the CI coverage floor.
- [ ] Fixture files are token-free and pass all existing secret, path, and documentation
      hooks.
- [ ] Automated tests prove user-scope and project-scope discovery against the synthetic
      tree, including at least one unsupported nested structure that falls back safely.
- [ ] An automated or manual containment test proves test-mode save, backup, and restore
      do not modify paths outside the disposable root.
- [ ] A manual macOS staging smoke run confirms the sidebar populates from the staged
      catalog paths and records the inspected backup/restore result.
- [ ] Existing Linux, Windows, and macOS CI jobs pass.

## Open questions

- [ ] Does `getApplicationSupportDirectory()` resolve below a process-level `HOME` override
      on each supported desktop platform? Resolve in Phase 0; do not assume.
- [ ] How can the preference store receive a test-root directory with the least production
      behavior change if the override is required?
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

# Plan: very_good_analysis 11 Migration

Last reviewed: 2026-09-16
Date: 2026-09-16
Author: maintainers (research spike)
Status: draft
Linked issue/PR: Dependabot [#60](https://github.com/kgrizz-git/AgentsConfigHelper/pull/60)
(superseded by this work)
Related: [TO_DO dependency maintenance](../../TO_DO.md#dependency-maintenance),
[Dependency upgrades (archive)](../archive/dependency-upgrades.md),
[changelog conventions](../../policies/changelog-conventions.md)

## Goal

Upgrade the pinned linter toolchain `very_good_analysis` 10.3.0 → 11.0.0 without
destabilising the repository's formatting contract or CI, and without bundling the change
with unrelated work. Dependabot PR #60 performs the version bump but fails the
`Analyze & format` job, because v11 changes both the lint rule set and the inherited
formatter's trailing-comma behaviour. This plan covers the deliberate migration instead.

## Research summary

Collected 2026-09-16 against upstream v11.0.0 (released 2026-09-03) and a throwaway git
worktree of `main` (`cae5836`). No repository files were changed by the spike.

Upstream changes in v11.0.0:

- Requires Dart SDK `^3.13.0`; the repo is on Flutter 3.47.1 / Dart 3.13.1, so the
  constraint is already satisfied.
- No new transitive dependencies. `pubspec.lock` changes only `very_good_analysis`.
- Seven rules enabled: `async_return_with_no_await`, `empty_container_bodies`,
  `initialize_in_field_declaration`, `unnecessary_const_in_enum_constructor`,
  `unnecessary_primary_constructor_body`, `unnecessary_type_name_in_constructor`,
  `use_declaring_parameters`.
- Three rules removed: `avoid_private_typedef_functions`, `one_member_abstracts`,
  `unnecessary_await_in_return`.
- Inherited formatter default changed: `formatter.trailing_commas` `preserve` → `automate`.
  The repo's `analysis_options.yaml` uses `include: package:very_good_analysis/analysis_options.yaml`
  without overriding it, so it currently inherits `preserve` and would inherit `automate`.

Measured impact on this repo (v11 installed in the worktree):

- `flutter analyze --fatal-infos` reports 109 findings. Only two of the new rules fire:
  - `unnecessary_type_name_in_constructor` — 95 findings (75 in `lib/`, 20 in `test/`),
    spanning 57 files. All are auto-fixable. `dart fix` rewrites `ClassName(...)` to
    Dart 3.13's `new(...)` unnamed-constructor shorthand.
  - `async_return_with_no_await` — 14 findings (7 in `lib/`, 7 in `test/`). No auto-fix;
    each needs a manual decision.
  - The other five new rules and the three removed rules produce zero findings.
- `dart format` churn under `automate`: 62 files reformatted, +1343 / −1960 lines
  (whitespace-only). The repo's CI gate is `dart format --output=none --set-exit-if-changed .`,
  which fails until every file is reformatted.
- Overriding `trailing_commas: preserve` reduces the format diff to zero before the
  constructor fixes. After `dart fix`, a normalising `dart format` touches only those 57
  constructor-fix files (≈95 changed lines).
- With v11 plus the 95 auto-fixes, `flutter test` still passes 548/548.

## Decision (recommended)

Adopt the v11 lint rules but **override `formatter.trailing_commas: preserve`** in this
repo's `analysis_options.yaml`, and treat adopting `automate` as a separate, deliberate
follow-up. Rationale: the rule adoption is the substance of the upgrade; a 62-file
whitespace reflow would dominate the diff, obscure the 95 constructor rewrites, and create
needless merge conflicts with in-flight work. `preserve` is the escape hatch upstream
documents for exactly this case, and `dart format --set-exit-if-changed` continues to gate
every PR — this is a formatting-convention choice, not a disabled check.

### Alternatives considered

| Option | Why not chosen |
| --- | --- |
| Adopt `automate` (upstream default) now | Reformats 62 otherwise-untouched files (+1343/−1960); buries the real change; conflicts with open branches. Better as its own formatting-only PR later. |
| Stay on `very_good_analysis` 10.3.0 | Leaves a stale linter and keeps Dependabot #60 open indefinitely. |
| Disable the new rules in `analysis_options.yaml` | AGENTS.md forbids disabling linters without permission; the required fixes are small and mechanical. |
| Land the constructor fixes in a separate PR | The v11 bump cannot pass `--fatal-infos` until the fixes land, so they must ship together or the bump lands with red CI. |

## Out of scope

- Flutter/Dart SDK changes (already on 3.13.1).
- Adopting `formatter.trailing_commas: automate` (recorded as a follow-up below).
- Any product/behaviour change — this migration is formatting and lint only.
- Bulk-upgrading unrelated transitive dependencies.

## Proposed file changes

```text
pubspec.yaml               — very_good_analysis ^10.3.0 -> ^11.0.0
analysis_options.yaml      — add formatter.trailing_commas: preserve, with a rationale comment
57 lib/ and test/ .dart    — 95 `dart fix` constructor rewrites (ClassName( -> new()
7 lib/ + 7 test/ .dart     — 14 manual async_return_with_no_await fixes
CHANGELOG.dev.md           — Unreleased / Changed entry
TO_DO.md                   — this plan's linked entry
```

Scope the auto-fix to the single code, so no other fix is applied implicitly:

```bash
dart fix --apply --code=unnecessary_type_name_in_constructor
```

## async_return_with_no_await sites (manual)

`lib/`:

- `lib/reports/report_save_service.dart:53`, `:71`
- `lib/services/file_operations.dart:66`, `:71`
- `lib/state/providers.dart:97`, `:235`
- `lib/utils/open_directory.dart:34`

`test/`:

- `test/services/config_service_fallback_test.dart:195`
- `test/services/config_service_test.dart:661`
- `test/services/fixture_test_root_save_restore_test.dart:337`, `:343`, `:349`, `:355`, `:380`

Decision rule: where the body is a bare `return <futureExpr>;` with no other `await`, drop
`async` and return the future directly (behaviour-preserving, and it avoids an extra
microtask hop); otherwise add `await`. Each site is already covered by existing tests.

## Phases & checklist

### Phase 0: Baseline and rollback point

- [ ] Confirm `main` is green: `flutter analyze --fatal-infos`, `dart format --output=none
      --set-exit-if-changed .`, `flutter test` (548), `dart_code_linter:metrics analyze lib
      --set-exit-on-violation-level=warning`.
- [ ] Record the rollback commit in this plan.
- [ ] Supersede Dependabot PR #60 (close with a link to the replacement PR).

### Phase 1: Toolchain bump and formatter decision

- [ ] `pubspec.yaml`: `very_good_analysis` `^10.3.0` → `^11.0.0`.
- [ ] `flutter pub get`; confirm the `pubspec.lock` diff is limited to `very_good_analysis`.
- [ ] `analysis_options.yaml`: add a `formatter:` block with `trailing_commas: preserve`
      and a one-line comment explaining the deliberate override.
- [ ] `dart format --output=none --set-exit-if-changed .` → 0 changed.

### Phase 2: Auto-fix the constructor lint

- [ ] `dart fix --apply --code=unnecessary_type_name_in_constructor` (expect 95 fixes in
      57 files).
- [ ] `dart format .` to normalise the rewritten constructors.
- [ ] Spot-check representative `lib/` and `test/` diffs to confirm the `new(...)` shorthand
      introduces no API or behaviour change.

### Phase 3: Hand-fix the async lint

- [ ] Apply the decision rule to each of the 14 sites listed above.
- [ ] `flutter analyze --fatal-infos` → 0 issues.

### Phase 4: Verify and ship

- [ ] Run the full gate suite (see Verification).
- [ ] Add the `CHANGELOG.dev.md` entry; set this plan's status; keep the `TO_DO.md` entry
      aligned.
- [ ] Open the PR to `main` (this supersedes #60).

## Verification

- [ ] `flutter pub get` — lock diff limited to `very_good_analysis`.
- [ ] `dart format --output=none --set-exit-if-changed .` — 0 changed.
- [ ] `flutter analyze --fatal-infos` — 0 issues.
- [ ] `dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning` — no issues.
- [ ] `flutter test --coverage` — 548/548 pass, line coverage ≥ 80%.
- [ ] CI green across `Analyze & format`, `Tests`, and the three `Build` matrix jobs.
- [ ] `dart format .` is idempotent (a second run reports no change).

## Open questions

- [ ] Maintainer sign-off on `trailing_commas: preserve` versus adopting `automate` now.
- [ ] Is the `new(...)` unnamed-constructor shorthand acceptable house style? It is standard
      Dart 3.13 syntax and is what `dart fix` prefers over repeating the class name.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| `preserve` diverges from the upstream default | low | low | Documented override; revisit as a formatting-only PR |
| `new(...)` shorthand unfamiliar to reviewers | med | low | Confined to 95 mechanical sites; analyze and tests stay green |
| A manual async fix changes scheduling or error behaviour | low | med | Only drop `async` where the body is a bare return; existing tests cover every site |
| Constructor rewrite spans many files, risking merge conflicts | med | low | Land promptly on a dedicated branch; the file list is explicit and re-derivable |
| Dependabot re-opens #60 after the upgrade | low | low | Close #60 as superseded once this lands |

## Follow-ups

- Adopting `formatter.trailing_commas: automate` (the upstream default) is deliberately
  deferred. It should be its own formatting-only PR, with a blank-line-insensitive review
  and no semantic changes.

## Completion steps (when status = complete)

When this plan is complete, follow this workflow:

1. **Update plan status** to `complete` or `abandoned`.
2. **Move this file to `plans/archive/`** (preserve git history).
3. **Log completion** in the appropriate changelog:
   - User-visible changes → `CHANGELOG.md`
   - Internal/harness changes → `CHANGELOG.dev.md`
   - Maintenance/security → `MAINTENANCE.md`
4. **Remove related items from `TO_DO.md`**.
5. **Clean up `.context/` scratch files** (archive or delete).
6. **Update `orchestration-state.md`** if present (set phase to `complete`/`blocked`).
7. **Reference the completion** with links to related commits/PRs.

# Plan: Phase 5.5 Follow-ups (chore)

**Status:** completed
**Created:** 2026-08-17
**Parent phase:** `plans/archive/phase_5.5_docs.md` (merged via PR #6)
**Master plan anchor:** `plans/active/initial_master_plan.md` → "Phase 5.5: Documentation Accuracy & Polish"
**Profile:** `.context/project-profile.md`

> **Verification note:** Every claim below was re-confirmed against the working tree on
> 2026-08-17 (branch `main` at `11a49a7`). Link facts come from a live run of
> `ci/scripts/check_doc_links.py`; naming facts from `lib/catalog/tool_descriptor_registry.dart`
> vs `docs/supported-tools.md`; changelog framing from `policies/changelog-conventions.md`.

---

## Goal

Close the small, mostly-docs/hygiene follow-ups left by the merged Phase 5.5 so the
repo stays internally consistent and the docs-accuracy work is fully landed. This is a
**chore branch**: docs edits, a test, a `.context` regeneration, and one trivial UI
action stub. No app behavior changes except the optional "Reveal backups folder" action.

---

## Scope

### In scope

1. **Fix 5 broken relative doc links** (real, pre-existing — confirmed by `check_doc_links.py`).
   The `tmp/` broken links are gitignored scratch and are **excluded**.
2. **Reconcile tool-display-name drift** between the registry and `docs/supported-tools.md`
   so a future drift-guard test can pass, then **add the cross-doc drift guard** (deferred
   from Phase 5.5 M3).
3. **Regenerate `.context/project-profile.md`** so it matches shipped code (gitignored, not
   shipped — tracked follow-up only).
4. **Strike the already-resolved `changelog-conventions` item** from `TO_DO.md` (it was
   fixed during Phase 5.5; see "Non-goals" below).
5. **"Reveal backups folder" UI action** — the one real feature follow-up. Backups
   retention/pruning already shipped; this adds the user-facing way to open the backups dir.

### Out of scope / explicitly excluded

- `tmp/docs-accuracy-assessment-2026-08-15T1335.md` link errors — gitignored scratch, ignore.
- `inventory/harness-engineering.md` `oreolion/ai-sync-plugin` → `Oreolion/ai-sync` redirect:
  this is an **advisory** (not broken), a prompt to re-evaluate, not delete. Defer to a
  separate repo-hygiene pass; do not touch here unless trivial.
- Phase 6 (Polish/Error Handling/Release), Phase 9 tool-support expansion, and the
  PR #5 Qodo/SonarCloud code-quality items — tracked elsewhere in `TO_DO.md`.
- New tool entries (Kilo, Cline, Cursor/IDE split, Antigravity splits) — Phase 9.

---

## Findings → Work items

### F1. Fix 5 broken relative doc links

- **Evidence (`check_doc_links.py` live run, 2026-08-17):** 5 `BROKEN` (non-`tmp`) links:
  - `ci/README.md:9` → `../.github/workflows/template-checks.yml`
  - `ci/README.md:48` → `examples/strict-sensitive-data.yml`
  - `hooks/README.md:86` → `../ci/examples/strict-sensitive-data.yml`
  - `inventory/medical-data-security.md:55` → `../ci/examples/strict-sensitive-data.yml`
  - `policies/commits-and-branches.md:65` → `../ci/examples/open-prs-advisory.yml`
- **Action:** Each broken target path does **not** exist anywhere in the tree — `ci/examples/`
  is absent, and `template-checks.yml` / `strict-sensitive-data.yml` / `open-prs-advisory.yml`
  are not present (the template-checks workflow appears to have been folded into
  `.github/workflows/ci.yml`; see `CHANGELOG.dev.md:65,97,177`). So the fix is **link removal
  or repoint**, not path correction:
  - `ci/README.md:9` (`../.github/workflows/template-checks.yml`) → repoint to
    `../.github/workflows/ci.yml` (or drop if no longer relevant).
  - `ci/README.md:48`, `hooks/README.md:86`, `inventory/medical-data-security.md:55`
    (`…/examples/strict-sensitive-data.yml`) → drop the link (target never existed in this repo).
  - `policies/commits-and-branches.md:65` (`…/examples/open-prs-advisory.yml`) → drop the link
    (target never existed in this repo).
   Apply the minimal correct change; do not rewrite surrounding prose. Re-run
   `check_doc_links.py` to confirm 0 `BROKEN` outside `tmp/`.

### F2. Reconcile registry ↔ supported-tools display names

- **Evidence:** `lib/catalog/tool_descriptor_registry.dart` `displayName` values are
  `Codex` (`:87`) and `Agy-ACP` (`:285`); `docs/supported-tools.md` uses `Codex CLI`
  (table `:13`, section `## Codex CLI` `:85`) and `agy-acp` (table `:20`, matrix `:568`).
  These two mismatches would make a case-sensitive *substring* display-name drift test fail on
  **1 of 9** tools only — `Agy-ACP` (the doc has only lowercase `agy-acp`). `Codex` already
  matches as a substring of `Codex CLI` (also standalone at `:243`, `:569`, `:596`), so it does
  not fail. F2-before-F3 is still required (for `Agy-ACP`); only the stated magnitude changes.
- **Action:** Treat the registry `displayName` as the source of truth (per the
  `docs/supported-tools.md` policy that the registry is authoritative for tool identity) and
  align the doc's **display-name** usages only:
  - Rename `Codex CLI` → `Codex` wherever it is a display name: table `:13`, `## Codex CLI`
    heading `:85`, and section subheadings `:87/:100/:119/:127/:135`.
  - Rename `agy-acp` → `Agy-ACP` only in **display-name** positions: the table cell `:20`
    (`| agy-acp |`) and the `## agy-acp` heading `:599`. **Do NOT** touch the many legitimate
    lowercase `agy-acp` occurrences that are paths, CLI commands, or fork URLs — specifically
    keep `:605-606`, `:613-616`, `:644`, `:684-685`, `:694` (and the matrix `:568`) unchanged.
    Note `agy` alone is Antigravity's CLI command (`:519`), distinct from `agy-acp`.
  - The CLI command examples (`claude`, `codex`, `agy`, `agy-acp`) and config paths stay as-is —
    those are command/identifier names, not display names.

### F3. Add the cross-doc drift guard (deferred from M3)

- **Where:** `test/catalog/tool_descriptor_registry_test.dart` (already locks
  `catalog.length == 9` at `:10`).
- **Action:** Add a low-risk test asserting that **every**
  `ToolDescriptorRegistry.catalog[i].displayName` appears as a substring in
  `docs/supported-tools.md` (read via `File('docs/supported-tools.md')` from package root
  CWD). This catches omissions/substitutions, not just count. Prerequisite: F2 must land
  first or the test fails on `Agy-ACP` only (the sole case-sensitive mismatch). Do **not** add a
  count-only assertion (already covered) and do **not** use an inline-HTML marker (MD033 not
  disabled in `.markdownlint.yaml`).

### F4. Regenerate `.context/project-profile.md`

- **Where:** `.context/project-profile.md` (gitignored; `AGENTS.md:25` is the row that tells
  agents to read it first — `:21` is the "Do not load everything" lead-in). Current stale
  claims: `:9` "sync", `:25` "call external CLIs", `:65` "diff/undo", `:72` open backup-location
  question.
- **Action:** Regenerate the file to match shipped code (local-only, no networking; no
  external CLIs; backup-before-write with diff + restore to `<appSupport>/backups`;
  backup retention/pruning shipped). No profile generator exists in the repo (checked
  `scripts/`, `ci/`, `tools/`, `hooks/`), so this is a **hand-edit** of the four stale spots to
  mirror `AGENTS.md`/`README.md` wording. Not shipped; local-only artifact.

### F5. Strike the already-resolved `changelog-conventions` TO_DO item

- **Evidence:** `policies/changelog-conventions.md:17` already reads "**Public / user-facing**"
  (not "template-consumer"); `AGENTS.md:88` says "user-facing changes go in". A repo-wide grep
  for `template-consumer` matches only `TO_DO.md:32` (the stale claim), the archived Phase 5.5
  plan, `tmp/` scratch assessments, and this plan file itself — **no shipped doc** contains it.
  The reconciliation was completed during Phase 5.5.
- **Action:** Remove the `TO_DO.md` bullet at `:31-33` ("Reconcile
  `policies/changelog-conventions.md` … still uses template-consumer framing") since it is
  already satisfied. Do not re-edit the policy file.

### F6. "Reveal backups folder" UI action

- **Where:** backup retention/pruning already shipped (`BackupService.maxBackupsPerPath = 10`,
  `_pruneOldBackups`); Phase 5.5 deferred only the user-facing reveal action.
- **Action:** Add a small UI affordance (e.g., a menu/button in `HistoryModal` or `MainShell`)
  that opens the app-support `backups` directory. `url_launcher` is already a dependency
  (`pubspec.yaml:42`) but **cannot reliably open local directories on all desktops** (Linux
  especially) — implement a platform-appropriate fallback: `url_launcher` first, then
  `Process.start('open'/'xdg-open'/'explorer')` on failure. Wire it to the existing
  `getApplicationSupportDirectory()` + `backups` subdir path used by `lib/main.dart:14-15`.
  Keep it minimal; mark complete in `TO_DO.md:10` when landed.

### Changelog entries (repo convention)

- Per `policies/changelog-conventions.md`: F6 is a **user-facing** change → add an entry under
  `## Unreleased` in `CHANGELOG.md`. F1–F5 are docs/test/tooling only (no product behavior) →
  add a single grouped entry under `## Unreleased` in `CHANGELOG.dev.md`. Do not mix the two.

---

## Execution order

1. **F2** (naming reconcile) — prerequisite for F3.
2. **F3** (drift guard test) — depends on F2.
3. **F1** (broken links) — independent, mechanical.
4. **F4** (`.context` regen) — local-only.
5. **F5** (strike resolved TO_DO item) — bookkeeping.
6. **F6** (UI action) — only real feature; do last, or defer if scope creep is a concern
   (it is the one item that touches app behavior).

---

## Verification (don't close until green)

- [ ] `flutter analyze --fatal-infos` passes (F3 test + F6 only app-touching items).
- [ ] `flutter test` passes, including the new display-name drift guard (F3).
- [ ] `dart format --output=none --set-exit-if-changed .` clean.
- [ ] `markdownlint` clean on edited docs (pre-commit).
- [ ] `python3 ci/scripts/check_doc_links.py` → 0 `BROKEN` outside `tmp/` (F1).
- [ ] F2 rename scope verified: `grep -n "Codex CLI" docs/supported-tools.md` → no matches
      (display-name usages renamed); `Agy-ACP` present in the `## Agy-ACP` heading; lowercase
      `agy-acp` still present in protected paths/CLI/fork-URL lines (`:605-606`, `:613-616`,
      `:644`, `:684-685`, `:694`) — not touched. Every `catalog[i].displayName` present in
      `docs/supported-tools.md` (F2/F3).
- [ ] `.context/project-profile.md` no longer says "sync"/"call external CLIs"/"diff/undo"
      and its backup question is resolved (F4).
- [ ] `TO_DO.md` item `:31-33` (changelog-conventions) removed; `:10` (Reveal backups)
      closed if F6 landed (F5/F6).
- [ ] Changelog entries added per convention: F6 → `CHANGELOG.md` `## Unreleased`; F1–F5 →
      `CHANGELOG.dev.md` `## Unreleased` (repo changelog-conventions policy).

## Done criteria

All F1–F6 items completed or explicitly deferred. `TO_DO.md` Phase-5.5 follow-up section
reflects actual state. The repo has zero non-scratch broken doc links and a guard that keeps
the tool registry and its documentation from silently drifting.

> **Severity note:** All items are L (polish) except F6, which is a minor M feature. No
> security relevance.

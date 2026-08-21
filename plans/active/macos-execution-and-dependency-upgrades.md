# Plan: macOS Execution & Dependency Upgrades

Last reviewed: 2026-08-21
Date: 2026-08-20
Author: maintainers (revised from assessments under `plans/assessments/` and
`plans/assessments/macos-execution-plan-ox-alpha-free-review-2026-08-21T003700-0400.md`)
Status: draft
Linked issue/PR: n/a

> Formerly `plans/active/cleanup-and-troubleshooting.md`. Renamed to match scope
> (no general cleanup work in this plan).

## Goal

Restore reliable macOS config discovery (and writable edit/backup of those files)
without a careless security regression; correctly triage known Flutter/Xcode
toolchain noise; and upgrade dependencies safely with lockfile + CI gates.

## Out of scope

- General repo cleanup unrelated to macOS execution or dependency upgrades
- Mac App Store submission in this cycle (explicitly deferred; Option C
  **complicates** a future MAS path — re-enabling sandbox is mechanical, but
  grant UX and prefs/data relocation are the durable costs; record in ADR-002)
- Changing Windows/Linux discovery semantics except to keep them working
- “Fixing” Flutter’s Run Script always-run warning by editing assemble/embed phases
- Dual sandboxed-MAS + unsandboxed-Developer-ID variants (rejected as Option D)

## Approach

1. **Diagnose before changing entitlements or home resolution.**
2. **Record ADR-002** for the macOS file-access / distribution model before
   changing sandbox posture.
3. **Provisional preferred decision (pending ADR acceptance): Option C** —
   non-sandboxed Developer ID + Hardened Runtime + notarization, with compensating
   controls. Once ADR-002 accepts C, implement the Option C branch only; keep A/B
   documented as rejected alternatives in the ADR (do not build bookmarks /
   temporary-exception sync machinery unless ADR reverses).
4. **Always implement** real-home resolution + container/inaccessible-home warnings
   (defense-in-depth even under Option C).
5. **Triage** Issue B / Issue C as verify-and-close toolchain items.
6. **Upgrade** dependencies in staged families with analyze / test / format gates.

### Alternatives for macOS file access (ADR-002 must pick one)

| Option | Summary |
| --- | --- |
| A. Sandbox + home-relative temporary exceptions + bookmarks for project/manual paths | Keeps sandbox; static allow-list for known user-scope dirs; runtime grants for arbitrary roots |
| B. Sandbox + bookmarks everywhere | Strongest least-privilege; highest UX friction (Open panel for home tool dirs too) |
| C. Non-sandboxed Developer ID + Hardened Runtime + notarization (**preferred**) | Matches peer local power-tools (VS Code, JetBrains, iTerm2); simplest FS model; not Mac App Store |

**Important:** “Disable the sandbox with no compensating controls” remains
unacceptable. Option C is *not* that — it is an explicit distribution/threat-model
choice with Hardened Runtime, notarization, and the compensating controls listed in
Phase 1A. Temporary exceptions alone cannot cover `prefs.projectRoots`, typed manual
paths, or custom-home overrides (`COPILOT_HOME`, etc.); if Option A were chosen,
bookmarks would be **mandatory** for project roots and manual paths, not a fallback.

**Distribution / “professionalism” (see ADR-002):** Option A is *not* inherently more
professional for all distribution. **MAS** → sandbox (A/B; prefer minimal exceptions
or B). **Developer ID outside the store** → **C + Hardened Runtime + notarization**
is the peer-tool norm; A’s hybrid stack is not automatically “more professional.”
**Source builds** → trust is the source; sandbox is defense-in-depth. Signing/
notarization is required for serious binary distribution under either model. Until
a Developer ID cert + notarization pipeline exist, ship **source-build-only** (do
not distribute ad-hoc unsigned binaries claiming Option C compliance).

---

## Phase 0: Diagnose (before any entitlement or resolver change)

- [ ] Log / inspect the resolved home from a Debug macOS run and confirm whether
      it is under `~/Library/Containers/<bundle-id>/Data`.
- [ ] Confirm whether discovery returns zero items with **no** home warning today
      (expected: home is non-null container path → silent empty list).
- [ ] Note whether edit/backup paths would also miss the real home (same resolver).
- [ ] Record findings in **this plan** (not `.context/`) before Phase 1.

---

## Phase 1A: ADR-002 — macOS file-access architecture

- [x] Add `docs/adr/ADR-002-macos-file-access.md` comparing Options A/B/C (and
      rejected Option D: dual variants). Status: **proposed** (not yet
      `accepted`); covers build-time vs runtime grants explicitly.
- [ ] **Accept decision: Option C** (unless Phase 0 evidence forces a rethink), with:
      - Distribution channel: Developer ID outside Mac App Store (or
        source-build-only until cert/notarization exist)
      - **Final `PRODUCT_BUNDLE_IDENTIFIER` chosen** (replace
        `com.example.agentsConfigHelper` before signing; parameterize container
        heuristic + prefs migration by bundle id)
      - Compensating controls (**mechanized**, not prose-only):
        - `ENABLE_HARDENED_RUNTIME = YES` on Release; ship only notarized signed
          binaries; assert `codesign -d --entitlements :-` matches expected set;
          no debug-only CS entitlements (`cs.allow-jit`) in notarized artifacts
        - Backup-before-write + diff preview as in-app containment; document in
          README / security docs
        - No runtime network beyond existing `url_launcher` outbound; keep
          “nothing leaves the machine” data classification
        - Fail-closed parsing + robustness/fuzz tests for parsers reading
          project/config input (unsandboxed blast radius)
        - Planned (not merely optional): confirm writes outside the
          discovered-config set
      - Revisit triggers: MAS requirement, enterprise sandbox mandate, or Apple
        trust-model change
- [ ] Document A/B limitations that motivated C: project roots, manual paths,
      **custom-home overrides** (`COPILOT_HOME` / future XDG-style) cannot be covered
      by static home-relative exceptions alone.
- [ ] Prefs persistence: `DiscoveryPreferencesStore` / `lib/main.dart` use
      `getApplicationSupportDirectory` (container under sandbox). **Decide and
      implement** one-time best-effort copy from old container Application Support
      when the new store is empty (do not leave as docs-only).
- [ ] Link ADR from `ARCHITECTURE.md`, `.context/project-profile.md`, and a short
      pointer in `AGENTS.md`.

**Do not change sandbox entitlements until ADR-002 status is `accepted`.**
Acceptance implies the mechanized controls above are checklist-complete (or
explicitly deferred with owners), not merely intended.

---

## Phase 1B: Issue A — Config discovery under macOS access model

*Depends on Phase 0 evidence and Phase 1A decision.*

### Symptom / context

App shows “No configurations found.” Sandbox (when enabled) makes
`Platform.environment['HOME']` the container; `resolveHomeDirectory()` trusts that
env var only. Project-scope discovery also walks arbitrary
`DiscoveryRequest.normalizedProjectRoots`. Custom homes (`COPILOT_HOME`) may point
outside default `~/.…` trees.

### 1B-i — Home resolution + warnings (sandbox still on)

*Separate commit from the entitlement flip for bisectability. Under sandbox,
discovery may still be empty even with a correct real-home path — expected; this
step validates warning UX and heuristics.*

- [ ] On macOS, resolve real home via **`getpwuid_r(getuid())` → `pw_dir`**, copy
      the path string immediately (do **not** use plain `getpwuid`; do **not** use
      `NSHomeDirectory()` / naive platform-channel wrappers — those return the
      container under App Sandbox). Keep Darwin `struct passwd` layout in one
      tested place (arm64 vs x86_64 padding risk).
- [ ] Gate Darwin FFI / conditional imports so Windows/Linux builds and CI never
      import macOS-only symbols.
- [ ] Fallback chain: real-home (Darwin FFI) → existing env logic
      (`HOME` / `USERPROFILE` / Windows `HOMEDRIVE`+`HOMEPATH`) → optional
      container-path heuristic (strip `/Library/Containers/<bundle-id>/Data` when
      present; use the **chosen** bundle id) as last-resort insurance.
- [ ] Keep `homeDirectoryResolverProvider` as the injection seam for tests
      (FFI will not run on Linux CI).
- [ ] Add a sandbox/container (or inaccessible-home) warning through the
      **existing** `DiscoveryWarning` → sidebar warnings pipeline in
      `main_shell.dart` — do not invent a parallel empty-state-only UI.
- [ ] Empty state must not look identical to “user has no tools installed.”

### 1B-ii — Entitlements flip + release controls (after ADR accepted)

- [ ] **Delete** `com.apple.security.app-sandbox` from **both**
      `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`
      (prefer delete over `false`). Audit for now-inert leftover sandbox keys.
- [ ] Preserve DebugProfile `com.apple.security.cs.allow-jit` and
      `com.apple.security.network.server` for Flutter tooling only.
- [ ] Set / verify `ENABLE_HARDENED_RUNTIME = YES` on Release; document Debug
      posture; add Release acceptance check via `codesign -d --entitlements :-`.
- [ ] Document Hardened Runtime + notarization + **source-build-only until
      cert exists**; note Gatekeeper quarantine on downloaded zips in README.
- [ ] Implement prefs one-time migration (Phase 1A decision).
- [ ] Do **not** implement temporary-exception lists, catalog↔entitlements sync
      tests, or security-scoped bookmarks unless ADR-002 reverses to A/B.

### Access grants — Option A only (inactive unless ADR reverses)

*Skip entirely under Option C. Retained for ADR completeness.*

- Home-relative temporary exceptions for catalog-derived user-scope top-level
  dirs. Apple requires **leading `/` and trailing `/` for directories** on
  home-relative keys (e.g. `/.claude/`, `/Documents/Cline/Rules/`) — see Apple
  Entitlement Key Reference. Sync test must assert that format (require leading
  slash; do not reject it).
- Bookmarks mandatory for project roots and manual paths.
- Custom-home overrides outside granted dirs remain a known limitation (N2).

### Access grants — Option B only (not recommended)

*Skip. Open-panel-everywhere breaks auto-discovery UX.*

### Docs / changelog for Issue A

- [ ] Public `CHANGELOG.md` (Security / Changed) for user-visible access-model change;
      consider SemVer impact.
- [ ] `ARCHITECTURE.md`: home-resolution chain + chosen access model (Option C).
- [ ] README / security note: Developer ID distribution, Hardened Runtime,
      notarization, backup-before-write, source-build-only until cert, Gatekeeper
      quarantine note for downloaded zips.
- [ ] Developer notes in `CHANGELOG.dev.md` only for pure tooling.

---

## Phase 1C: Issue B — `Failed to foreground app; open returned 1`

- [ ] Verify Dart VM service connects and the process is alive (Activity Monitor /
      `ps`). If yes, treat as **benign Flutter toolchain noise**
      ([flutter/flutter#176850](https://github.com/flutter/flutter/issues/176850) —
      confirm the issue link still resolves before archiving this plan).
- [ ] Only if the process exits or never paints: run
      `./build/macos/Build/Products/Debug/agents_config_helper.app/Contents/MacOS/agents_config_helper`
      and inspect `~/Library/Logs/DiagnosticReports/`.
- [ ] Cross-ref Issue C: same Flutter regression era often surfaces the Run Script
      note alongside this message; both may clear on the same Flutter upgrade.
- [ ] **Exit criterion:** close when Flutter stable includes an upstream fix for
      #176850 (or equivalent), or document “wontfix / track upstream” with the
      last verified Flutter version.

---

## Phase 1D: Issue C — Xcode Run Script warning

- [ ] Confirm `alwaysOutOfDate = 1` and `ENABLE_USER_SCRIPT_SANDBOXING = NO` remain
      in `macos/Runner.xcodeproj/project.pbxproj` (already true today).
- [ ] **Accept as expected Flutter template noise.** Do not add synthetic outputs or
      clear `alwaysOutOfDate` on Flutter-owned phases (asset/assemble risk).
- [ ] No xcconfig duplicate of script-sandboxing required unless pbxproj drifts.

---

## Phase 2: Dependency audit & upgrade

**Goal:** Safely update dependencies and lockfile while managing breaking changes.

- [ ] **Baseline:** `flutter pub outdated`.
- [ ] **Rollback anchors:** commit (or tag) before each major-bump family so a bad
      family can be reverted independently.
- [ ] **Stage 1 (safe):** `flutter pub upgrade` for minor/patch only → verify →
      commit `pubspec.lock`.
- [ ] **Stage 1 / Stage 2 verification (every stage):**
      - `flutter analyze --fatal-infos`
      - `flutter test`
      - `dart format --output=none --set-exit-if-changed .`
- [ ] **Stage 2 (majors):** one package **family** at a time.
      - Riverpod stack moves in **lockstep**: `flutter_riverpod`,
        `riverpod_annotation`, `riverpod_generator` (then **always** run
        `dart run build_runner build --delete-conflicting-outputs`, review
        `.g.dart` drift, then **re-run the format gate** after codegen).
      - Analyzer-coupled linters **last** after any SDK constraint move:
        `very_good_analysis`, then `dart_code_linter` (custom_lint ecosystem often
        lags Dart SDK; document fallback if incompatible on release day).
- [ ] Codegen for non-generator bumps only when analysis shows `.g.dart` drift.
- [ ] Log dependency bumps in `CHANGELOG.dev.md` (public `CHANGELOG.md` only if a
      bump changes user-visible/runtime behavior or security posture).

---

## Verification / acceptance criteria

### Issue A (Option C)

- [ ] Debug macOS run discovers known user-scope configs from the **real** home for
      tools the developer has installed.
- [ ] Project roots and manual paths work without Open-panel grants.
- [ ] Discovery finds configs under a **`COPILOT_HOME`-style override** outside
      default `~/.copilot` (regression guard for custom-home edge cases).
- [ ] Save + timestamped backup still succeed.
- [ ] Hot reload still works (DebugProfile JIT + network.server preserved).
- [ ] Windows/Linux: env-based home resolution and discovery unchanged in CI.
- [ ] Sandbox key **deleted** from both entitlements files; Release has
      Hardened Runtime enabled; notarization / source-build-only documented.
- [ ] macOS-host FFI home-resolution test green on `macos-latest`.
- [ ] Final non-`com.example` bundle ID in place (or explicitly deferred with owner
      until first signed release).

### Issues B / C

- [ ] B classified (benign vs real crash) with evidence; exit criterion recorded;
      #176850 link confirmed.
- [ ] C left as accepted noise (or cleared by Flutter upgrade).

### Phase 2

- [ ] Analyze, test, and format gates green after each stage (including after
      codegen); lockfile committed.

---

## Test plan (add with Issue A implementation)

| Test | Level | Why |
| --- | --- | --- |
| Resolver fallback chain via `homeDirectoryResolverProvider` overrides | Unit | FFI unavailable on Linux CI |
| Container-path heuristic strips `/Library/Containers/<id>/Data` | Unit | Easy to get wrong |
| Container-shaped home ⇒ sandbox warning in empty / warning banner | Widget | Covers UX step |
| Darwin FFI gated out; Windows/Linux still use env fallback | Unit on CI matrix | Cross-platform safety |
| **Real Darwin FFI home == unsandboxed `$HOME` / `dscl` NFSHomeDirectory** | Unit/integration on **macos-latest** | Struct-offset risk; mocks alone are insufficient |
| `COPILOT_HOME` override discovery (absolute path outside default home tree) | Unit | Option C acceptance / N2 guard |

*Option A only (inactive under C): catalog ↔ entitlements sync asserting leading `/` + trailing `/` on home-relative dirs; bookmark resolve + stale handling.*

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Option C without compensating controls ≈ reckless unsandbox | Med if rushed | High | ADR-002 mechanized checklist; Hardened Runtime build setting + notarization runbook |
| FFI `struct passwd` mis-parse ⇒ silently wrong home | Med | High | macOS-host FFI equivalence test; single tested struct definition |
| Unsigned / ad-hoc binary distributed as “Option C” | Med if rushed | High | Source-build-only until Developer ID + notarization exist; README |
| Template bundle ID shipped / heuristic keyed wrong | Med | Med | Choose final bundle ID before signing; parameterize migration/heuristic |
| MAS later required → major rework | Low near-term | High | Record as accepted consequence; revisit triggers in ADR |
| `NSHomeDirectory` / channel “fix” reintroduces container HOME | Med | High | Plan forbids it; code review + tests |
| Prefs lost when leaving sandbox container support dir | Low | Med | One-time best-effort migration (not docs-only) |
| Parser bug under full FS access | Low | High | Fail-closed parsing + robustness/fuzz tests named in ADR |
| Major Riverpod/linter bumps break CI | Med | Med | Family-by-family + rollback commits; linters last; format after codegen |
| Editing Run Script phases breaks builds | Low if followed | High | Issue C: do nothing |
| *(A only)* Ship exceptions without bookmarks → project discovery empty | — | — | Retired if C accepted |
| *(A only)* Entitlement list drifts / wrong path format | — | — | Retired if C accepted; if A: sync test + Apple leading-`/` rule |

---

## Open questions (resolve in ADR-002)

- [x] Preferred option? → **C** (provisional; confirm in ADR-002)
- [ ] Distribution channel for v1 / near-term releases? → Developer ID or
      source-build-only until cert
- [ ] Confirm compensating-controls checklist owners (signing/notarization runbook;
      Hardened Runtime Release setting)
- [ ] Final bundle ID value
- [ ] Custom-home overrides (`COPILOT_HOME` / future XDG): document as first-class
      under C; known limitation under A/B
- [ ] Minimum Open-panel UX for batch-adding project roots? → N/A under C; required
      under A/B

## Completion steps (when status = complete)

1. Set status to `complete`.
2. Move this file to `plans/archive/`.
3. Log in `CHANGELOG.md` / `CHANGELOG.dev.md` as appropriate.
4. Remove related `TO_DO.md` items if any.
5. Ensure ADR-002 remains the durable record for the access-model decision.

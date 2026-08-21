# Assessment: macOS Execution & Dependency Upgrades Plan + ADR-002 (Option C)

**Assessment date:** 2026-08-21T00:37:00-04:00 (America/New_York)
**Reviewed by:** ox-alpha (opencode / x-preview-f-free) — independent senior Flutter/Dart/macOS review
**Mode:** Read-only review of tracked sources; originally written under `tmp/`,
canonical copy is this `plans/assessments/` file.
**Files under review:**

- `plans/active/macos-execution-and-dependency-upgrades.md` (status: draft)
- `docs/adr/ADR-002-macos-file-access.md` (status: proposed; preferred Option C)
- Lineage skimmed: `plans/assessments/macos-execution-and-dependency-upgrades-plan-assessment-2026-08-20T235617-0400.md`

**Ground-truth checks performed against source** (claims in plan/ADR were verified, not taken on faith):

- `macos/Runner/DebugProfile.entitlements` — currently `app-sandbox=true`, `cs.allow-jit=true`, `network.server=true`
- `macos/Runner/Release.entitlements` — currently `app-sandbox=true` only
- `macos/Runner.xcodeproj/project.pbxproj` — **no `ENABLE_HARDENED_RUNTIME` anywhere**; bundle ID is template placeholder `com.example.agentsConfigHelper…` (lines 398/412/426)
- `lib/services/home_directory_resolver.dart:41-56` — env-only resolution (`HOME` → `USERPROFILE` → Windows `HOMEDRIVE`+`HOMEPATH`), as the plan describes
- `lib/state/providers.dart:77` — `COPILOT_HOME` honored
- `lib/services/discovery_preferences_store.dart:52` and `lib/main.dart:14` — both use `getApplicationSupportDirectory` (prefs-migration exposure is real)

---

## Verdict

**Ready with nits.** No High-severity defects. The plan and ADR are technically accurate on every macOS-specific claim I checked, internally consistent with each other, and correctly sequenced. Four Medium findings (M1–M4) should be folded into the Phase 1A acceptance checklist at or before ADR acceptance; none blocks starting Phase 0.

**Explicit position on Option C: agree, strongly, for near-term.** Details below.

---

## Findings (severity ordered)

### M1 — No test exercises the real Darwin FFI resolver (highest bug risk in the plan)

Plan lines 122–133 introduce hand-rolled FFI (`getpwuid_r(getuid())` → `pw_dir`). The test table (plan lines 260–270) covers provider-injected fallback chains (i.e., mocks), container-heuristic string handling, and cross-platform gating — but **nothing runs the actual FFI path on a macOS host**. Darwin's `struct passwd` layout differs between arm64 and x86_64 in padding-sensitive ways; an offset error yields a *silently wrong home directory* — the worst possible failure mode for an app whose entire job is reading/writing files under home. The existing tests would stay green while discovery scans the wrong tree.

**Recommend:** add a macOS-host test row (runs on the existing `macos-latest` CI leg) asserting the FFI-resolved home equals the unsandboxed `$HOME` (and/or the Directory Service NFS home for the current user); keep the struct definition in one tested location; copy the string immediately (already specified). This closes the gap between "fallback chain tested via mocks" and "the real thing works."

### M2 — Hardened Runtime is prose-only; no implementation hook exists

Compensating control #1 (ADR lines 181–183; plan lines 87, 148–150, 246–247) has no mechanism behind it: grep of `macos/Runner.xcodeproj/project.pbxproj` shows **no `ENABLE_HARDENED_RUNTIME` setting**, and `Release.entitlements` contains nothing but `app-sandbox`. Under Option C the plan should add concrete steps:

- Set `ENABLE_HARDENED_RUNTIME = YES` on the Release build configuration (decide Debug posture explicitly).
- Assert no debug-only CS entitlements (`com.apple.security.cs.allow-jit`) leak into notarized artifacts.
- Add an acceptance checkbox: release build passes `codesign -d --entitlements :-` inspection with exactly the expected set.

Without this, "Hardened Runtime + notarization" remains aspirational — precisely the "reckless unsandbox" outcome the plan's own risk table warns against (plan line 278).

### M3 — Bundle identifier is still the Flutter template placeholder

`PRODUCT_BUNDLE_IDENTIFIER = com.example.agentsConfigHelper…` (pbxproj lines 398/412/426). Before any Developer ID signing/notarization this must change, and it interacts with three plan items:

1. The container-path heuristic strips `/Library/Containers/<bundle-id>/Data` (plan lines 130–131, 265) — a bundle-ID change re-bases that constant.
2. Prefs migration (plan lines 97–100): the old container Application Support path is keyed by the old bundle ID.
3. Signing identity and Gatekeeper trust.

**Recommend:** make "final bundle ID chosen" a Phase 1A/1B sub-task before the entitlement flip, and parameterize the heuristic + migration notes by bundle ID rather than hardcoding.

### M4 — Untrusted-input parser hardening deserves named compensating-control status

Under C the process has full user-session filesystem reach **and parses attacker-influenced content**: project-root scans ingest arbitrary repos (`.github/copilot-instructions.md`, `.cursor/rules/`), and configs contain tokens (ADR context, lines 12–21). A parser memory-safety or logic bug now has maximal blast radius. The ADR's controls cover signing and backup-before-write but never mention input robustness.

**Recommend:** add a compensating control to ADR-002 Consequences: fail-closed parsing plus robustness/fuzz tests for the TOML/YAML/front-matter parsers (cf. ADR-001 TOML work), and consider promoting "confirm writes outside the discovered-config set" from optional to planned. Low likelihood, high impact, cheap to name.

### L1 — Prefs migration is document-only

Plan lines 97–100 / risk row line 281 and the ADR Neutral section (lines 191–195) only document the container→real-home Application Support move. Cheap improvement: one-time best-effort copy from the old container path when the new store is empty (covers both `DiscoveryPreferencesStore` at `discovery_preferences_store.dart:52` and whatever `lib/main.dart:14` persists). Prevents predictable "my saved paths vanished" reports from early Debug-build users.

### L2 — Split Phase 1B into two commits for bisectability

(a) Resolver + warnings while sandbox is still on (validates warning UX and heuristics; discovery will still be empty — expected), then (b) the entitlement flip. The sequencing gate at plan line 104 is good governance, but commit granularity is unstated.

### L3 — Entitlement cleanup detail

Prefer deleting `com.apple.security.app-sandbox` outright over setting `false` (plan line 144 allows either); after the flip, audit both plists for now-inert sandbox keys so shipped entitlements tell the truth. Trivial, keeps the security-review surface clean.

### L4 — Format gate after codegen

Phase 2 Riverpod lockstep (plan lines 220–228) runs `build_runner`; generated `.g.dart` can differ in formatting. Run the format gate after codegen within that stage, not only at stage end.

### N1 — Unverified upstream link

flutter/flutter#176850 (plan line 185, ADR line 237) was not verified in this review; confirm the issue resolves before archiving the plan.

### N2 — "Permanently complicates" slightly overstated (plan lines 22–23)

Re-enabling the sandbox later is mechanical; the durable costs are grant UX and data/prefs relocation. The ADR's revisit triggers already handle this honestly — soften the plan wording to match.

### N3 — Alternatives-summary cell nit (ADR line 205)

Option C's "user can extend in-app: N/A" — bookmarks remain possible as optional hardening under C per ADR lines 217–218; cell could say "optional."

### N4 — Phase 0 findings destination ambiguous (plan line 74)

"in this plan or `.context/`" — pick one (recommend the plan) to avoid drift.

---

## Option C agreement (explicit)

**Agree with Option C for near-term.** The product shape decides it: auto-discovery across the real home + arbitrary project roots + typed manual paths + env overrides (`COPILOT_HOME`) is fundamentally incompatible with build-time static grants. Option A forces two coexisting access models plus catalog↔release coupling (every new tool directory needs a shipped build); Option B breaks the core "open the app and see your agents" promise with Open-panel friction on hidden dot-directories. Option C deletes whole failure classes (exception drift, bookmark rot, silent custom-home misses) and matches peer local power-tools. Conditions, all already half-present in the docs: compensating controls must be mechanized (M2/M3), not prose; keep real-home resolution + container warnings as defense-in-depth (plan already does); record the MAS consequence in the ADR (done).

## Distribution / professionalism framing

**Agree with the ADR's channel-relative framing** (ADR lines 144–154); I disagree with any absolute "sandbox = professional" claim:

- **MAS ⇒ sandbox mandatory; temporary exceptions review-hostile** — correct, and correctly rules out C for that channel.
- **Developer ID outside the store ⇒ signed + notarized + Hardened Runtime, unsandboxed** — genuinely the peer norm (VS Code, JetBrains IDEs, iTerm2 all ship this way). A hybrid exceptions+bookmarks stack is not "more professional"; it is more machinery with more failure modes.
- **Source builds ⇒ trust boundary is the repo; sandbox is defense-in-depth** against dependency/parser bugs, not the primary boundary — the ADR states this with appropriate nuance (lines 32–35, 139–142).

One sharpening: until a Developer ID certificate and notarization pipeline actually exist, the project ships source-build-only and should say so plainly; distributing ad-hoc unsigned binaries would violate Option C's own controls. Also note Gatekeeper/quarantine applies to users who download even "source-era" zip artifacts through a browser — worth one README sentence.

## Sequencing assessment

Sound. Phase 0 evidence → ADR accepted → Option C branch, with the entitlement freeze (plan line 104) mirrored in the ADR's implementation notes (ADR lines 220–228), is correct governance. Only additions: the L2 commit split, and folding M2/M3 into the Phase 1A acceptance checklist so that "accepted" implies mechanized controls rather than intent.

## Recommended edits (concrete)

**Plan — `plans/active/macos-execution-and-dependency-upgrades.md`:**

1. Phase 1A acceptance checklist: add "final bundle ID chosen (M3)" and "Hardened Runtime build-setting step identified for Release config (M2)."
2. Phase 1B: split into 1B-i (resolver + warnings, sandbox intact) and 1B-ii (entitlements flip) commits (L2); specify delete-not-`false` for the sandbox key (L3).
3. Test plan: add a macOS-host FFI-equivalence test row (M1); note it runs on the `macos-latest` CI leg.
4. Risks table: add "FFI struct mis-parse ⇒ silently wrong home" (mitigated by M1 test) and "unsigned binary distributed" (mitigated by a signing/notarization runbook).
5. N2/N4 wording fixes.

**ADR — `docs/adr/ADR-002-macos-file-access.md`:**

1. Compensating controls: mechanize #1 (`ENABLE_HARDENED_RUNTIME = YES` on Release; strip debug CS entitlements from notarized artifacts); add parser-hardening control (M4); note the bundle-ID prerequisite (M3).
2. Neutral section: either decide the one-time best-effort prefs migration (L1) or explicitly reject it with rationale.
3. N3 cell fix; confirm the #176850 link (N1).

---

## Bottom line

A well-engineered plan and an unusually honest ADR; the Option C call is right for this product at this moment. Fix M1–M3 — actually test the FFI on macOS, mechanize Hardened Runtime, resolve the bundle ID — at ADR-acceptance time, and this is ready to execute end to end.

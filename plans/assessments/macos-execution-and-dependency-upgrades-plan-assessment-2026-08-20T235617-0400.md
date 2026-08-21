# Assessment: `plans/active/macos-execution-and-dependency-upgrades.md`

**Assessment date:** 2026-08-20T23:56:17-0400  
**Last updated:** 2026-08-21T00:06:00-0400 (Composer concurrence + N1 correction)  
**Reviewed by:** ox-alpha (original); Composer (update — agrees with Option C; corrects N1)  
**File under review:** `plans/active/macos-execution-and-dependency-upgrades.md` (status: draft)  
**Canonical location:** `plans/assessments/macos-execution-and-dependency-upgrades-plan-assessment-2026-08-20T235617-0400.md`  
**(Moved from `tmp/`; do not treat `tmp/` copy as source of truth.)**

**Lineage:** Third review of this plan. Supersedes
`tmp/cleanup-and-troubleshooting-plan-assessment-2026-08-20T231413-0400.md` (original draft) and
`tmp/cleanup-and-troubleshooting-plan-assessment-2026-08-20T233327-0400.md` (first revision).
This revision restructured the plan per prior feedback; the focus here is the **Option A/B/C
decision** plus residual nits.

---

## Verdict

**Ready for implementation pending a short Phase 1A ADR that records Option C.** The plan
revision resolves every critical finding from the two prior assessments. Residual work is
polish plus locking the distribution/access decision. **This update concurs with choosing
Option C**, with compensating controls as listed below. One residual finding (N1) in the
original 23:56 text was factually wrong and is corrected here — do not follow the old N1
“no leading slash” guidance.

---

## Traceability: prior findings vs this revision

| Prior finding | Addressed? |
| --- | --- |
| Project-root scanning incompatible with static exceptions; bookmarks mandatory | Yes — explicit in Approach + Phase 1B |
| Entitlement list incomplete vs catalog; no sync mechanism | Yes — derivation rule + unit test |
| "Disable sandbox = unacceptable" asserted without analysis; ADR needed | Yes — Phase 1A gates implementation on an accepted ADR |
| `NSHomeDirectory()` trap; use `getpwuid_r`; copy string immediately | Yes — stated verbatim |
| Platform gating for Darwin FFI; injection seam for tests | Yes — both |
| Container-path heuristic fallback missing | Yes — added as last-resort link |
| Prefs-store container migration trap | Yes — noted in Phase 1A + risks |
| Format gate missing from Phase 2 | Yes — added to every-stage verification |
| Lint-plugin lag risk; upgrade ordering | Yes — linters last, fallback documented |
| Riverpod lockstep + unconditional codegen for that family | Yes |
| Rollback anchors | Yes |
| Issue B exit criterion; B/C cross-reference | Yes |

---

## Residual findings

### N1. Entitlement path format — **corrected** (was Medium; original claim was wrong)

The 23:56 draft claimed home-relative exception paths must be *without* a leading slash
(e.g. `.claude/`, `Music/`), and that `/.claude/` would be silently ignored.

**That is incorrect.** Apple’s App Sandbox Temporary Exception Entitlements reference states
explicitly that **each string must start with a slash (`/`)** whether the key is
`home-relative-path` or `absolute-path`, and that directories must end with a trailing slash.
For home-relative keys, the value is still “relative to `~`” but encoded with a leading slash
(e.g. `/.claude/`, `/Documents/Cline/Rules/`). Community write-ups match this
(`/Desktop`, `/Library/.../`).

**Action for Option A (if ever chosen):** keep slash-prefix + trailing-slash; the sync test
should **require** a leading `/` on home-relative entries (reject missing slash), not reject
leading slashes. The plan’s original Phase 1B wording was already aligned with Apple — leave it.

### N2. Static grants can't cover custom-home overrides either (Low — ADR input)

Discovery already honors `COPILOT_HOME`
(`lib/state/providers.dart:77-78`) and the general design implies possible XDG-style overrides.
Under Option A/B, any override pointing outside granted dirs fails even with perfect entitlement
coverage. This strengthens the case for Option C and belongs in the ADR’s “options considered”
limitations for A/B.

### N3. Next ADR number is 002 (Nit)

`docs/adr/` contains `ADR-001-toml-comment-preservation.md`. Use **ADR-002**.

### N4. CI matrix supports the cross-platform test row (Confirmation)

`.github/workflows/ci.yml` build job runs on `macos-latest`, `ubuntu-latest`, `windows-latest`, so
the "Darwin FFI gated out; Windows/Linux still use env fallback" test-plan row is executable as
written.

### N5. Option C branch should be explicit (Nit — adopted)

If Option C wins: remove `com.apple.security.app-sandbox` from *both* entitlements files (or set
false), keep `allow-jit` / `network.server` in DebugProfile (Flutter tooling), and note that local
`flutter run` debug builds bypass Gatekeeper — Option C adds zero day-to-day dev friction;
notarization + Hardened Runtime matter for **distributed** binaries.

---

## The core decision: Options A / B / C

### Option A — Sandbox + home-relative temporary exceptions + bookmarks for project/manual paths

| Pros | Cons |
| --- | --- |
| Keeps sandbox containment: a compromised app can only touch granted dirs | Temporary exceptions are Apple-discouraged by name and revocable; rejected outright for MAS |
| Zero-friction auto-discovery for catalog tools (no panels) — preserves the product's "auto-detect common paths on first launch" promise | Two coexisting access models (static grants + bookmark machinery) = double implementation, double bug surface |
| Read/write to known tool dirs just works, including edit/backup flows | Bookmarks are required *anyway* for project roots/manual paths — so the hard part isn't avoided, only augmented |
| Sync test makes drift enforceable | Catalog drift still possible for new tools until test catches it; every new tool needs a release to grant access |
| | Custom-home overrides (`COPILOT_HOME`, future XDG-style) outside granted dirs silently fail (N2) |
| | Most complex option overall: hybrid semantics hardest to explain in docs/support |

### Option B — Sandbox + bookmarks everywhere

| Pros | Cons |
| --- | --- |
| Purest least-privilege; no deprecated/discouraged entitlements; most future-proof vs Apple policy | First-run UX is brutal: users must Open-panel their way to hidden dot-dirs (`cmd+shift+.`), per directory, per new tool |
| Single uniform access model — one mechanism to build/test/document | Fundamentally breaks the stated product feature of automatic first-launch discovery (AGENTS.md) |
| No entitlement maintenance or drift risk | Bookmark rot/stale handling becomes a permanent support burden |
| Works identically for any path, including custom homes | Highest abandonment risk for a pre-1.0 tool whose first impression is "it found nothing" |

### Option C — Non-sandboxed Developer ID + Hardened Runtime + notarization

| Pros | Cons |
| --- | --- |
| Simplest filesystem model: everything works — user-scope dirs, arbitrary project roots, manual paths, custom-home overrides — with zero grants | No sandbox containment: full user-session FS access if the binary is compromised at runtime |
| Matches the distribution norm for peer local power-tools (VS Code, JetBrains IDEs, iTerm2) | Permanently rules out Mac App Store distribution (currently out of scope, but irreversible-ish architecture choice) |
| No bookmark machinery, no entitlement drift, no sync test, no temporary exceptions — deletes entire failure classes the plan currently guards against | Relies on compensating controls rather than OS-enforced confinement |
| Notarization + Hardened Runtime preserve Gatekeeper trust, code identity, and supply-chain checks | Some locked-down enterprise environments prefer sandboxed apps (rare blocker in practice) |
| Least code, fastest to ship, fewest moving parts for a pre-1.0 maintainer | If MAS ever becomes a goal, significant rework (record as accepted consequence in ADR) |

### Option D (considered and rejected): dual variants

Shipping both a sandboxed store build and an unsandboxed Developer ID build doubles packaging, QA,
and support surface for zero current demand. Revisit only if MAS becomes real.

---

## Recommendation

**Choose Option C** (non-sandboxed Developer ID + Hardened Runtime + notarization), recorded in
ADR-002.

**Composer concurrence:** Agree. For this product (local agent/IDE config manager, auto-discovery
across home + arbitrary project roots, pre-1.0, MAS out of scope), A is the worst complexity/risk
tradeoff and B breaks the core auto-discovery promise. Option C matches peer tools and deletes
whole failure classes — *provided* compensating controls are real, not aspirational.

Caveats (still agree, with eyes open):

1. Formalize C in ADR-002 before ripping sandbox out of Release — do not treat this assessment as
   the ADR.
2. Compensating controls must be checklist items, not prose-only.
3. Keep real-home resolution + container detection as defense-in-depth (cheap; helps if someone
   re-enables sandbox later or runs under unexpected confinement).
4. Drop Option-A-only scope (exception lists, catalog↔entitlements sync, bookmarks) from the
   active checklist once ADR-002 accepts C; retain A/B as rejected alternatives in the ADR.

**Compensating controls to write into the ADR** (separates Option C from unacceptable “just
disable it”):

- Hardened Runtime enabled; distribute only notarized, signed binaries.
- Keep the existing backup-before-write + diff-preview safety model as the in-app containment
  story; document it as such.
- No network entitlements needed at runtime beyond existing `url_launcher` outbound links; keep
  the internal data classification ("nothing leaves the machine") in README/security docs.
- Optional hardening: in-app confirmation for writes outside the discovered-config set.

**Revisit triggers** (also record in ADR): a concrete MAS requirement, an enterprise customer
mandating sandboxed builds, or Apple degrading notarized-app trust.

If the maintainers nonetheless pick **A**: accept the bookmark stack as mandatory scope, keep
Apple’s leading-`/` path format (see corrected N1), assert leading `/` + trailing `/` in the sync
test, and add N2 (custom homes) to the ADR’s limitations section. **B** is not recommended for
this product at any stage short of a MAS mandate.

---

## Plan polish (applied to the plan in the same change set)

1. ~~Fix N1 wording~~ — plan already correct; assessment N1 corrected instead.
2. Resolve `ADR-00N` → `ADR-002`.
3. Add N2 (custom-home overrides) to Open questions / ADR inputs.
4. Risks table: Option-A-only rows marked conditional / retire when C is accepted.
5. Option C Issue A acceptance: discovery under `COPILOT_HOME`-style override outside defaults.
6. Approach / Phase 1B: provisional preferred decision = Option C; drop A-only machinery from
   default path once ADR accepted.
7. Option C entitlements steps made explicit (N5).

## Bottom line

The plan is well-structured and ready to execute. **Agree with Option C.** Next: Phase 0
diagnose, then ADR-002 accepting C with compensating controls; implement Phase 1B along the
Option C branch (real-home resolution + warnings + sandbox off + Hardened Runtime/notarization
docs); Issues B/C and Phase 2 as written.

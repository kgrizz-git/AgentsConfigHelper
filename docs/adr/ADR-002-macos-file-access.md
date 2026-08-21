# ADR-002: macOS file-access model (sandbox vs Developer ID)

Last reviewed: 2026-08-21
Date: 2026-08-21
Status: proposed
Deciders: maintainers
Related plan: [`plans/active/macos-execution-and-dependency-upgrades.md`](../../plans/active/macos-execution-and-dependency-upgrades.md)

## Context

AgentsConfigHelper is a local desktop app whose core loop is:

1. **Auto-discover** agent/IDE config and rules files under the user's real home
   (e.g. `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/Documents/Cline/Rules`, …).
2. **Scan user-added project roots** for project-scope configs
   (`.cursor/rules/`, `.github/copilot-instructions.md`, …).
3. **Accept manual absolute paths** typed or chosen by the user.
4. **Honor overrides** such as `COPILOT_HOME` (absolute paths outside default
   `~/.copilot`).
5. **Read, edit, and backup** those files (configs may contain tokens).

On macOS, Flutter's default template enables **App Sandbox**. Under the sandbox,
`$HOME` / `NSHomeDirectory()` resolve to the app container
(`~/Library/Containers/<bundle-id>/Data`), so discovery against the real home
finds nothing — and looks identical to "no tools installed."

This ADR records the durable options for fixing that, including what is
**build-time vs runtime**, so we do not re-litigate "just disable the sandbox"
vs "keep the sandbox" in every session.

Audience note (near-term): most users will **build from source**. Trusting that
source already implies trusting the process with local files; sandbox is then
defense-in-depth, not the primary trust boundary. Distribution of signed
binaries to third parties raises the stakes. Until a Developer ID certificate and
notarization pipeline exist, the project ships **source-build-only** and must not
distribute ad-hoc unsigned binaries claiming Option C compliance. Gatekeeper /
quarantine still applies to zips downloaded through a browser.

## Decision (proposed)

**Preferred near-term choice: Option C** — non-sandboxed macOS builds intended for
**Developer ID + Hardened Runtime + notarization** when distributing binaries,
with compensating controls listed under Consequences.

Until this ADR is flipped to `accepted`, do not change entitlements. Implement
real-home resolution (`getpwuid_r`) and container warnings either way.

**Acceptance of this ADR implies the compensating controls below are checklist-
complete (or explicitly deferred with owners)** — not merely aspirational.

**Revisit** if Mac App Store, enterprise sandbox mandates, or Apple trust-model
changes become real requirements.

---

## How macOS access actually works (shared vocabulary)

Three different mechanisms get confused under "Option A":

| Mechanism | When decided | Who can extend it | What it covers |
| --- | --- | --- | --- |
| **App Sandbox on/off** | Build / signing entitlements | Maintainers only (rebuild + re-sign) | Whether the process is confined at all |
| **Temporary exception paths** (`home-relative-path.*`) | **Hardcoded at build time** in `.entitlements` | **Not from the app.** Adding a new top-level dir requires a new build (and, for distributed apps, a new signed release) | Specific home-relative directories, e.g. `/.claude/`, `/.cursor/`, `/Documents/Cline/Rules/` (Apple requires leading `/` and trailing `/` for directories) |
| **User-selected access + security-scoped bookmarks** | **Runtime**, via Open/Save panel (or drag-drop) | **Users, from within the app** — grant persists across launches if bookmark data is stored | Arbitrary folders/files the user explicitly chooses (project roots, odd manual paths, custom homes) |

So for Option A specifically:

- You do **not** list every individual config *file* in entitlements. You list
  **top-level directories** that contain those files (catalog-derived).
- You do **not** put every project path in entitlements. Projects and one-off
  paths are granted **in-app** via Open panel + bookmarks.
- Users **cannot** widen the temporary-exception allow-list from Settings; they
  **can** add project roots / pick folders if bookmark UX is implemented.
- Custom env overrides (`COPILOT_HOME` pointing at `/Volumes/…` or another tree)
  still fail under A/B unless the user also grants that location via the panel
  (or you add another static exception and ship a new build).

---

## Options

### Option A — Sandbox + home-relative temporary exceptions + bookmarks for projects/manual paths

#### Option A sketch

- Keep `com.apple.security.app-sandbox`.
- Ship a **build-time** allow-list of home-relative dirs derived from
  `ToolDescriptorRegistry` / `docs/supported-tools.md` (including non-dot paths
  such as `/Documents/Cline/Rules/`).
- Implement **runtime** security-scoped bookmarks for project roots and manual
  paths (and optionally for custom-home directories).
- Resolve real home via `getpwuid_r` (env `$HOME` alone is insufficient).

| Pros | Cons |
| --- | --- |
| OS-enforced confinement: compromise cannot freely walk the whole disk | Temporary exceptions are Apple-discouraged / MAS-hostile; may be tightened later |
| Auto-discovery of known `~/…` tool dirs stays zero-friction | **Two systems** to build, test, document (exceptions + bookmarks) |
| Users can add **projects** in-app via Open panel (bookmarks) | Exception list is **hardcoded at build**; new tool dirs need a release |
| Stronger story if MAS or enterprise sandbox ever matter | Custom homes outside the allow-list still need a panel grant |
| Sync test can prevent catalog↔entitlements drift | Highest implementation cost of the viable options |

**Impractical?** Not if you commit to bookmarks. **Impractical as "exceptions only"**
(no bookmarks): project-root discovery and typed manual paths stay broken.
**Enumerating "every config file"?** No — enumerate top-level dirs. **Every
project?** No — those are runtime grants, not the plist.

### Option B — Sandbox + bookmarks everywhere (minimal/no temporary exceptions)

#### Option B sketch

- Keep sandbox.
- No (or almost no) temporary exceptions.
- First launch / settings: user Open-panels home tool dirs and each project root;
  persist bookmarks.

| Pros | Cons |
| --- | --- |
| Purest least-privilege; no discouraged entitlements | Breaks **automatic** first-launch discovery (core product promise) |
| One access model (bookmarks only) | Brutal UX for hidden dot-directories (`⌘⇧.`), per tool / per machine |
| Users extend access entirely from within the app | Bookmark rot / stale grants = permanent support burden |
| Works for arbitrary custom homes once granted | Highest abandonment risk for pre-1.0 |

**Impractical for this product** unless MAS forces it. Safer on paper; hostile to
"open the app and see your agents."

### Option C — Non-sandboxed Developer ID + Hardened Runtime + notarization (**preferred**)

#### Option C sketch

- **Delete** `com.apple.security.app-sandbox` from Debug and Release entitlements
  (prefer delete over `false`; keep Debug `allow-jit` + `network.server` for
  Flutter tooling only).
- Distribute (when ready) as Developer ID–signed, Hardened Runtime, notarized
  binaries — same class as VS Code, JetBrains IDEs, iTerm2.
- Still implement real-home resolution + container warnings as defense-in-depth.
- Rely on compensating controls (below), not OS filesystem jail.
- Choose a final non-`com.example` `PRODUCT_BUNDLE_IDENTIFIER` before signing;
  parameterize container-path heuristic and prefs migration by that id.

| Pros | Cons |
| --- | --- |
| Home dirs, projects, manual paths, `COPILOT_HOME` all work without grant UX | No OS FS confinement if the process is compromised |
| Matches peer local power-tools and source-builder expectations | Effectively rules out Mac App Store without a major rework |
| Deletes entire failure classes (exception drift, bookmarks, silent custom-home misses) | Enterprise environments that *require* sandbox may reject it |
| Least code; fastest for pre-1.0 | Trust shifts to signing + app safety practices |

**"Unsafe" for source builders?** Relative to "I already run this trusted source,"
mostly no. Sandbox is still useful defense-in-depth against dependency/parser
bugs; it is not the primary trust boundary for that audience. Stakes rise when
shipping prebuilt binaries to people who never read the source.

### Distribution channel vs “professional”

“Is Option A more professional / better for distribution?” depends on **channel**:

| Channel | More professional fit | Notes |
| --- | --- | --- |
| **Mac App Store** | Sandbox required → **A or B** | Temporary exceptions are review-hostile; **B** (bookmarks everywhere) or a *minimal* A is cleaner than a large exception list. **C is not MAS-viable.** |
| **Developer ID outside the store** (typical indie/desktop) | **C + Hardened Runtime + notarization** | Peer norm for local power-tools (VS Code, JetBrains, iTerm2). A is not “more professional” here; a hybrid exceptions+bookmarks stack can look less polished than a signed notarized unsandboxed tool. |
| **Build-from-source / local `flutter run`** | Either; trust is the source | Gatekeeper/notarization barely apply for local builds; sandbox is defense-in-depth. Downloaded zip artifacts still get quarantine. |

Sandbox is **not** a substitute for a signing/notarization story. Unsandboxed without Hardened Runtime + notarization when shipping binaries is unprofessional; **C with those controls is not.**

### Option D — Dual variants (sandboxed MAS build + unsandboxed Developer ID) — **rejected**

Doubles packaging, QA, entitlements, and support for no current demand. Revisit
only if MAS becomes real.

---

## Consequences (if Option C is accepted)

### Positive

- Discovery and edit/backup match the product's intended breadth of access.
- No bookmark stack or temporary-exception maintenance for v1.
- Local `flutter run` / build-from-source stays simple (Gatekeeper not in the way).

### Negative / tradeoffs

- Document and own: this is a **power tool** with full user-session FS access at
  the OS layer.
- Future MAS path requires revisiting this ADR (likely Option A or B). Re-enabling
  sandbox is mechanical; durable costs are grant UX and prefs/data relocation
  (not literally irreversible).
- Must not confuse "Option C" with "flip sandbox off and forget" — compensating
  controls are part of the decision.

### Compensating controls (required with Option C)

1. **Hardened Runtime (mechanized):** set `ENABLE_HARDENED_RUNTIME = YES` on the
   Release configuration (decide Debug posture explicitly). Ship only
   **notarized**, signed binaries when distributing outside source builds.
   Acceptance check: `codesign -d --entitlements :-` matches the expected set;
   debug-only CS entitlements (`com.apple.security.cs.allow-jit`) must not appear
   on notarized artifacts (DebugProfile only).
2. Keep **backup-before-write + diff preview** as the in-app safety story;
   document in README / architecture.
3. Keep **local-only** data classification: config tokens do not leave the
   machine; no config cloud sync in v1.
4. **Parser hardening:** fail-closed parsing plus robustness/fuzz tests for
   TOML/YAML/front-matter parsers that ingest project/config input (unsandboxed
   blast radius). Promote “confirm writes outside the discovered-config set”
   from optional to planned.
5. Prefer real-home resolution via `getpwuid_r` + warn on container-shaped homes
   even when unsandboxed (cheap; survives accidental re-enable of sandbox).
   Cover the real FFI path with a **macOS-host** equivalence test (not mocks
   alone); keep `struct passwd` layout in one tested place.
6. **Bundle ID prerequisite:** replace template `com.example.agentsConfigHelper`
   before Developer ID signing; parameterize container heuristic + prefs
   migration by the chosen id.
7. **Source-build-only** until cert + notarization pipeline exist; README notes
   Gatekeeper quarantine on downloaded zips.

### Prefs migration (decided)

**Do** a one-time best-effort copy from the old sandboxed Application Support
location (container path keyed by prior bundle id) into the new
`getApplicationSupportDirectory` location when the destination store is empty.
Covers `DiscoveryPreferencesStore` and any other prefs under
`lib/main.dart` / path_provider. Document old→new paths in the release note for
the entitlement flip. Skipping migration is rejected — it predictably drops
early Debug users’ saved paths.

---

## Alternatives summary

| Option | Build-time list? | User can extend in-app? | Auto-discover `~/…` tools? | Arbitrary projects? | Custom homes? | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| **A** | Yes — top-level home dirs in entitlements | Yes — projects/manual via bookmarks only | Yes (for listed dirs) | Yes (with bookmarks) | Only if granted or listed | Viable if confinement required |
| **B** | Minimal | Yes — everything via bookmarks | No (until user grants) | Yes | Yes after grant | Not for this product unless MAS |
| **C** | No FS allow-list | Optional (bookmarks as hardening only) | Yes | Yes | Yes | **Preferred near-term** |
| **D** | Both stacks | Depends on variant | Depends | Depends | Depends | Rejected |

---

## Follow-up triggers

Reopen this ADR if any of:

- Concrete Mac App Store or notarization-policy requirement for sandbox.
- Enterprise customer mandates sandboxed builds.
- Apple degrades trust in notarized non-sandboxed Developer ID apps.
- Users demand in-app "grant folder" UX even under C (can still offer bookmarks
  as optional hardening without turning sandbox on).

## Implementation notes (after `accepted`)

1. Phase 0 diagnose (confirm container `$HOME` on current Debug builds); record
   in the plan.
2. Flip this ADR to `accepted` only when Phase 1A mechanized-control checklist
   items are owned (Hardened Runtime setting, bundle ID, prefs migration,
   parser-hardening note).
3. Execute Option C branch in
   [`plans/active/macos-execution-and-dependency-upgrades.md`](../../plans/active/macos-execution-and-dependency-upgrades.md)
   Phase 1B as **1B-i** (resolver + warnings, sandbox intact) then **1B-ii**
   (entitlements delete + Hardened Runtime + migration).
4. Link from `ARCHITECTURE.md`, `.context/project-profile.md`, and a short note
   in `AGENTS.md`.

## References

- Apple: [App Sandbox Temporary Exception Entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)
  (home-relative paths: leading `/`, directories trailing `/`)
- `macos/Runner/DebugProfile.entitlements`, `Release.entitlements`
- `lib/services/home_directory_resolver.dart`, `lib/state/providers.dart`
- `lib/catalog/tool_descriptor_registry.dart`
- flutter/flutter#176850 (related macOS toolchain noise; not access-model —
  confirm the issue still resolves before treating Issue B as closed)

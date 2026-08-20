# Product Ideas: Making AgentsConfigHelper More Useful, Intuitive & Full-Featured

Last reviewed: 2026-08-20

> **Status:** Idea backlog — not yet committed to the roadmap.
> **Next step:** Review these ideas, pick a shortlist to implement, then write a
> detailed plan under `plans/active/` (see `TO_DO.md`).

This document collects concrete, creative ideas to improve AgentsConfigHelper. Each
idea is grounded in what the app already does (discovery, comment-preserving
structured/raw editing, backup-before-write, diff preview, History & Backups
restore) and the roadmap phases (7 Templates, 8 Visual Editing, 9 more tools).
They are deliberately varied in size: some are an afternoon of work, others are
multi-phase product bets. Nothing here is approved for implementation yet.

---

## A. Discoverability & Onboarding

### A1. First-run guided tour
A short, dismissible walkthrough (3–5 steps) shown on first launch: what the sidebar
is, how the diff-before-save works, where backups live, and "add a custom path."
Shown once, re-openable from Help. Greatly lowers the "what do I do now?" moment in
the current empty/loaded states.

### A2. Tool health dashboard / "home" tab
A landing screen summarizing your agent setup at a glance: which tools are installed,
whether their config files exist, last-edited time, and how many backups each has.
One click drills into any tool. Turns a flat file list into a personal status board.

### A3. "What is this?" inline explainers
Per-setting tooltips and info popovers drawn from `docs/supported-tools.md` data
(e.g., "Enables background bash without confirmation", "Scopes network access to
these hosts"). Even a one-line plain-language description per field makes opaque
permission JSON feel manageable for non-experts.

### A4. Smart discovery hints
When discovery finds *no* config for a tool that clearly exists (e.g., the binary is
on `PATH` but `~/.claude/` is absent), surface a friendly tip: "Claude Code looks
installed but we didn't find settings — want to create one?" Fills the gap between
"detected" and "configured."

### A5. Contextual "official docs" links per tool/setting
While editing a tool's config or tool-specific rules, surface a "Docs" affordance
that opens the relevant official documentation for that tool (e.g., Claude Code
settings reference, Cursor rules docs, Opencode config reference, Kilo
`kilo-config` guidance). Links should be scoped per `ToolDescriptor` so each tool
shows its own curated set, and ideally per-setting where the source format/field
maps to a known doc anchor.

**Link freshness is a must.** These URLs rot as vendors move docs, so the link table
must be verified automatically:
- Store the links in a single declarative source (e.g., a `tool_descriptor_registry`
  field or a `docs/tool_links.json` consumed by the app).
- Add a CI job (and/or a local script in `scripts/`) that checks each URL returns
  200/expected content on a schedule (e.g., weekly) and fails (or opens an issue/PR)
  when a link drifts or 404s. Reuse the repo's existing Python tooling conventions
  under `hooks/scripts/` / `scripts/`.
- Optionally pin a "last verified" date per link and show it in the UI tooltip
  ("verified 2026-08-20") so users know how fresh the pointer is.

This pairs naturally with A3 ("What is this?" inline explainers) — the explainer can
link out to the authoritative source.

---

## B. Editing Experience & Guidance

### B1. Visual permission builder (Phase 8 anchor)
Replace raw JSON editing for the most common, high-stakes fields (allow/deny command
lists, folder scopes, read-only vs read-write) with guided controls: a multi-select
of common safe commands, a folder picker with allow/deny toggle, and live
human-readable translation ("Allows: `git`, `npm test` • Denies writes outside
`src/`). Keeps the file format hidden but the power intact.

### B2. Safe-default suggestions
On edit, suggest secure defaults: prefer read-only over read-write, scope broad
globs to specific folders, warn on `**` or `sudo`. Offer a one-click "harden this
config" pass that proposes changes via the normal diff-preview flow.

### B3. Real line-level diff (upgrade current list diff)
The current diff is add/remove-at-list-level. Replace the raw-editor diff with a
true unified (Git-style) line diff, and let History compare an old backup against the
live file with the same engine. This is the single highest-leverage UX upgrade and
unblocks "selective merge" (B4/A7).

### B4. Selective merge from backup/template
Let users cherry-pick individual changed lines/keys from a backup or template into
the current file (rather than full restore). Directly serves the master-plan
"Git-style Merging & Diffing" backlog item.

### B5. Inline validation as you type
Live, format-aware validation in the raw editor: highlight JSON/YAML/TOML syntax
errors with line/column, and block Save (or warn) when the result won't parse. Pairs
with the planned Config Validation Service. Never silently ship a corrupted file.

### B6. Schema-aware field completion
For known tools, autocomplete keys and enumerate allowed values (e.g., `permissions`
modes, `model` names) with docs-on-hover. Reduces typos and guesswork in structured
configs.

### B7. Find / replace + jump-to-key
A `Cmd/Ctrl+F` in the editor that jumps to a key or value across the open file;
replace mode for bulk edits (e.g., renaming a model id everywhere). Small but daily
useful.

---

## C. Safety, Audit & Trust

### C1. Configuration audit / risk score
Scan the active config and flag risky patterns: over-broad command allowlists,
write access to system dirs, disabled permission prompts, embedded secrets. Show a
clear, color-coded risk summary with remediation suggestions — delivered through the
existing diff-preview (suggested = proposed edit) rather than a separate engine.

### C2. Secret detection before save
Before writing, scan the *resulting* file for likely secrets (API keys, bearer
tokens, `AWS_*`, private keys) and warn: "This change would write a secret to
`~/.cursor/permissions.json`. Continue?" Local-only, no redaction needed because
nothing leaves the machine — but it prevents accidental commits or careless edits.

### C3. Backup annotations & labels
Let users name/label backups ("before enabling auto-approve", "experiment for
project X") and add notes at save time. Makes the 10-snapshot History view
meaningful instead of a wall of timestamps.

### C4. Dry-run / "what would change" mode
A toggle that computes and shows the diff for an edit *without* touching the file or
creating a backup — for cautious exploration. Complements, but is distinct from, the
official diff-before-write.

### C5. Recovery-friendly corrupted-file flow
When a file fails to parse, offer more than "open raw editor": show the exact
line/column of the error, offer to open the last good backup side-by-side, and never
auto-overwrite. Builds on the Phase 6 recovery work already started.

---

## D. Templates, Reuse & Cross-Tool Power

### D1. Template library (Phase 7 anchor)
Save named, reusable config/rule snippets to `~/AgentsConfigHelper/` (user-configurable):
"Strict read-only", "Full autopilot", "Team baseline permissions". Load any template
straight into a live location, or save a live config as a new template. This is the
foundation Phase 7 describes.

### D2. Cross-tool translation
Convert a permission/rules intent from one tool's format to another (e.g., Claude
`permissions` → Cursor `permissions.json`, or `CLAUDE.md` guidance → `AGENTS.md`).
Maps divergent models onto a common intent so users maintain one mental model.

### D3. "Same setting, all tools" bulk view
Show a single setting (e.g., "allow background shell") across every tool you have,
and let you toggle it everywhere at once. Surfaces consistency gaps users didn't know
they had.

### D4. Shared rule snippets / "rule blocks"
Reusable Markdown rule fragments (e.g., "never commit secrets", "test before
merge") that can be injected into any instruction doc (`AGENTS.md`, `CLAUDE.md`,
`.mdc`). Versioned in the template library.

### D5. Environment-aware profiles
Group configs into profiles (Personal / Work / Client-X) and switch them in one
click, backing up the previous state first. Lightweight and local-only; no cloud sync.

---

## E. Smarter Discovery & Coverage

### E1. More tools & surfaces (Phase 9 anchor)
Continue the Phase 9 split: distinct Kilo, Cline, VS Code/GitHub Copilot, Cursor IDE
vs Cursor agent, and the Antigravity surfaces (IDE, desktop, `agy` CLI). Each new
tool = a `ToolDescriptor` + `docs/supported-tools.md` section.

### E2. Git repo–aware discovery
Scan the current Git repo for project-level configs (`.claude/settings.json`,
`kilo.jsonc`, `.github/copilot-instructions.md`) and show them grouped under the
repo, separate from global configs. Makes the app project-context aware.

### E3. Watch / live-reload
Detect external changes to an open file (another tool or editor modified it) and
prompt to reload, so the app never silently shows stale content. Cheap trust-builder.

### E4. Fuzzy search across all configs
A global search box that finds any key/value/rule across every discovered file and
jumps to it. Turns 13 tools × multiple files into one searchable surface.

---

## F. Polish, UX & Delight

### F1. Command palette
A `Cmd/Ctrl+K` palette for power users: jump to a tool, run an action (add path,
open history, toggle theme, save), search settings. Speeds up everything.

### F2. Light/dark/auto themes + per-OS feel
Already auto from OS; add an explicit toggle and platform-native chrome
(`macos_ui`/`fluent_ui` feel) so it reads as a first-class desktop app on each OS.

### F3. Keyboard-first navigation
Full keyboard routing: sidebar arrows, open, save (`Cmd+S`), discard, open history,
close. Accessibility + speed.

### F4. Export / print a config
Export the current (or a diff of) config as Markdown/PDF for sharing in a PR or
review — read-only, no secrets by default (pair with C2). Useful for team reviews.

### F5. Monospace + readable formatting options
Adjustable font size/zoom and a "pretty print preview" toggle for the raw editor so
long configs are easier on the eyes.

### F6. "Recently edited" and favorites
Pin favorite tools/configs to the top and show a recently-edited list so the most
used items are one click away.

### F7. Activity log
A local, always-on log of what the app changed (file, time, diff summary, backup
created) so users can answer "what did I do Tuesday?" without spelunking backups.

---

## G. Ecosystem (longer bets — see `plans/active/future_enhances.md`)

### G1. IDE extensions (VS Code / Cursor / JetBrains)
Manage configs from inside the editor; sync with the desktop template library. Large
surface, high convenience.

### G2. In-app AI assistant (opt-in, secret-safe)
Ask questions with your active config as context; generate safe rules from natural
language; audit configs for unsafe permissions. **Hard requirement:** redact secrets
and require explicit per-session consent before anything leaves the machine (per
`future_enhancements.md` and `TO_DO.md` AI-integration note).

---

## H. Modular Visual Editor (primary UX direction)

The headline product direction: make the default experience **modular and visual**
rather than raw JSON/YAML/TOML editing. The structured file is still the source of
truth, but users interact with it through logical, tool-agnostic modules they can
update, add, remove, and **reorder** — with the raw file available as a toggle or a
side-by-side pane. This generalizes and elevates the Phase 8 "Visual Editing" goal
(B1/B2/B6) into the core interaction model.

### H1. Tabbed/sectioned modules per config
Render each tool config as a set of purpose-built modules instead of a text blob:
- **Rules** — instruction/rule entries (reorderable, enable/disable, add/remove).
- **Permissions** — allow/deny command lists and folder scopes with guided controls.
- **Keys** — named key/value settings (e.g., `model`, `theme`, feature flags).
- **Settings** — tool preferences and toggles.
- **Models** — model selection, params, and provider entries.

Modules shown per tool are driven by the `ToolDescriptor` capability table, so a
tool that has no permissions model simply doesn't show that tab. Each item supports
add / edit / remove / **drag-to-reorder** (order matters for some rule/precedence
models).

### H2. Add / remove / reorder as first-class actions
Every module list supports inline add (with a sensible template/empty state),
removal with undo, and reordering (drag handles or move-up/down). Reordering writes
back in document order so the user's intent is preserved on disk — important because
some tools treat list order as precedence.

### H3. Raw file as a companion, not the default
Keep the existing raw editor, but reposition it as a secondary option:
- A "Raw" toggle within the same view, and/or
- A **split mode** showing the visual modules on one side and the live raw file on
  the other, kept in sync (edits on either side update the other, then go through the
  normal diff-before-write + backup flow).
This satisfies power users who want to see exactly what will be written, while
keeping casual users in the safe visual layer.

### H4. Live two-way sync between visual and raw
When split mode is on, edits in the visual module (e.g., toggling a permission)
immediately reflect in the raw pane and vice versa, using the existing
comment-preserving parsers. The diff preview (B3) then summarizes the net change
before save.

### H5. Module templates & quick-add presets
Per-module quick-add chips ("Add read-only folder", "Add deny: sudo", "Add rule:
never commit secrets") so common operations are one click, not a form. Pairs with D4
shared rule blocks and B2 safe-default suggestions.

### H6. Collapsible / focus mode
Let users hide modules they don't use and focus on one (e.g., only Permissions while
hardening). Persist the layout per tool.

---

## Product Commentary & Suggested Sequencing

The strongest product promise here is not merely “a nicer config editor.” It is a
**local, trustworthy translator between a user's intent and the exact files their
AI tools read**. Raw files and official documentation should remain one click away,
but the normal path should answer three questions without requiring format knowledge:
what does this setting do, where does it apply, and what exactly will change?

### A. Discoverability & Onboarding

**A1 — First-run guided tour:** Worth doing early, but make it task-led rather than
a generic feature tour. An empty-state choice such as “Review permissions,” “Add a
tool,” or “Open an existing config” is friendlier than pointing at the sidebar.
Never block the user, and make Help → Replay tour easy to find.

**A2 — Tool health dashboard / home tab:** This should become the default landing
surface after discovery. “Installed” must be carefully distinguished from “config
found,” “config valid,” and “last checked,” since binary detection can otherwise make
the app appear more certain than it is. It pairs especially well with E3 and C1.

**A3 — What is this? inline explainers:** High-leverage and foundational for a
visual editor. Use progressive disclosure: a one-sentence plain-English explanation,
an optional example, then a link to the relevant raw key and official documentation.
Keep wording focused on the consequence (“lets the agent …”), not the vendor schema.

**A4 — Smart discovery hints:** Useful when framed as an invitation rather than a
diagnosis. Creating a config should begin from a safe, documented starter preset and
show the target path, format, and resulting diff; never create a file merely because
a tool may be installed.

**A5 — Contextual official docs links:** Essential trust infrastructure. Prefer a
small curated registry with link labels, anchors, and a fallback tool-level landing
page. Automated freshness checks should tolerate rate limits and redirects, report
actionable failures, and avoid making normal app use depend on the network.

### B. Editing Experience & Guidance

**B1 — Visual permission builder:** The best Phase 8 starting point: permissions are
high-risk, repetitive, and poorly represented by raw lists. Start with a limited,
lossless subset for each tool, preserve unsupported entries verbatim, and always show
the generated configuration before save.

**B2 — Safe-default suggestions:** Strong differentiator if advice is explainable
and non-alarmist. Each suggestion should name the risk, describe the trade-off, and
offer a reversible diff; avoid presenting one universal policy as correct for every
user or repository.

**B3 — Real line-level diff:** A prerequisite for confident editing, recovery, and
review. Include both a semantic summary (“one command allowed”) and a raw unified
diff, because users need the former to understand intent and the latter to verify
fidelity. Treat comments, ordering, and line endings as first-class diff concerns.

**B4 — Selective merge from backup/template:** Valuable, but build it only after a
robust semantic/raw diff engine exists. The initial version should cherry-pick whole
structured fields or Markdown blocks, rather than attempting arbitrary line merging
that can create invalid JSON, YAML, or TOML.

**B5 — Inline validation as you type:** Table stakes for the raw escape hatch. Show
errors immediately but reserve Save blocking for definite parse failures; schema
warnings should explain uncertainty and let knowledgeable users proceed.

**B6 — Schema-aware field completion:** A natural second phase after structured
modules and explainers. Model names and vendor schemas change frequently, so mark
the source and verification date, allow custom values, and never let autocomplete
silently remove an unfamiliar but valid field.

**B7 — Find / replace + jump-to-key:** Small, dependable, and worth shipping early.
Search should cover raw text and the visual field labels, while replace needs a clear
scope (current field, file, or all open files) plus a preview and undo.

### C. Safety, Audit & Trust

**C1 — Configuration audit / risk score:** The audit itself is compelling; a single
numeric “risk score” can be misleading. Lead with understandable findings grouped by
severity and confidence, and use a score only as an optional summary. Make rules
tool-specific and explain that this is guidance, not a security guarantee.

**C2 — Secret detection before save:** A sensible guardrail, but users will expect
both false-positive control and privacy. Scan locally, report only the category and
location (not the secret value), let users suppress a finding for a known-safe case,
and make clear the app does not transmit the file.

**C3 — Backup annotations & labels:** A compact upgrade that makes the existing
backup feature feel intentional. Suggest a label based on the change summary, allow
freeform notes, and keep labels in app-managed metadata so the original config stays
untouched.

**C4 — Dry-run / what would change mode:** Conceptually this can be the normal
unsaved-edit state rather than a separate mode. Clearly distinguish “preview only”
from “Save will create a backup,” and ensure previewing never mutates metadata or
updates a file timestamp.

**C5 — Recovery-friendly corrupted-file flow:** A high-trust requirement. Pair the
line/column error with plain language, last-known-good comparison, copy-to-clipboard,
and an option to save a repaired copy elsewhere; keep destructive repair behind an
explicit choice.

### D. Templates, Reuse & Cross-Tool Power

**D1 — Template library:** A core feature once safe editing is established. Templates
need a manifest (name, description, compatible tools/formats, version, author/local
origin) and a preview so users never apply a mystery blob. Begin with local files and
export/import before considering sharing or sync.

**D2 — Cross-tool translation:** One of the most exciting ideas, but it must expose
lossiness. Translate through a small common intent model, show a capability mapping
(exact / approximate / unsupported), and require review; do not imply that two
vendors’ permission systems have identical semantics.

**D3 — Same setting, all tools bulk view:** This is the natural UI for the common
intent model, not a direct all-files toggle. Start read-only as a consistency matrix,
then add multi-edit transactions only when each target has a clear mapping and a
single combined diff/rollback story.

**D4 — Shared rule snippets / rule blocks:** Very practical and lower risk than full
translation. Give blocks a title, intent, variables (for example project name), and
clear insertion points; preserve a marker or metadata so updates can identify an
inserted block without overwriting nearby hand-written rules.

**D5 — Environment-aware profiles:** Powerful but potentially surprising when it
changes many live files. Treat a profile switch as a named, reviewable transaction
with an all-files diff, per-file opt-out, automatic backups, and an easy revert.

### E. Smarter Discovery & Coverage

**E1 — More tools & surfaces:** Coverage matters, but consistent quality matters
more. Add tools in vertical slices—discovery, accurate display, raw safety,
documentation, and only then visual modules—rather than creating a large list of
partially understood integrations.

**E2 — Git repo-aware discovery:** This may be the feature that makes the app feel
native to developer workflows. Make the active repository explicit, distinguish
global/project/inherited files, respect ignore rules and user-selected boundaries,
and never scan an entire drive by default.

**E3 — Watch / live-reload:** A must-have safeguard before two-way split editing.
When unsaved local edits conflict with an external change, offer a three-way compare
and choices to reload, keep draft, or merge; never discard either side automatically.

**E4 — Fuzzy search across all configs:** High daily value once users have several
tools. Results should show the exact file, scope, matched setting in plain language,
and whether the value is effective or overridden—not merely a text hit.

### F. Polish, UX & Delight

**F1 — Command palette:** Excellent after the app has enough actions to justify it.
Keep it discoverable through visible menu equivalents and let it search tools,
settings, documentation, and actions in a single place.

**F2 — Light/dark/auto themes + per-OS feel:** Important polish, but favor a shared,
accessible design system over aggressively mimicking each platform. Respect system
settings, high contrast, and reduced motion before adding platform-specific chrome.

**F3 — Keyboard-first navigation:** This should be built alongside every feature,
not saved for polish. Define focus order, visible focus indicators, shortcuts, and
screen-reader labels as acceptance criteria for all new views.

**F4 — Export / print a config:** More useful as an “export review” feature than a
literal print feature: generate a Markdown report containing scope, explanations,
semantic/raw diff, and redacted sensitive values. Keep PDF optional to avoid making
the core workflow depend on platform printing quirks.

**F5 — Monospace + readable formatting options:** Low effort, high comfort. Add zoom,
wrapping, whitespace visibility, and format-on-preview while preserving the actual
on-disk formatting unless the user explicitly elects to normalize it.

**F6 — Recently edited and favorites:** A simple navigation win. Store recents
locally, make pinning explicit, and show enough path/scope context that similarly
named configs are not confused.

**F7 — Activity log:** This completes the trust story with backups and diff preview.
Record only local operational metadata and redacted change summaries, include a link
to the backup/diff, and provide retention and clear-history controls.

### G. Ecosystem

**G1 — IDE extensions:** Defer until the desktop information architecture and template
format are stable. An extension should initially deep-link into the desktop app or
share a thin local library, avoiding a second divergent editing implementation.

**G2 — In-app AI assistant:** Valuable only if its privacy controls are exceptional.
Make the offline/manual workflow fully useful first; for any remote assistant, show
the exact context leaving the machine, redact by default, make consent granular, and
offer a no-network mode that is easy to verify.

### H. Modular Visual Editor

**H1 — Tabbed/sectioned modules per config:** This is the right primary direction,
provided it is schema- and capability-driven rather than a hand-built UI for each
file. The module list should also contain an “Unrecognized fields” section, ensuring
the visual layer never hides or destroys information it does not understand.

**H2 — Add / remove / reorder as first-class actions:** Correctly treats ordering as
meaningful. Use undo, keyboard move controls as well as drag-and-drop, and confirm
the target format preserves order; a visual reorder must never create a noisy,
unrelated reformat of the file.

**H3 — Raw file as a companion, not the default:** This is the key user-experience
balance. Put “View source” and “Open in external editor” within reach, and make the
raw view truthful about comments or fields that a structured module cannot round-trip.

**H4 — Live two-way sync between visual and raw:** Aspirational and technically the
riskiest item in this section. Ship one-way visual-to-preview plus raw-to-reload
first; introduce live two-way sync only after conflict handling, parser fidelity,
undo semantics, and performance are proven across every supported format.

**H5 — Module templates & quick-add presets:** A welcoming way to turn expertise
into clicks. Every preset should state what it adds, why someone might choose it,
what it does *not* protect, and the exact raw representation before application.

**H6 — Collapsible / focus mode:** Nice, but should follow good default information
hierarchy rather than compensate for clutter. Persist local preferences, retain an
easy “reset layout,” and never hide validation errors just because their module is
collapsed.

---

## I. Additional Ideas: Intent, Context & Confidence

### I1. Plain-language intent composer
Offer a “Tell us what you want” entry point with focused choices such as “let the
agent run tests,” “keep it inside this project,” or “require confirmation for network
access.” The app proposes the applicable visual fields and raw changes, then asks the
user to review. This is a translator, not an opaque chatbot: every proposed change
must remain inspectable, editable, and reversible.

### I2. Scope and precedence map
Show a small visual map of global, project, workspace, and rule files that affect the
selected tool. Mark the currently effective setting and explain when a nearer file
overrides a global one. This directly removes a common raw-config frustration: users
often edit a valid file that simply is not the file their tool is using.

### I3. “Why is this effective?” inspector
For any visible setting, show its raw source path, the parsed value, its precedence,
related overrides, and a link to the official rule. Where exact precedence is not
known, say so plainly. This turns debugging a configuration into an understandable
inspection flow instead of web searching.

### I4. Setup recipes
Provide guided, editable recipes for common outcomes: a cautious personal setup, a
team review workflow, a read-only documentation agent, or a project with tightly
scoped write access. Recipes should use templates/presets, explain their trade-offs,
and end in the standard all-changes diff rather than performing a magic setup.

### I5. Configuration doctor
Run a local diagnostic that checks parse validity, unknown/deprecated keys where
known, missing referenced paths, conflicting allow/deny entries, and discovery
ambiguities. Results should be categorized as error, warning, or informational and
link directly to a fix or explanation—never turn uncertainty into a failure.

### I6. Effective-config sandbox
Let users experiment with a draft configuration and see a simulated effective view:
which rules apply, what scopes are granted, and which config wins by precedence.
Clearly label it as a best-effort interpretation unless the vendor formally defines
all semantics. This is especially useful before changing several global/project files.

### I7. Multi-file change sets
When an action touches more than one config, group it into a named change set with a
single review screen, per-file toggles, atomic-write handling where practical,
backups for every file, and a one-action revert. It makes D3 and D5 safe enough to
feel friendly rather than frightening.

### I8. Project switcher and recent workspaces
Let users add local repositories to a compact workspace list and switch the sidebar
between them. Show project-level configs, recent changes, health findings, and the
active Git branch without needing broad automatic filesystem scans.

### I9. Built-in examples and glossary
Add a searchable, offline mini-reference that defines terms such as “allowlist,”
“glob,” “workspace,” and “inheritance,” with tiny before/after examples for each
supported format. Pair every concept with a “show me in this config” action, reducing
the need to leave the app just to decode vendor vocabulary.

### I10. Change confidence checklist
Before save, summarize a human-sized checklist: files affected, validation result,
high-risk permissions, preserved unknown fields/comments, backup destination, and
whether the official docs link is current. This is a calmer, more useful final gate
than a generic confirmation dialog.

### I11. Accessible comparison modes
Offer more than red/green diff colors: side-by-side and unified layouts, icons and
words for additions/removals, adjustable contrast and font size, keyboard navigation,
and a prose change summary. This improves both accessibility and reviewability for
everyone.

### I12. User feedback loop for unsupported configs
When the app encounters a safe-to-share structural feature it cannot visualize, let
the user save a local note or generate a redacted diagnostic summary for a future bug
report. The immediate UI should preserve that field under “Unrecognized fields,”
which keeps the app honest and helps prioritize coverage without collecting configs
silently.

### Recommended initial product slice

To make a visible shift away from raw-file editing without taking on the full risk of
two-way synchronization, prioritize **A2, A3, B3, B5, B7, C5, E3, H1, H3, I2, and
I10**. That slice gives users a friendly home, plain-language explanations, a
validated visual view, transparent source access, conflict safety, precedence
context, and an understandable final review. Follow it with B1/B2 and C1 once the
underlying structured representation has proved lossless for the supported tools.

---

## How to use this list

1. Review and star the ideas that fit the product vision (most are independent).
2. Cluster a few into a shortlist and write a plan under `plans/active/`
   (reuse the existing phase-plan format, e.g. `phase_3_design.md`).
3. Keep this file as the living idea backlog; move adopted ideas into their plan and
   mark them done in `TO_DO.md` once shipped.

Cross-references:
- Phase 7 Templates → D1, D2, D4, H5
- Phase 8 Visual Editing → B1, B2, B6, **H1–H6 (primary UX direction)**
- Phase 9 Tools/Markdown → E1, E2
- Master-plan backlog "Git-style Merging & Diffing" → B3, B4
- `future_enhancements.md` (IDE/AI) → G1, G2

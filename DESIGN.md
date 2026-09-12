# Design: AgentsConfigHelper UI & Data Model

Last reviewed: 2026-09-10
Status: living doc — update with the code, not after it.
Supersedes: the 2026-08-11 draft (placeholders never filled).

Visual language (colors, type, badges, shape) lives in
[`docs/DESIGN_LANGUAGE.md`](docs/DESIGN_LANGUAGE.md). Service layers and
data flow live in [`ARCHITECTURE.md`](ARCHITECTURE.md). This file records
the UI structure, the editor model, and the data-model shape.

## UI structure

- `MainShell` (`lib/screens/main_shell.dart`) is a two-pane
  `MultiSplitView`: a sidebar list of discovered configs plus manual paths
  on the left, a `ConfigEditor` for the active selection on the right.
  Selection is `_activeConfigId`; a dedicated `_showingOverview` flag
  (planned — does not exist in code yet) will host the Overview report
  screen (see `plans/archive/config-overview-report.md`) without
  overloading selection.
- Sidebar header hosts global actions (add path, manage project roots)
  behind a `+` popup menu.
- `ConfigEditor` renders, per config: a structured policy card when the
  tool has a schema adapter (Claude, Cursor, Opencode, Codex), otherwise
  the raw text editor — raw-first fallback is the rule, never a dead end.
- Overlays: add-path dialog, history/backups modal with timestamped
  restore, review-and-confirm save flow with diff preview
  (`StructuredSaveFlow`), fidelity and TOML opt-in banners where the
  parser cannot round-trip losslessly.

## Editor model

1. Structured cards edit typed fields; every save goes through diff
   preview → explicit confirm → backup-before-write to centralized
   `<appSupport>/backups` (10 newest snapshots per path, older pruned
   best-effort) → overwrite.
2. `JSON`/`JSONC` and `YAML` attempt source-preserving updates; a full
   rewrite requires explicit per-save opt-in. TOML structured editing is
   opt-in (off by default) and always rebuilds from its parsed map.
3. The raw editor is always available and is the only editor for
   unclassified files.

## Data model

- `ToolConfig`: one discovered file — path, format, `rawSettings`
  (`Map<String, Object?>`), `originalContent` for fidelity comparison.
- `DiscoveredConfig`: discovery result (tool id, scope, path, format).
- `ToolDescriptor` / `ConfigTarget` catalog: known tools, their managed
  paths, formats, and schema-adapter bindings. Manual paths group under
  `Other` wherever listings are grouped by tool.
- Parsers are pure functions (`lib/parsers/`); business logic lives in
  services/models, never in widgets beyond service orchestration.

## Key decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Backup location | Centralized `<appSupport>/backups`, not alongside originals | Keeps user config dirs clean; single restore source |
| Unknown files | Raw editor, never blocked | Fidelity first; classification is progressive |
| TOML structured editing | Opt-in, rebuild semantics disclosed | `toml` package cannot round-trip source |
| macOS distribution | Unsandboxed source builds only | Discovery needs real home-dir access; see ADR-002 |
| Overview report | Generated snapshot (HTML+MD), metadata-only | No live watching; paths listed, values never embedded |

## Open questions

- [ ] App-level light theme: the app is dark-only; `DESIGN_LANGUAGE.md`
  defines light tokens for the HTML export only. Promote to a full app
  light theme or keep dark-only — deferred past 0.2.0.
- [ ] `ARCHITECTURE.md` (last reviewed 2026-08-17) predates the Overview
  surface: update its data-flow section when the report screen lands.

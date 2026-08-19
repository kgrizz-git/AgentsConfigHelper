# Master Plan: AgentsConfigHelper

Status: active
Created: 2026-08-11
Profile: `.context/project-profile.md`

## Goal

Build a cross-platform desktop application to visualize, edit, and manage configuration settings and rules for AI agents and IDEs. (Original goal included "sync" — deferred: moved to Phase 7 Templates & Syncing; V1 is local-only, no networking.)

---

## Phase 1: Core Domain & Parsers (Pure Dart)

**Goal:** Define the data models and build the parsers.

* Design the unified `ToolConfig` model.
* Implement format-specific parsers (`JSON`, `YAML`, `TOML`, `Markdown`).
* Write comprehensive unit tests against synthetic fixtures.
* **Detailed Plan:** *[Link to be created]*

## Phase 2: Services & Discovery

**Goal:** Find the configs and handle safe file I/O.

* Implement `DiscoveryService` to scan standard OS directories and project folders.
* Implement `BackupService` to handle `.bak` creation and restore functionality. (Implemented as app-support-dir backups via BackupService, not alongside originals.)
* Integrate CLI hooks for agents that expose configuration commands. (Deferred: moved to Phase 7 Templates & Syncing; V1 is local-only, no networking.)
* **Detailed Plan:** *[Link to be created]*

## Phase 2.5: Advanced Parsers (JSONC)

**Goal:** Safely parse and write JSONC (JSON with Comments) without losing user annotations.

* Evaluate and integrate a comment-preserving JSONC parser.
* Implement `JsoncConfigParser` supporting `.jsonc` and Opencode configurations.
* **Detailed Plan:** `plans/active/phase_2.5_jsonc.md`

## Phase 3: UI/UX Design System & Prototyping

**Goal:** Define the visual language, typography, and aesthetic layout of the application to ensure a premium, modern feel.

* Establish color palettes, typography, and spacing (Design Tokens).
* Mockup the core layout (Sidebar, main content area, empty states).
* Choose a component library strategy (e.g., custom Material 3, or a native-feeling desktop library like `macos_ui` / `fluent_ui`).
* Prototype micro-interactions (hover states, diff transitions).
* **Detailed Plan:** `plans/active/phase_3_design.md`

## Phase 4: Application State & UI Shell

**Goal:** Scaffold the visual application framework based on Phase 3.

* Choose and implement state management (e.g., Riverpod, Provider, or Bloc).
* Build the main application shell (Sidebar for tools, main editor area).
* Set up dark/light theme switching based on the OS.
* **Detailed Plan:** *[Link to be created]*

> **Update (PR #5):** Phase 4's two concrete pieces are done:
>
> 1. **`DiscoveryService` wired into the shell.** `main_shell.dart` no longer hardcodes sidebar entries; the sidebar is Riverpod-provided from `DiscoveryService.discoverConfigs()` plus user-added paths (`lib/state/providers.dart`).
> 2. **State management (Riverpod) is in place.** `lib/state/providers.dart` supplies `DiscoveryProvider`/config providers consumed by the shell and editors.
>
> The "Detection priority" list in `docs/supported-tools.md` and `DiscoveryService.defaultRelativePaths` have been reconciled into a declarative `ToolDescriptor` table (`lib/catalog/tool_descriptor_registry.dart`).

## Phase 5: Editors & Diff Viewers

**Goal:** Allow users to actually edit and save configurations safely.

* Build generic key-value editor widgets.
* Build specialized toggle/form widgets based on the tool.
* Implement a Diff Viewer widget to preview changes before confirming a save.
* **Detailed Plan:** *[Link to be created]*

> **Update (PR #5):** Both editor features are shipped:
>
> * **History & Backups view** — implemented as `lib/widgets/history_modal.dart`, backed by `BackupService` (centralized `.bak` store in app support dir, restore support).
> * **Raw text editor fallback** — implemented in `lib/widgets/config_editor.dart`, replacing the former "coming soon" placeholder.
>
> **Still deferred:** the diff modal (`ConfigEditor._buildDiffSection`) remains a list-level add/remove view; upgrading it to a true line-level diff for the raw editor and History/Backups comparison is tracked under the master-plan backlog "Git-style Merging & Diffing."

## Phase 5.5: Documentation Accuracy & Polish

> **Status:** Complete (2026-08-17). Plan archived at `plans/archive/phase_5.5_docs.md`.

**Goal:** Bring the user-facing and contributor docs in line with the shipped codebase, and
raise the README's professionalism so the project reads like a credible OSS desktop app.

**Why now:** The first independent doc audit (`tmp/docs-accuracy-assessment-2026-08-15T1335.md`)
found the architecture and safety claims largely hold up, but several README/ARCHITECTURE
statements are inaccurate and one is security-relevant. Most are concentrated in feature-scope
overreach and the backup-location note. Fixing these is low-risk, high-trust, and unblocks the
Phase 6 release narrative.

* Correct README feature-scope overreach: remove the "sync" capability claim (not implemented; no networking in `lib/`), and reword "undo mechanisms" to the actual backup-restore behavior.
* Rewrite the Data Privacy / backup note so it states the **true** backup location (centralized app-support `backups/` dir, not alongside originals), discloses that backups accumulate without auto-pruning, and that filenames encode original absolute paths. Add where/how to purge. (Shipped: retention/pruning subsequently landed — `BackupService.maxBackupsPerPath = 10`, `_pruneOldBackups` — so the shipped README documents retention (10 snapshots per path, pruned best-effort) instead.)
* Fix the structured-vs-instruction-document distinction: Markdown/text are raw passthrough, not "native" like JSON/JSONC/YAML/TOML.
* Sync the README supported-tool list to `ToolDescriptorRegistry` (9 tools; currently lists 8 and omits `agy-acp`); consider a drift test that asserts every `ToolDescriptorRegistry` display name appears in `docs/supported-tools.md` (names as source of truth, catching substitutions and omissions — not a count-only check).
* Mark the "CLI Integration Service" in `ARCHITECTURE.md` as `(planned)` — no such service exists.
* Resolve the `CHANGELOG.md` version conflict (says `0.4.4` template history; app is `0.1.0`); reset to an app changelog.
* Rewrite `docs/NAVIGATION.md` to drop the inherited "this template" scaffolding framing.
* Add a `LICENSE` file and License section; add a screenshot, status/CI badges, and a "Project status: early development" line to README.
* Document the vendored `lib/vendor/json_ast/` (origin, license, rationale) and clarify it is vendored, not a pub dependency.
* Add a `Last reviewed:` line to README (matching AGENTS.md/ARCHITECTURE.md/`docs/supported-tools.md`).
* **Detailed Plan:** `plans/archive/phase_5.5_docs.md`

> **Note:** The Master Plan itself also contains stale "sync" language (Goal line, Phase 2 "Integrate CLI hooks", Phase 2 "`.bak` creation") that this phase should reconcile while editing the docs.

## Phase 6: Polish, Error Handling & Build Readiness

**Goal:** Get it ready for a local build.

* Handle corrupted configs and parsing errors gracefully.
* Finalize macOS, Windows, and Linux build settings (icons and permissions).
* Draft user release notes.
* Fold in manual-path removal bug fix from TO_DO.md (Qodo #10).
* **Detailed Plan:** `plans/active/phase_6_build_readiness.md` (In progress; supersedes the stub below).

> **Suggestion (2026-08-13):** Current parse-error handling is a single generic error string in `main_shell.dart`. Phase 6 should define per-format recovery (offer raw-editor open, show line/col of syntax error, never auto-overwrite a corrupted file) and formalize the JSONC fallback-warning path described in `phase_2.5_jsonc.md`.
>
> **Update (2026-08-18):** The 2026-08-13 premise is partly stale — `lib/screens/main_shell.dart` (not repo-root `main_shell.dart`) already surfaces parse errors via `on Object catch` in three places. The detailed plan (`phase_6_build_readiness.md`) re-baselines the goal to per-format recovery, position-accurate diagnostics, and the JSONC fallback-warning path, and folds in two deferred `TO_DO.md` bug fixes: manual-path removal (Qodo #10) and extracting config persistence out of the widget layer (Qodo architecture finding).

## Phase 7: Templates & Intelligent Merging

**Goal:** Allow users to save, load, and selectively merge configuration templates, moving beyond automated backups to intentional preset management.

* **Structured Template Library:** Allow saving templates for various configs and agent instructions in a structured folder (defaulting to `~/AgentsConfigHelper/` but configurable by the user).
* **Live Location Syncing:** Allow loading templates from the library directly to live agent locations, and saving live locations back to the template library.
* **Semantic Parsing & Granular Copying:** Interpret and parse the configs so the user can visually choose to copy a specific setting or rule from one config/template to another, rather than copying the entire file.

## Phase 8: Visual Editing & Rule Guidance

**Goal:** Move away from raw JSON/YAML editing to an intuitive, visual, and guided experience that helps users write safe and effective agent rules.

* **Visual Editor:** Make the app more intuitive and visual, abstracting away the underlying file formats (JSON, YAML, etc.) with rich UI controls (toggles, dropdowns, specialized rule builders).
* **Rule Guidance & Safety:** Provide active guidance to help users write or interpret rules, including:
  * Suggesting safe defaults and best practices.
  * Providing guidance on common read-only commands.
  * Offering templates or wizards for allowing/restricting commands within specific folders or workspaces.

## Phase 9: Deferred Tools & Markdown/Starlark Sources

**Goal:** Extend discovery and editing beyond the V1 structured-config set (JSON/JSONC, TOML, YAML) to the deferred sources and tools currently excluded from auto-discovery.

* **Raw-text editor:** Shipped in Phase 5 as the raw-editor fallback (`ConfigEditor` "Advanced" raw-content editor + `ConfigService.saveRawConfig`), so it is no longer a Phase 9 prerequisite. Phase 9 builds discovery/parsing/validation/tool support for the deferred Markdown/Starlark/plain-text sources on top of that shipped editor.
* **Markdown rules discovery:** Surface `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, Kiro steering, Cursor `.mdc`, Codex `.rules`, Devin `.devin/rules/*.md` in the sidebar (per `docs/supported-tools.md` "Deferred Sources").
* **Starlark & plain text:** Support Codex `.rules` (Starlark) and deprecated Cursor `.cursorrules` (plain text) via the raw editor.
* **VS Code / GitHub Copilot:** Add as a first-class supported tool. Instructions are `.github/copilot-instructions.md` (Markdown); no permission model. Add a `ToolDescriptor` entry and a section in `docs/supported-tools.md` (already stubbed there as deferred).
* **Additional deferred tools (from 2026-08-16 review):** the catalog currently has 9 entries and omits several requested tools, and folds some multi-surface products into one entry. Add/separate as follows:
  * **Kilo** — no `ToolId` or `docs/supported-tools.md` section today; add descriptor + config paths.
  * **Cline** — not supported at all; add `ToolId` + config paths.
  * **Cursor agent vs Cursor IDE** — the single `cursor` entry mixes agent permissions (`~/.cursor/permissions.json`) with IDE instruction files (`.cursorrules`, `.cursor/rules/*.mdc`); model the IDE-level editor `settings.json` as a separate entry (e.g., `cursorIde`) so agent and IDE configs are discoverable distinctly.
  * **Antigravity surfaces** — the `antigravity` entry today only covers the CLI config (`.gemini/antigravity-cli/settings.json`); add distinct descriptors/config for the **Antigravity IDE**, the **Antigravity desktop app**, and the **`agy` CLI** settings. (`agyAcp` already models the ACP session bridge separately and should stay distinct.)
* **Parser registry reconciliation:** Ensure `lib/catalog/tool_descriptor_registry.dart` and `DiscoveryService.defaultRelativePaths` reflect all supported tools (target set grows past 10 once Kilo, Cline, the Cursor IDE split, and the Antigravity-surface splits are added) plus deferred sources.

> **Note:** See `docs/supported-tools.md` "Deferred / not yet supported" for the authoritative list of excluded sources. The Phase 1 Markdown parser (line 18) anticipated this; Phase 9 closes the gap.

## Backlog & Future Enhancements

**Goal:** Track future feature requests that are currently deferred.

* **User Config Presets:** (Superseded by Phase 7 Templates).
* **Git-style Merging & Diffing:** Show a rich diff (like Git) between the current configuration file and a saved preset/backup. Allow users to selectively merge changes from the current file into the saved preset.

> **Note:** For long-term vision, broader ecosystem ideas (like IDE extensions and integrated AI assistants), please see [`future_enhancements.md`](future_enhancements.md).

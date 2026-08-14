# Master Plan: AgentsConfigHelper

Status: active
Created: 2026-08-11
Profile: `.context/project-profile.md`

## Goal

Build a cross-platform desktop application to visualize, edit, sync, and manage configuration settings and rules for AI agents and IDEs.

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
* Implement `BackupService` to handle `.bak` creation and restore functionality.
* Integrate CLI hooks for agents that expose configuration commands.
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

> **Suggestion (2026-08-13):** Phase 4 is the highest-leverage next step. Two concrete, well-scoped pieces:
>
> 1. **Wire `DiscoveryService` into the shell.** `main_shell.dart` currently hardcodes two sidebar entries; replace with a Riverpod-provided list from `DiscoveryService.discoverConfigs()` plus user-added paths. This turns the hardcoded demo into the real app.
> 2. **Add state management (Riverpod).** Everything is currently local widget state, which blocks scaling to a discovery-driven UI. Introduce a `DiscoveryProvider`/`ConfigProvider` before building History/Backups or the raw editor.
>
> Reconcile the "Detection priority" list in `docs/supported-tools.md` and `DiscoveryService.defaultRelativePaths` into one declarative `ToolDescriptor` table (see notes in `agent-config-discovery.md`).

## Phase 5: Editors & Diff Viewers

**Goal:** Allow users to actually edit and save configurations safely.

* Build generic key-value editor widgets.
* Build specialized toggle/form widgets based on the tool.
* Implement a Diff Viewer widget to preview changes before confirming a save.
* **Detailed Plan:** *[Link to be created]*

> **Suggestion (2026-08-13):** Two editor features are already stubbed in the shipped `ConfigEditor` and should be promoted to real work items:
>
> * **History & Backups view** — the "History & Backups" button currently shows a "coming soon" snackbar, but `BackupService` (centralized `.bak` store in app support dir, restore support) is already built. This is high-value, low-risk, and should be done right after Phase 4 wiring.
> * **Raw text editor fallback** — the "Raw JSON/YAML Editor Coming Soon" panel. Needed so the many `rawSettings` fields (models, env, nested permissions) that `ToolConfig` does not normalize are still user-editable without redesigning the model.
>
> The existing diff modal (`ConfigEditor._buildDiffSection`) is a list-level add/remove view; consider upgrading it to a true line-level diff for the raw editor and for the History/Backups comparison (ties into the master-plan backlog "Git-style Merging & Diffing").

## Phase 6: Polish, Error Handling & Release

**Goal:** Get it ready for a local machine release.

* Handle corrupted configs and parsing errors gracefully.
* Finalize macOS, Windows, and Linux build settings (icons, permissions).
* Draft user release notes.
* **Detailed Plan:** *[Link to be created]*

> **Suggestion (2026-08-13):** Current parse-error handling is a single generic error string in `main_shell.dart`. Phase 6 should define per-format recovery (offer raw-editor open, show line/col of syntax error, never auto-overwrite a corrupted file) and formalize the JSONC fallback-warning path described in `phase_2.5_jsonc.md`.

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

## Backlog & Future Enhancements

**Goal:** Track future feature requests that are currently deferred.

* **User Config Presets:** (Superseded by Phase 7 Templates).
* **Git-style Merging & Diffing:** Show a rich diff (like Git) between the current configuration file and a saved preset/backup. Allow users to selectively merge changes from the current file into the saved preset.

> **Note:** For long-term vision, broader ecosystem ideas (like IDE extensions and integrated AI assistants), please see [`future_enhancements.md`](future_enhancements.md).

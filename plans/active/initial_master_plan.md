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

## Phase 3: UI/UX Design System & Prototyping

**Goal:** Define the visual language, typography, and aesthetic layout of the application to ensure a premium, modern feel.

* Establish color palettes, typography, and spacing (Design Tokens).
* Mockup the core layout (Sidebar, main content area, empty states).
* Choose a component library strategy (e.g., custom Material 3, or a native-feeling desktop library like `macos_ui` / `fluent_ui`).
* Prototype micro-interactions (hover states, diff transitions).
* **Detailed Plan:** *[Link to be created]*

## Phase 4: Application State & UI Shell

**Goal:** Scaffold the visual application framework based on Phase 3.

* Choose and implement state management (e.g., Riverpod, Provider, or Bloc).
* Build the main application shell (Sidebar for tools, main editor area).
* Set up dark/light theme switching based on the OS.
* **Detailed Plan:** *[Link to be created]*

## Phase 5: Editors & Diff Viewers

**Goal:** Allow users to actually edit and save configurations safely.

* Build generic key-value editor widgets.
* Build specialized toggle/form widgets based on the tool.
* Implement a Diff Viewer widget to preview changes before confirming a save.
* **Detailed Plan:** *[Link to be created]*

## Phase 6: Polish, Error Handling & Release

**Goal:** Get it ready for a local machine release.

* Handle corrupted configs and parsing errors gracefully.
* Finalize macOS, Windows, and Linux build settings (icons, permissions).
* Draft user release notes.
* **Detailed Plan:** *[Link to be created]*

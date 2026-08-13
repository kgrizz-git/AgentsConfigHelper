# System Architecture

Last reviewed: 2026-08-11

## Overview

AgentsConfigHelper is a local-only, cross-platform Flutter desktop app. It abstracts the configuration files of multiple AI agent systems into a unified `ToolConfig` model.

## Core Layers

1. **UI Layer (Flutter Widgets)**
   - Displays a list of discovered tools.
   - Provides a settings editor (forms, toggles) customized based on the tool's capabilities.
   - Shows diffs and prompts for confirmation before applying changes.

2. **Service Layer**
   - **Discovery Service**: Scans the user's system on start up (standard OS directories and project folders) to discover agents and IDs to configure. It also provides the ability for users to manually add custom configuration paths.
   - **Config Validation Service (planned)**: Will perform strict format verification and schema validation before saving, preventing corrupted or malformed settings.
   - **Backup & Restore Service**: Responsible for copying the original file to a `.bak` or app-data folder before writes are executed. Handles rollbacks.
   - **CLI Integration Service**: Interfaces with agent CLIs (e.g., `claude config`, `opencode set`) when file-based edits aren't sufficient.

3. **Parser / Domain Layer**
   - Pure Dart functions that handle format-specific parsing and serialization.
   - Formats handled: `JSON`, `JSONC`, `YAML`, `TOML`.
   - **Comment Preservation:** `JSONC` and `YAML` parsers utilize AST-based string patching (`json_ast`, `yaml_edit`) to mutate specific values in the raw text, guaranteeing that user comments, trailing commas, and formatting are completely preserved when saving.
   - Normalizes disparate schemas into a single `ToolConfig` entity.

## Data Flow (Read/Write)

1. **Read**: Discovery Service locates file -> Parser parses format -> UI renders `ToolConfig`.
2. **Write**: UI edits `ToolConfig` -> Parser serializes format -> Backup Service saves original -> File is overwritten.

## Security & Constraints

- **No Cloud Sync**: Version 1 has no networking component for config data.
- **Tokens in memory only**: The app parses files containing API keys, but does not cache them beyond application memory.
- **Stateless Parsers**: Parsers must be pure, testable functions with no side effects.

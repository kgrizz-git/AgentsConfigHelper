# Design: AgentsConfigHelper UI & Data Model

Last reviewed: 2026-08-11
Author: Antigravity
Status: draft
Supersedes: n/a

---

## Problem

Different AI tools (Claude, Cursor, Opencode, etc.) scatter their configuration across various files and formats. Developers need a unified way to visualize, edit, and back up these configurations safely.

## Requirements

### Must have
- Abstracted unified configuration model.
- Safe backup-before-write functionality.
- Support for JSON, YAML, TOML, and Markdown.

### Nice to have
- Syntax highlighting for raw config editing.
- Integration directly with tool CLIs.

### Non-requirements
- Cloud sync / remote backup.

## Proposed design

*(To be filled out during the UI prototyping phase)*

### Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| [decision point] | [chosen option] | [why] |

## Data model / schema changes

```dart
// Placeholder for ToolConfig model definitions
```

## API / interface changes

```dart
// Placeholder for Parser interfaces
```

## Open questions

- [ ] How should we handle nested structures in TOML/YAML when mapping to a flat UI?
- [ ] Should backups live next to the original file (e.g., `.cursorrules.bak`) or in a centralized app data directory?

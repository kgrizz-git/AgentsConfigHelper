# Plan: Agent Config Discovery

Status: complete
Created: 2026-08-11
Profile: `.context/project-profile.md`

## Goal

Build a comprehensive, auto-discoverable database of config file locations, formats, and CLI interfaces for supported AI agents and IDEs. This is the research foundation before any UI or parser code is written.

## Targets

| Tool | Config format | Known paths | CLI available |
|---|---|---|---|
| Claude Code | JSON, Markdown | `~/.claude/settings.json`, `CLAUDE.md`, `.claude/` | Yes (`claude` CLI) |
| OpenAI Codex | TOML, JSON | `~/.codex/config.toml`, `AGENTS.md` | Yes (`codex` CLI) |
| Opencode | JSON/JSONC | `~/.config/opencode/opencode.json`, `.opencode/` | Yes (`opencode` CLI) |
| Paseo | JSON | TBD | Yes (`paseo` CLI) |
| Cursor | JSON, Markdown | `.cursorrules`, `.cursor/rules/`, `~/.cursor/` settings | Yes (`cursor` CLI) |
| Kiro | JSON/TOML (TBD) | TBD | Yes (`kiro` CLI) |
| Devin | JSON/YAML (TBD) | TBD | Yes (`devin` CLI) |
| Antigravity (agy) | TBD | TBD | Yes (`agy` CLI) |

## Research tasks

1. For each tool, document:
   - Exact config file paths (global + project-level)
   - File format and schema (JSON keys, TOML sections, Markdown conventions)
   - Permissions model (what can be allowed/denied, how rules are expressed)
   - CLI commands that read or modify config

2. Create `docs/supported-tools.md` with structured reference for each tool.

3. Design the internal `ToolConfig` model that normalizes these disparate formats.

## Output

- `docs/supported-tools.md` — human + agent reference
- `.context/research/` — raw findings, version notes, quirks
- Dart model sketches in comments or draft files

## Done when

- All 8 tools have documented config locations and formats
- A unified internal model is proposed
- Findings are recorded in repo

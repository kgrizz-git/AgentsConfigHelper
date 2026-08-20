# AgentsConfigHelper

Last reviewed: 2026-08-17

[![CI](https://github.com/kgrizz-git/AgentsConfigHelper/actions/workflows/ci.yml/badge.svg)](https://github.com/kgrizz-git/AgentsConfigHelper/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.44.9-02569B?logo=flutter)

A cross-platform desktop application for visualizing, editing, and managing configuration settings, rules, and permissions for AI agents and IDEs.

> **Under development — use at your own risk.** AgentsConfigHelper is pre-1.0 and under active
> development. It is provided "as is," without warranty of any kind. Because it reads and writes your
> real AI-agent and IDE configuration files (with automatic, timestamped backups), you use it entirely
> **at your own risk**. Always review pending changes and keep your backups before relying on it for
> production configuration.

**Project status:** Early development (0.1.0)

![Screenshot placeholder — add a screenshot or GIF to `assets/screenshots/`](https://img.shields.io/badge/screenshot-coming_soon-lightgrey)

<!-- Run `flutter run -d macos` and capture a screenshot or GIF, then replace this placeholder. -->

## Why

Different AI tools scatter their configuration across `~/.claude/`, `~/.codex/`, `.cursor/`, `~/.config/opencode/`, and more — in four different formats (JSON, JSONC, YAML, TOML) with divergent permission models. AgentsConfigHelper gives you a single interface to find, view, and safely edit all of them.

## Features

### Available now

- **Config Discovery** — Automatically detects common configuration paths on first launch (e.g. `~/.claude/settings.json`, `.cursorrules`). Users can also add custom paths manually.
- **Structured config editing (JSON/JSONC, YAML, TOML)** — Comment-preserving edits using AST-based string patching. Your trailing commas, comments, and formatting are preserved exactly as they are.
- **Instruction document editing (Markdown/text)** — Raw text editing for `CLAUDE.md`, `AGENTS.md`, `.mdc` rules, and similar instruction files. Content is never reformatted or rewritten.
- **Edit Safety** — Local-only file operations with a strict backup-before-write policy. Diff preview before every write, plus timestamped backups with one-click restore.
- **Cross-Platform** — Built in Flutter/Dart, targeting macOS, Windows, and Linux from a single codebase.

### Planned

- **CLI Integration Service** — Interfaces with agent CLIs (e.g. `claude config`, `opencode set`) when file-based edits are not sufficient.
- **Config Validation** — Strict format verification and schema validation before saving.
- **Templates & Syncing** — Save, load, and merge configuration templates across tools. See Phase 7 of the [master plan](plans/active/initial_master_plan.md).

## Supported tools

AgentsConfigHelper supports the following tools. See [`docs/supported-tools.md`](docs/supported-tools.md) for the full configuration reference, config paths, and permission models for each tool.

Every location below is discovered and editable. Structured configs get comment-preserving
edits; rules and instruction documents get raw text editing. A `—` means the tool has no
location of that kind.

| Tool | Formats | User config | Project config | Rules / instruction docs |
| --- | --- | --- | --- | --- |
| Claude Code | JSON + Markdown | `~/.claude/settings.json` | `.claude/settings.json` | `~/.claude/CLAUDE.md`, `CLAUDE.md`, `.claude/CLAUDE.md` |
| Codex | TOML + Markdown | `~/.codex/config.toml` | `.codex/config.toml` | `~/.codex/AGENTS.md` (+ shared `AGENTS.md`) |
| Opencode | JSONC + Markdown | `~/.config/opencode/opencode.json` | `.opencode/opencode.json` | `~/.config/opencode/AGENTS.md` (+ shared `AGENTS.md`) |
| Paseo | JSON | `~/.paseo/config.json` | `paseo.json` | — |
| Cursor | JSON + text/Markdown | `~/.cursor/permissions.json` | `.cursor/permissions.json` | `.cursor/rules/*.mdc`, `.cursorrules`, `CLAUDE.md` (+ shared `AGENTS.md`) |
| Kiro | YAML + Markdown | `~/.kiro/settings/permissions.yaml` | — | `.kiro/steering/*.md` (+ shared `AGENTS.md`) |
| Devin | JSON + Markdown | `~/.config/devin/config.json` | `.devin/config.json` | `~/.config/devin/AGENTS.md` (+ shared `AGENTS.md`) |
| Antigravity | JSON + Markdown | `~/.gemini/antigravity-cli/settings.json` | — | `~/.gemini/GEMINI.md`, `.agents/rules/*.md` |
| Agy-ACP | JSON | `~/.openab/agy-acp/sessions.json` | — | — |
| Kilo | JSONC + Markdown | `~/.config/kilo/kilo.jsonc` | `kilo.jsonc` / `.kilo/kilo.jsonc` | `~/.config/kilo/AGENTS.md`, `.kilo/agents/*.md` (+ shared `AGENTS.md`) |
| Cline | JSON + Markdown | `~/.cline/data/settings/global-settings.json` | — | `.clinerules/`, `.clinerules`, `.cline/rules/*.md` (+ shared `AGENTS.md`) |
| LM Studio | JSON + YAML | `~/.lmstudio/settings.json` | — | hub `model.yaml` / presets (weights not discovered) |
| GitHub Copilot | JSONC + Markdown | `~/.copilot/settings.json` (+ managed `config.json`, `mcp-config.json`) | `.github/copilot/settings.json` | `.github/copilot-instructions.md` (+ shared `AGENTS.md`) |
| AGENTS.md (shared) | Markdown | `~/.agents/AGENTS.md` | `AGENTS.md` | Cross-tool [agents.md](https://agents.md/) convention |

## Getting Started

### Prerequisites

- **Flutter SDK** >= 3.44.9 ([install guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK** >= 3.12.2 (bundled with Flutter)
- **Linux only:** `ninja-build` and `libgtk-3-dev` (required for building the native shell)

  ```bash
  sudo apt-get install -y ninja-build libgtk-3-dev
  ```

### Run from source

```bash
flutter pub get
flutter run -d macos  # or windows / linux
```

### Build release binary

```bash
flutter build macos --release    # or linux / windows
```

## How it works / Safety model

- **Backup location:** Backups are stored in a centralized application-support directory, not alongside the original files:
  - macOS: `~/Library/Application Support/<bundle-id>/backups`
  - Linux: `~/.local/share/<app>/backups` (or `$XDG_DATA_HOME`)
  - Windows: `%APPDATA%\<app>\backups`

- **Backup retention:** The newest 10 snapshots per original file path are retained. Older backups are pruned best-effort after each save. Filenames encode the original absolute path (including usernames and project names). Backups are byte-for-byte copies of the original file, so any secret embedded in the source config — including inside comments (e.g. `// API key: sk-...`) — is duplicated verbatim into both the updated file and the backup. The backup directory lives outside `~/.claude/`, `~/.codex/`, and other tool-specific config directories, so whatever permissions or tooling protect those paths do not extend to backups.

- **Diff before write:** A diff preview is shown before every save. There is no in-session undo stack; the revert path is timestamped backup restore via the History & Backups view.

- **Comment preservation:** JSONC and YAML parsers use AST-based string patching (`json_ast`, `yaml_edit`) to mutate only target values, preserving user comments, trailing commas, and formatting. TOML serialization is currently lossy (see [ADR-001](docs/adr/ADR-001-toml-comment-preservation.md)).

- **Data classification: Internal.** Config files may contain tokens or sensitive local paths. All file parsing and visualization happens strictly locally on the machine. Nothing is ever transmitted to the cloud or committed to the repository (beyond synthetic fixtures for testing).

- **Purging backups:** Delete the contents of the backup directory listed above to remove all snapshots.

## Development

### Commands

```bash
flutter pub get                              # install dependencies
flutter analyze --fatal-infos                # lint + type check
dart format --output=none --set-exit-if-changed .  # format check
flutter test                                 # run tests
flutter test --coverage                      # run tests with coverage
```

### Quality gates

The CI pipeline enforces:

- `dart format` (Dart formatter)
- `flutter analyze --fatal-infos` (static analysis)
- `dart_code_linter:metrics` at warning level
- **80% minimum line coverage** (vendor code excluded)
- `gitleaks` full-history secret scan
- `semgrep` SAST scan (non-blocking, results in Security tab)
- **3-OS release build matrix** (macOS, Linux, Windows)

### Pre-commit hooks

```bash
pre-commit install
pre-commit run --all-files
```

Hooks include `gitleaks`, `markdownlint`, `shellcheck`, and repo hygiene checks. See [`hooks/README.md`](hooks/README.md).

## Contributing

See [`AGENTS.md`](AGENTS.md) for the agent/developer contract, conventions, and key file reference. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the system architecture overview.

## License

This project is licensed under the [MIT License](LICENSE).

The vendored `lib/vendor/json_ast/` library is also MIT-licensed (copyright 2019 json_ast authors). See [`lib/vendor/json_ast/LICENSE`](lib/vendor/json_ast/LICENSE).

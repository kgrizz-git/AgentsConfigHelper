# AgentsConfigHelper

AgentsConfigHelper is a cross-platform desktop application designed to visualize, edit, sync, and manage configuration settings, rules, and permissions for various AI agents and IDEs.

It provides a unified interface for tools like Claude, Codex, Opencode, Paseo, Cursor, Kiro, Devin, and Antigravity.

## Features

- **Config Discovery**: Automatically detects common configuration paths on first launch (e.g. `~/.claude/settings.json`, `.cursorrules`, etc.).
- **Unified Interface**: Abstracted data models handle JSON, YAML, TOML, and Markdown config formats natively.
- **Edit Safety**: Local-only file operations with a strict backup-before-write policy. Includes diff previews and undo mechanisms.
- **Cross-Platform**: Built in Flutter/Dart, targeting macOS, Windows, and Linux from a single codebase.

## Getting Started

1. **Prerequisites**: Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the Application**:
   ```bash
   flutter run -d macos  # or windows / linux
   ```

## Development and Contributions

This project uses a strict pre-commit and CI setup to enforce line limits, code complexity (`very_good_analysis`), and secret scanning (`gitleaks`).

- **Formatting**: `dart format .`
- **Linting**: `flutter analyze`
- **Testing**: `flutter test`

### Key Files

- `lib/` - Main Flutter application source code.
- `AGENTS.md` - Rules and guidelines for AI coding agents working in this repository.
- `docs/supported-tools.md` - Internal research mapping out supported AI agents and their configuration formats.
- `ARCHITECTURE.md` - High-level system architecture overview.

## Data Privacy

**Data Classification: Internal.**
Config files may contain tokens or sensitive local paths. All file parsing and visualization happens strictly locally on the machine. Nothing is ever transmitted to the cloud or committed to the repository (beyond synthetic fixtures for testing).

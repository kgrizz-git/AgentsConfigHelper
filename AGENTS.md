# AGENTS.md

Last reviewed: 2026-08-11

Single source of truth for AI coding agents working in this repository. Other agent
entrypoints (`CLAUDE.md`, `GEMINI.md`, `QWEN.md`, `.github/copilot-instructions.md`,
`.cursor/rules/`, `.windsurf/rules/`) are thin pointers back to this file.

> **Project:** AgentsConfigHelper — cross-platform Flutter desktop app for visualizing,
> editing, and managing config settings, rules, and permissions for AI agents and IDEs
> (Claude, Codex, Opencode, Paseo, Cursor, Kiro, Devin, Antigravity, etc.).

## Read this first

**Quick navigation:** See [`docs/NAVIGATION.md`](docs/NAVIGATION.md) for a role-based guide to finding documentation.

Do not load everything. Start here, then open only what the task needs.

| If you are… | Read |
|---|---|
| Starting a new session on this project | `.context/project-profile.md`, then [`prompts/new-agent-session.md`](prompts/new-agent-session.md) |
| Moving work between agents or IDEs | [`templates/handoff.md`](templates/handoff.md) → `.context/handoff.md` |
| Running periodic repo health checks | [`prompts/maintenance-loop.md`](prompts/maintenance-loop.md) |
| Looking for a tool / library / service | [`inventory/README.md`](inventory/README.md) (a menu, not a checklist) |
| Adding/enforcing repo rules | [`policies/README.md`](policies/README.md) |
| Wiring local checks | [`hooks/README.md`](hooks/README.md) |
| Working with supported agent configs | `docs/supported-tools.md` (after P6 research) |

## Project essentials

- **Stack:** Flutter / Dart, targeting macOS, Windows, Linux
- **No Python** — ignore ruff/Python hooks in template; Dart toolchain handles lint/format/tests
- **Config discovery:** auto-detect common paths on first launch + user-managed paths
- **Edit safety:** backup-before-write with diff/undo and restore instructions
- **Data classification:** internal — config files may contain tokens but nothing leaves the machine

## Key files and directories

| Path | Purpose |
|---|---|
| `.context/project-profile.md` | Project identity, stack, decisions (fast-load summary) |
| `lib/` | Flutter source (models, parsers, services, screens, widgets) |
| `test/` | Unit and widget tests |
| `plans/active/` | Active implementation plans |
| `docs/supported-tools.md` | Config format reference for each supported agent/IDE |
| `hooks/` | Pre-commit hooks (gitleaks, hygiene, markdownlint) |
| `.github/workflows/ci.yml` | Build matrix + analyze + test + secret scan |

## Commands

```bash
flutter pub get           # install dependencies
flutter analyze --fatal-infos   # lint + type check
dart format --output=none --set-exit-if-changed .   # format check
flutter test              # run tests
flutter run -d macos     # run on desktop (macos/windows/linux)
flutter build macos --release   # build release binary
```

## Conventions

- Follow Dart/Flutter style (dart format enforced in CI)
- No comments unless they add non-obvious context
- Keep widgets small and focused; business logic in services/models
- Config parsers are pure functions — easy to test
- New tools (agent/IDE) get a parser + entry in `docs/supported-tools.md`

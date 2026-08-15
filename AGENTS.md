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
| --- | --- |
| Starting a new session on this project | `.context/project-profile.md`, then [`prompts/new-agent-session.md`](prompts/new-agent-session.md) |
| Moving work between agents or IDEs | [`templates/handoff.md`](templates/handoff.md) → `.context/handoff.md` |
| Running periodic repo health checks | [`prompts/maintenance-loop.md`](prompts/maintenance-loop.md) |
| Looking for a tool / library / service | [`inventory/README.md`](inventory/README.md) (a menu, not a checklist) |
| Adding/enforcing repo rules | [`policies/README.md`](policies/README.md) |
| Wiring local checks | [`hooks/README.md`](hooks/README.md) |
| Working with supported agent configs | `docs/supported-tools.md` |

## Project essentials

- **Stack:** Flutter / Dart, targeting macOS, Windows, Linux
- **App language is Dart, not Python** — the Dart toolchain handles all app lint/format/tests, so
  ignore the template's ruff/Python *application* hooks. This is not a ban on Python: repo tooling
  (pre-commit hook scripts under `hooks/scripts/`) is intentionally written in Python and targets 3.10+.
- **Review checklist:** [`best_practices.md`](best_practices.md) is a compact mirror of these
  conventions for Qodo's compliance check — keep it in sync with this file (AGENTS.md is authoritative).
- **Config discovery:** auto-detect common paths on first launch + user-managed paths
- **Edit safety:** backup-before-write with diff/undo and restore instructions
- **Data classification:** internal — config files may contain tokens but nothing leaves the machine

## Key files and directories

| Path | Purpose |
| --- | --- |
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

- **Never bypass pre-commit hooks (e.g., `--no-verify`) or force add files (e.g., `git add -f`) without explicit user permission. If hooks fail, fix the issues.**
- **Never disable linters, rules, or checks (e.g., in `.pre-commit-config.yaml` or `.gitignore`) without explicit user permission.**
- Follow Dart/Flutter style (dart format enforced in CI)
- No comments unless they add non-obvious context
- Keep widgets small and focused; business *logic* lives in services/models. Widgets (including
  Riverpod `ConsumerWidget`/`ConsumerState`) may still invoke services and read providers from
  callbacks — that orchestration is not "business logic in the widget."
- Config parsers are pure functions — easy to test
- New tools (agent/IDE) get a parser + entry in `docs/supported-tools.md`

## Agent tooling policy

- Search and read targeted files before requesting broad repository context.
- Use one primary code-intelligence/indexing tool per role or task.
- Prefer a CLI plus task-specific skill for batch work; use MCP when persistent,
  interactive state materially helps.
- Record decisions, changed files, verification, and next steps in a handoff before
  changing agents or IDEs.
- Keep credentials, generated indexes, and local agent state out of version control.

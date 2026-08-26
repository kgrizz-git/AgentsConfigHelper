# AGENTS.md

Last reviewed: 2026-08-16

Single source of truth for AI coding agents working in this repository. Other agent
entrypoints (`CLAUDE.md`, `GEMINI.md`, `QWEN.md`, `.github/copilot-instructions.md`,
`.cursor/rules/`, `.windsurf/rules/`) are thin pointers back to this file.

> **Project:** AgentsConfigHelper — cross-platform Flutter desktop app for visualizing,
> editing, and managing config settings, rules, and permissions for AI agents and IDEs
> (Claude Code, Codex, Opencode, Paseo, Cursor, Kiro, Devin, Antigravity, Agy-ACP, etc.).
>
> **Under development — use at your own risk.** Pre-1.0, under active development. Provided
> "as is," without warranty. Reads and writes real agent/IDE config files (with automatic
> timestamped backups). Always review pending changes.

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
| Running the macOS disposable test-root smoke | `docs/macos-test-root.md` |

## Project essentials

- **Stack:** Flutter / Dart, targeting macOS, Windows, Linux
- **App language is Dart, not Python** — the Dart toolchain handles all app lint/format/tests, so
  ignore the template's ruff/Python *application* hooks. This is not a ban on Python: repo tooling
  (pre-commit hook scripts under `hooks/scripts/`) is intentionally written in Python and targets 3.10+.
- **Review checklist:** [`best_practices.md`](best_practices.md) is a compact mirror of these
  conventions for Qodo's compliance check — keep it in sync with this file (AGENTS.md is authoritative).
- **Config discovery:** auto-detect common paths on first launch + user-managed paths
- **Edit safety:** backup-before-write with diff preview and timestamped backup restore
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

## Maintenance

- Use semantic versioning (`CHANGELOG.md` already declares this; `TO_DO.md` tracks
  formalizing it as an enforced policy).
- Update the relevant plan(s) in `plans/active/` as each phase is implemented — reflect
  what actually shipped, not just what was proposed. Every active plan must have one open,
  linked entry in `TO_DO.md`; add it when activating the plan and keep the two records aligned.
- Archive a plan only as the final implementation step: after its scope, validation, review,
  and explicitly recorded follow-through are complete, remove its `TO_DO.md` entry and move the
  file from `plans/active/` to `plans/archive/` rather than deleting it. Do neither early.
- Log changes in the appropriate changelog: user-facing changes go in
  `CHANGELOG.md`; developer-only changes (hooks internals, tests/CI) go in
  `CHANGELOG.dev.md`. See `policies/changelog-conventions.md`.
- Remove completed items from `TO_DO.md` once done. Plans are different: keep completed
  items in plan files as history — archive the plan instead of stripping it.

## Agent tooling policy

- Search and read targeted files before requesting broad repository context.
- Use one primary code-intelligence/indexing tool per role or task.
- Prefer a CLI plus task-specific skill for batch work; use MCP when persistent,
  interactive state materially helps.
- Record decisions, changed files, verification, and next steps in a handoff before
  changing agents or IDEs.
- Keep credentials, generated indexes, and local agent state out of version control.

## macOS distribution note

The current macOS workflow is source-build-only and intentionally unsandboxed
so the app can discover and edit real user configuration files. Do not publish
or distribute a prebuilt macOS artifact without revisiting
[`docs/adr/ADR-002-macos-file-access.md`](docs/adr/ADR-002-macos-file-access.md).
Local source-build outputs, including `flutter build macos --release`, remain
supported.

For the opt-in, development-only macOS test-root workflow, see
[`docs/macos-test-root.md`](docs/macos-test-root.md). It explains the safety contract and the
root [`dev.sh`](dev.sh) entrypoint; do not substitute personal configuration files for its
token-free fixtures.

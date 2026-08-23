# Documentation Navigation

Last reviewed: 2026-08-16

> **Under development — use at your own risk.** AgentsConfigHelper is pre-1.0 and under active
> development. See [README.md](../README.md) for details.

Quick navigation guide for AgentsConfigHelper's documentation. Use this to find what you need without loading everything.

## Quick Start by Role

### I'm new to the project

1. Read [`README.md`](../README.md) (2 min)
2. Check [`docs/supported-tools.md`](supported-tools.md) for the tools and config formats you care about
3. Review [`ARCHITECTURE.md`](../ARCHITECTURE.md) for the system overview

### I'm an AI agent starting a session

1. Read [`AGENTS.md`](../AGENTS.md) — the single source of truth for conventions and rules
2. Check [`docs/supported-tools.md`](supported-tools.md) for config format reference
3. See [`ARCHITECTURE.md`](../ARCHITECTURE.md) for the service and parser layers

### I'm contributing code

1. Read [`AGENTS.md`](../AGENTS.md) for conventions
2. Run the quality gates: `dart format --output=none --set-exit-if-changed .` and `flutter analyze --fatal-infos`
3. Check [`plans/active/`](../plans/active/) for current implementation plans

## Documentation Map

### Core (Read These First)

- [`AGENTS.md`](../AGENTS.md) — Single source of truth for AI coding agents
- [`README.md`](../README.md) — Project overview, features, getting started, safety model
- [`ARCHITECTURE.md`](../ARCHITECTURE.md) — High-level system architecture
- [`docs/supported-tools.md`](supported-tools.md) — Config format reference for each supported tool

### Design & Decisions

- [`DESIGN.md`](../DESIGN.md) — UI and data model design notes
- [`docs/adr/`](adr/) — Architecture Decision Records
- [`docs/testing-strategies.md`](testing-strategies.md) — layered safe-testing options
- [`docs/macos-test-root.md`](macos-test-root.md) — macOS disposable-fixture smoke workflow
- [`docs/research/`](research/) — raw discovery and product-gap research; verify findings
  against the source before implementation

### Plans & Tracking

- [`plans/active/`](../plans/active/) — Active implementation plans
- [`plans/archive/`](../plans/archive/) — Completed plans (history)
- [`TO_DO.md`](../TO_DO.md) — Deferred items and follow-ups
- [`CHANGELOG.md`](../CHANGELOG.md) — User-facing changes
- [`CHANGELOG.dev.md`](../CHANGELOG.dev.md) — Developer-only changes

### Hooks & CI

- [`hooks/README.md`](../hooks/README.md) — Pre-commit hooks and policy scripts
- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — CI pipeline

## Common Commands

```bash
flutter pub get                              # install dependencies
flutter run -d macos                         # run from source
flutter analyze --fatal-infos                # lint + type check
dart format --output=none --set-exit-if-changed .  # format check
flutter test                                 # run tests
flutter build macos --release                # build release binary
```

## Tips

1. **Don't load everything** — Start with `AGENTS.md`, then open only what you need
2. **One source of truth** — `docs/supported-tools.md` is the authoritative tool/config reference
3. **Plans are history** — Completed plans get archived, not deleted

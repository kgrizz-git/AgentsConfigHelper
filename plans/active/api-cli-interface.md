# Plan: Local API/CLI Interface (deferred)

Last reviewed: 2026-09-03
Date: 2026-09-03
Author: maintainers
Status: deferred — triaged, not in Next Up; activation requires bounded scope and fidelity decision
Linked task: [TO_DO.md — API/CLI interface (deferred)](../../TO_DO.md#apicli-interface-deferred)
Parent: [Master plan](../../plans/active/initial_master_plan.md) Phase 7 (Templates) / Phase 8 (Visual Editing)
Related: [Structured Configuration Roadmap](structured-configuration-roadmap.md) Phase 0.5, [ADR-001](../../docs/adr/ADR-001-toml-comment-preservation.md), [ADR-002](../../docs/adr/ADR-002-macos-file-access.md)

## Goal

Expose the app's local file operations to humans and agents without launching the Flutter GUI, while preserving the existing safety model (backup-before-write, diff preview, fidelity disclosure). The surface is for **local** automation only — dotfiles/CI, headless servers, and `exec`-capable agents (Paseo, Claude Code, Cursor) — not a cloud service.

This is the inverse of the existing `Planned` item in `README.md`/`ARCHITECTURE.md` (`CLI Integration Service` that calls `claude config`/`opencode set`). That item remains deferred to Master Plan Phase 7; this plan exposes *this app* as a callee.

## Product decisions

- **Local-only, no cloud sync.** `ARCHITECTURE.md` V1 is local-only file I/O; `TO_DO.md` AI Agent Integration requires secret redaction before any external call. This interface never transmits file contents off-machine; MCP/HTTP transports are loopback only and out of scope until explicitly approved.
- **CLI first, MCP shim second, HTTP last.** Easiest and most robust is a `bin/` CLI with `--json` output and deterministic exit codes (no networking, no auth, no daemon). A narrow MCP stdio adapter reuses the same command handlers for agents. Local HTTP (`shelf` on `127.0.0.1`) is deferred — it adds port allocation, token auth, and lifecycle complexity that conflicts with the current unsandboxed source-build scope in `ADR-002`.
- **Reuse the service layer, keep `lib/` pure.** `lib/services/config_service.dart`, `DiscoveryService`, `BackupService`, and `FidelityAssessor` remain pure/testable. `bin/` owns `args` parsing, exit codes, and `dart:io`; `lib/` gains no `dart:io` or Flutter dependencies.
- **Safety parity with the GUI.** Every write still creates a timestamped backup (`BackupService`), supports `--dry-run` diff without writing, and surfaces the same `FidelityRisk` (`lib/services/fidelity_assessor.dart`) that the GUI's `FormattingFidelityNotice` shows. No `--force` that bypasses backup.
- **Secrets stay local.** `models.json` / `kilo.jsonc` and similar secret-bearing files are never redacted on local reads, but any future AI-assist that sends context off-machine must follow the redaction rule already in `TO_DO.md` and `plans/active/future_enhancements.md` (In-App AI Assistant).

## Proposed surface (Phase 1 CLI)

All commands are local, operate on the same discovered paths as the GUI (`ToolDescriptorRegistry`), and respect `PASEO_HOME`/`COPILOT_HOME`/`CODEX_HOME` overrides already handled by `DiscoveryService`. `--test-root` containment applies when present.

| Command | Purpose | Output |
| --- | --- | --- |
| `discover [--json]` | List registered configs (tool, scope, path, format, exists) | table or JSON array |
| `get <path> [--json]` | Parse and print normalized `ToolConfig` + raw head | JSON + raw on `--json` |
| `validate <path> [--json]` | Parse-only check; position-accurate errors for JSON/YAML/TOML | exit 2 on parse error |
| `diff <path> --apply <patch.json> [--dry-run]` | Show unified diff for a proposed structured or raw edit; fidelity risk | diff text + `fidelity:{risk,mechanism}` |
| `apply <path> --apply <patch.json> [--dry-run] [--json]` | Backup, serialize via appropriate parser, write | backup path + fidelity |
| `backups <path> [--json]` | List timestamped snapshots | table/JSON |
| `restore <path> --backup <name>` | Backup-before-restore (same as GUI History & Backups) | restored path |

`patch.json` is a minimal envelope, e.g. `{"rules":["a"],"permissions":["Bash(git *)"]}`; raw edits use `{"rawContent":"..."}` and route through `ConfigService.saveRawConfig` so merge-fidelity logic is exercised. No in-place mutation without `--apply`.

Exit codes: `0` success, `2` parse/validation failure, `3` fidelity-blocked (future fail-closed), `4` I/O/permission, `5` bad args.

## Architecture boundary

```text
bin/agents_config_helper.dart  ->  args parsing, exit codes, JSON envelope, --test-root wiring
lib/services/*, lib/parsers/*, lib/catalog/*  ->  reused unchanged, no dart:io in lib
lib/services/fidelity_assessor.dart  ->  shared risk/mechanism for CLI and GUI
```

- `bin/` is the only place that imports `dart:io`/`args`. Unit tests for handlers live in `test/cli/` and reuse existing token-free fixtures in `test/fixtures/staging_home/`.
- `--test-root` reuses the existing descriptor-relative no-follow bridge; the CLI rejects symlink escapes identically to the GUI.
- No new config file for the CLI itself; it reads the same `DiscoveryPreferences` as the GUI.

## Phases and checklist

### Phase 1 — local CLI (prerequisite for any agent surface)

- [ ] Add `bin/agents_config_helper.dart` with `package:args`, `--json`/`--dry-run`/`--test-root` globals, and the command table above.
- [ ] Wire each command to the existing services (no duplicated parser logic); `apply` delegates to `ConfigService.saveConfig` / `saveRawConfig` so `FidelityAssessor` and backup semantics are identical to the GUI.
- [ ] Add `test/cli/` coverage reusing `staging_home` fixtures: `discover`, `get`, `validate` (including JSONC fallback), `diff --dry-run` creates no write/backup, `apply` creates exactly one backup, fidelity `caution`/`warning`/`none` matches `FormattingFidelityNotice`.
- [ ] Document in `README.md` (CLI section) and `ARCHITECTURE.md` (new CLI subsection under Service Layer); add to `TO_DO.md` deferred entry.

### Phase 2 — MCP stdio shim (only after Phase 1 is stable)

- [ ] Add a thin `bin/mcp_server.dart` (or `mcp` subcommand) speaking MCP JSON-RPC over stdio, exposing `discover`, `get`, `validate`, `diff`, `apply`, `backups`, `restore` as tools. Each tool handler delegates to the same Phase 1 command handlers — no second implementation.
- [ ] Keep stdio only (no SSE/HTTP); no auth beyond local process spawn. Reuse `--test-root` when the host provides it.
- [ ] Add MCP-specific tests (tool listing, JSON-RPC round-trip) plus secret-bearing fixture that proves no redaction on local read and no off-machine transmission.

### Phase 3 — local HTTP (deferred, not started here)

- [ ] Requires explicit product review: port selection, bearer-token auth, CORS, daemon lifecycle, and macOS sandbox/FLUTTER build implications per `ADR-002`. Not started until Phase 0.5 fallback policy (fail-closed vs warning) in `formatting-fidelity-disclosure.md` is decided, because HTTP would otherwise expose the lossy fallback over the network.

## Non-goals

- Cloud sync, account system, or remote API.
- Replacing the Flutter GUI, diff preview, or backup model.
- Structured editing of Markdown/Starlark rules as schemas (still raw-text, per Roadmap Non-goals).
- Full HTTP server in this cycle.

## Validation

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
# once bin/ exists:
dart run bin/agents_config_helper.dart discover --json | jq
dart run bin/agents_config_helper.dart validate test/fixtures/staging_home/.claude/settings.json
dart run bin/agents_config_helper.dart diff --dry-run --apply patch.json test/fixtures/staging_home/.codex/config.toml
python3 ci/scripts/check_doc_links.py --internal-only --strict
```

Every slice must retain byte-for-byte `validate`/`diff --dry-run` no-write guarantees and backup-before-write on `apply`/`restore`.

## Completion steps

1. Implement Phase 1 CLI; update `README.md`, `ARCHITECTURE.md`, `CHANGELOG.md` (user-facing) and `CHANGELOG.dev.md` (tests).
2. Add Phase 2 MCP shim only after Phase 1 tests pass; do not mark the `TO_DO.md` deferred entry complete until at least Phase 1 is shipped and validated.
3. Revisit HTTP only after the fidelity fallback decision is recorded in `ADR-001` and the Roadmap.
4. Move this plan to `plans/archive/` as the final completion action, per `policies/plans-and-todos.md`.

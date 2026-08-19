# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"

## Follow-ups from Phase 5.5 (docs accuracy)

- [x] ~~Add a "Reveal backups folder" action in the UI~~ — done (F6, 2026-08-17).
- [x] ~~Reconcile or regenerate `.context/project-profile.md`~~ — done (F4, 2026-08-17).
- [ ] Add a README screenshot or GIF to `assets/screenshots/` (blocked on user — an agent cannot capture a running Flutter desktop GUI). README currently shows a placeholder badge.
- [x] ~~Add the cross-doc drift guard~~ — done (F3, 2026-08-17).
- [x] ~~Fix broken relative links~~ — done (F1, 2026-08-17).
- [x] ~~Reconcile `policies/changelog-conventions.md`~~ — done during Phase 5.5 (2026-08-16).

## Tool-support gaps (discovery expansion — see Phase 9 of the master plan)

- [ ] **Catalog every location where each supported tool stores config or rules.** Goal: for
      the tools we already claim to support, `ToolDescriptorRegistry` should cover *all*
      config and rules paths, both user and project scope — not one representative path per
      tool. The 2026-08-17 audit of the registry's 32 targets found these gaps to confirm or
      close:
  - [ ] **Kiro** has no project-scope structured config target — only `.kiro/steering/*.md`.
        Confirm whether a project-level `permissions.yaml` (or equivalent) exists upstream.
  - [ ] **Antigravity** has no project-scope structured config target — only rules files.
        Confirm whether a project-level settings file exists upstream.
  - [ ] **Agy-ACP** has a single user-scope target and no rules/instruction targets. Confirm
        whether the host ACP config (e.g. Zed `agent_servers`) should be in scope at all.
  - [ ] **Cursor** user scope covers only `~/.cursor/permissions.json`; confirm whether
        user-scope rules files (e.g. a global `.cursorrules` equivalent) exist.
  - [ ] Re-verify each tool's paths against upstream docs and refresh
        `.context/research/2026-08-13-discovery-targets.md`, then update
        `docs/supported-tools.md` and the README table together.
- [ ] Expand supported-tool catalog beyond the current 9 entries. Tracked after the
      2026-08-16 review of registry vs. requested tools:
  - [ ] **Kilo** — not in `tool_descriptor_registry.dart` or `docs/supported-tools.md`; add `ToolId` + config paths.
  - [ ] **Cline** — not supported at all; add `ToolId` + config paths.
  - [ ] **Split Cursor agent vs Cursor IDE** — current `cursor` entry folds agent
        permissions (`~/.cursor/permissions.json`) and IDE instruction files
        (`.cursorrules`, `.cursor/rules/*.mdc`) into one tool; model the IDE-level
        editor `settings.json` separately (e.g., `cursorIde`).
  - [ ] **Split Antigravity surfaces** — current `antigravity` entry only covers the CLI
        config (`.gemini/antigravity-cli/settings.json`); add distinct entries/config for
        the Antigravity IDE, the Antigravity desktop app, and the `agy` CLI settings
        (note `agyAcp` already models the ACP session bridge separately).
  - [ ] **Promote VS Code / GitHub Copilot** from deferred docs-only to a first-class
        `ToolDescriptor` (already stubbed in `docs/supported-tools.md`).
  - [ ] **LM Studio** — not supported at all; add `ToolId` + config paths (local LLM runner
        with model management and API server settings).

## Deferred from PR #5 review (Qodo / SonarCloud)

- [ ] Wire SonarCloud coverage reporting: switch from Automatic Analysis to a
      CI `sonar-scanner` step and set `sonar.dart.lcov.reportPaths=coverage/lcov.info`
      so coverage shows on all branches (currently 0.0% everywhere — Automatic
      Analysis cannot ingest lcov). The `test` job's 80% lcov gate already
      enforces coverage independently.
- [ ] Extract config persistence out of the widget layer: `MainShell` calls
      `ConfigService.saveConfig`/`saveRawConfig` directly, and `HistoryModal`
      reaches data via `backupListProvider`. Consider a dedicated save
      controller/notifier so widgets stay presentation-only (Qodo architecture
      findings — deferred, likely not worth doing). The current save callback
      in `MainShell` is already a clean 3-step orchestration (call service,
      invalidate provider, setState) that `AGENTS.md` explicitly permits.
      Extracting a full Riverpod controller would create split-brain state
      (controller updates via Riverpod while loading/error/dirty stays as
      setState) with no user-facing benefit. Only revisit if a concrete
      testability gap emerges that the existing `onSave` injection point on
      `ConfigEditor` cannot cover.
- [ ] Revisit TOML lossless round-trip: `ConfigService.saveRawConfig` re-serializes
      through `parser.serialize` when structured edits diverge from the raw
      baseline, which drops comments/whitespace for TOML (serializer is not
      AST-preserving). See ADR referenced in `toml_config_parser.dart`.
- [ ] Adjust the Qodo dashboard settings for Python false positives — **only if the
      noise persists**. The repo-side fix already shipped (Dart-vs-Python note in
      `AGENTS.md`, `.pr_agent.toml` with scoped `extra_instructions`, no checks
      disabled), so what remains is the Python-3.8-baseline assumption and any
      org-level Compliance-tool toggle. Both live at qodo.ai, not in this repo —
      nothing to change here unless the dashboard is the cause.

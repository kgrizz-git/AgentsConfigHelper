# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] add a third party license file
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"

## Tool-support gaps (discovery expansion — see Phase 9 of the master plan)

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
      findings — deferred, not blocking).
- [ ] Revisit TOML lossless round-trip: `ConfigService.saveRawConfig` re-serializes
      through `parser.serialize` when structured edits diverge from the raw
      baseline, which drops comments/whitespace for TOML (serializer is not
      AST-preserving). See ADR referenced in `toml_config_parser.dart`.
- [ ] Fix manual-path removal for files also discovered via a catalog target
      (Qodo #10): `DiscoveryService.addIfValid` mutates an existing discovered
      item to `isManual: true` instead of tracking manual provenance separately,
      so `removeManualPath` deletes only the preference entry and the file is
      rediscovered via its user/project scope on refresh — the sidebar "remove"
      silently no-ops. Disambiguate manual provenance so removal only affects
      manual-only items. Touches `lib/services/discovery_service.dart`,
      `lib/state/providers.dart`, `lib/models/discovered_config.dart`.
- [x] Correct the Qodo review profile for the Python false positives —
      clarified the Dart-vs-Python note in AGENTS.md and added `.pr_agent.toml`
      with scoped `extra_instructions` (no checks disabled). Remaining, only if
      the noise persists: the Python-3.8-baseline assumption and any org-level
      Compliance-tool toggle are dashboard settings at qodo.ai, not repo files.

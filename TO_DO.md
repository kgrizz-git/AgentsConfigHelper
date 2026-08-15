# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] add a third party license file
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"

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
- [x] Correct the Qodo review profile for the Python false positives —
      clarified the Dart-vs-Python note in AGENTS.md and added `.pr_agent.toml`
      with scoped `extra_instructions` (no checks disabled). Remaining, only if
      the noise persists: the Python-3.8-baseline assumption and any org-level
      Compliance-tool toggle are dashboard settings at qodo.ai, not repo files.

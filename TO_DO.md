# To Do

- [ ] Complete all phases of the master plan
- [ ] Address issues flagged by sonar cloud
- [ ] institute semantic versioning
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"

## Follow-ups from Phase 5.5 (docs accuracy)

- [ ] Add a "Reveal backups folder" action in the UI (backup retention/pruning already shipped).
- [ ] Reconcile or regenerate `.context/project-profile.md` to match shipped code — its "sync", "call external CLIs", "diff/undo", and open backup-location question are stale. (Gitignored, not shipped; tracked here.)
- [ ] Add a README screenshot or GIF to `assets/screenshots/` (blocked on user — an agent cannot capture a running Flutter desktop GUI). README currently shows a placeholder badge.
- [ ] **Add the cross-doc drift guard** (deferred from Phase 5.5 M3). Assert in a test that
      every `ToolDescriptorRegistry.catalog[i].displayName` appears in
      `docs/supported-tools.md` — names as source of truth, so it catches omissions and
      substitutions, not just a count. Note the doc currently uses `Codex CLI` and `agy-acp`
      where the registry says `Codex` and `Agy-ACP`, so the naming must be reconciled in one
      direction first or the test fails on 2 of 9. Do **not** add a count-only assertion
      (`tool_descriptor_registry_test.dart` already locks `catalog.length`) and do **not** use
      an inline-HTML marker.
- [ ] **Fix broken relative links** flagged by `ci/scripts/check_doc_links.py` (5 real, all
      pre-existing; the `tmp/` hits are gitignored scratch and can be ignored):
  - [ ] `ci/README.md:9` → `../.github/workflows/template-checks.yml`
  - [ ] `ci/README.md:48` → `examples/strict-sensitive-data.yml`
  - [ ] `hooks/README.md:86` → `../ci/examples/strict-sensitive-data.yml`
  - [ ] `inventory/medical-data-security.md:55` → `../ci/examples/strict-sensitive-data.yml`
  - [ ] `policies/commits-and-branches.md:65` → `../ci/examples/open-prs-advisory.yml`
  - [ ] Advisory (not broken): `inventory/harness-engineering.md` points at
        `oreolion/ai-sync-plugin`, which now redirects to `Oreolion/ai-sync` — re-evaluate the
        entry and refresh its review date rather than deleting it.
- [ ] Reconcile `policies/changelog-conventions.md` with the de-templated changelogs — it
      still uses template-consumer framing (`:20`, `:36`) while `AGENTS.md` and `CHANGELOG.md`
      now say "user-facing". Both files link to it as the authority.

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
- [ ] Adjust the Qodo dashboard settings for Python false positives — **only if the
      noise persists**. The repo-side fix already shipped (Dart-vs-Python note in
      `AGENTS.md`, `.pr_agent.toml` with scoped `extra_instructions`, no checks
      disabled), so what remains is the Python-3.8-baseline assumption and any
      org-level Compliance-tool toggle. Both live at qodo.ai, not in this repo —
      nothing to change here unless the dashboard is the cause.

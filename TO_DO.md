# To Do

## Next Up

Keep this queue to **3–5 items**. When it falls below three, promote one or two actionable
items from the body; do not add more than needed to restore the queue. Each item below links to
its full entry, which remains the source of scope and completion detail.

1. [Structured configuration presentation](#structured-configuration-presentation)
2. [Safe exploratory testing](#safe-exploratory-testing)
3. [Project workspace labels](#project-workspace-labels)
4. [Tool catalog integrity acceptance](#tool-catalog-integrity-acceptance-follow-through)
5. [macOS local execution follow-through](#macos-local-execution-follow-through)

## Backlog maintenance

- Every file in `plans/active/` must have one open, linked entry in this file. Add that entry
  when activating a plan; keep its scope/status aligned with the plan as work progresses.
- Completing implementation is the last step before removing its TO_DO entry and archiving its
  plan. Do not remove the entry or archive the plan while validation, review, or an explicitly
  recorded follow-through remains.

## Release and maintenance

### Release readiness — prepare 0.2.0

- [ ] Confirm the scope of the accumulated
      backward-compatible user-facing changes, then bump `VERSION` and `pubspec.yaml`, move
      `CHANGELOG.md` entries from Unreleased into a dated release section, and choose the next
      platform build number. Do this when cutting a release, not for every feature PR.
- [ ] check and possibly clarify harness guidance about the use of TO_DO.md, "CHANGELOG.dev.md", "CHANGELOG.md"

### Master plan delivery

- [ ] Complete all remaining phases of the [master plan](plans/active/initial_master_plan.md).

### Future-enhancement triage

- [ ] Periodically review [future enhancements](plans/active/future_enhancements.md) and
      [`docs/PRODUCT_IDEAS.md`](docs/PRODUCT_IDEAS.md); promote a bounded, approved slice into
      a new active plan only when it is ready to implement.

## Product follow-ups (prioritized)

### Recommended delivery order

1. **Broaden tool schemas incrementally:** use sanitized staging fixtures and regression tests
   to select each next schema rather than treating every format alike.
2. **Finish testing regression coverage:** keep the proven macOS staging workflow maintained,
   add the default-startup harness and unsupported nested-structure raw-editor fixture, and
   defer Linux/Windows test-root work until their platform-native bridges are planned.
3. **Tool catalog integrity:** implement the [tool-catalog integrity plan](plans/active/tool-catalog-integrity.md)
      so supported-tool documentation has explicit source/schema evidence, deterministic PR
      checks, and a monthly advisory review reminder. **Status:** Phases 0–3 shipped; Phase 4
       local acceptance verified; remaining items are two post-merge GitHub Actions
       manual-dispatch confirmations — immediate (fresh dispatch now) and future (stale-path
       re-dispatch after the next overdue window) (see the plan's Phase 4).

The durable sequence and architecture decisions are in the
[Structured Configuration Roadmap](plans/active/structured-configuration-roadmap.md).

### Project workspace labels

- [ ] Make project-scope sidebar entries distinguish their root
      (for example, `workspace — AGENTS.md`) instead of repeating only the tool/file name.
      Then consider user-editable project aliases stored in discovery preferences; preserve the
      canonical path for matching, handle duplicate names clearly, and add migration/widget
      coverage before exposing rename controls.

### Safe exploratory testing

- [ ] The token-free fixtures and
      macOS-only `--test-root` staging smoke now exercise automatic discovery, editing,
      backup, restore, and preferences without touching a real config. Next, add default-mode
      startup-regression coverage, an unsupported nested-structure raw-editor fixture, and
      documented sanitized-fixture intake rules. Compare isolated OS users and VMs for
      native-platform validation later; Docker is supplementary for Linux, not the primary
      desktop/macOS answer. Do not enable test-root mode on Linux or Windows until each has a
      platform-native containment design. (See
      [docs/testing-strategies.md](docs/testing-strategies.md) and the implementation
      [plan](plans/active/safe-testing-foundation.md), with test-root implementation
      details in [its focused plan](plans/active/test-root-containment.md)).

### Structured configuration presentation

- [ ] Expand parsers and UI models so supported
      configuration formats can present discovered rules, permissions, and settings as
      focused widgets/cards rather than only raw syntax. Start with tool-schema metadata
      and a single high-value read-only card; preserve a faithful raw-editor fallback for
      unsupported or ambiguous content. Enable editing only after lossless/minimal-patch
      fixture coverage, then add parser/UI tests per schema. (See gap analysis in
      [docs/research/config-structured-editing-gap.md](docs/research/config-structured-editing-gap.md)
      and [implementation roadmap](plans/active/structured-configuration-roadmap.md).)

- [ ] **Plain-language configuration help:** For the structured rule/permission UI, add
      contextual hover help that explains each setting in plain language and links to the
      owning tool's authoritative documentation. Design a versioned metadata source,
      ensure links are tool-specific and reviewable, and keep unknown settings visibly
      unclassified rather than inventing explanations.

### Tool catalog integrity acceptance follow-through

- [ ] Source-evidence matrix and
      automated review workflow are complete through Phase 3 (no-write scheduled/manual
      workflow: run summary + warning annotation). Remaining: manually dispatch
      `.github/workflows/catalog-advisory.yml` once after it lands on `default` to confirm
      the live summary path (`result=fresh` while the marker is current), and re-dispatch
      after the next overdue window to confirm the stale-date `::warning` path. See
      [plans/active/tool-catalog-integrity.md](plans/active/tool-catalog-integrity.md) Phase 4.

### macOS local execution follow-through

- [ ] Complete the remaining validation and follow-through in the
      [macOS local execution plan](plans/active/macos-local-execution.md). Keep the app
      source-build-only and unsandboxed for this cycle; do not broaden distribution scope
      before its ADR-directed review is complete.

### Agent-config discovery follow-through

- [ ] Review the deferred work in the [agent-config discovery plan](plans/active/agent-config-discovery.md)
      and promote only a bounded, current discovery slice when it is ready for implementation.

### Tool-support discovery candidates

- [ ] Select a bounded candidate from the [future-enhancements discovery inventory](plans/active/future_enhancements.md#discovery-expansion-candidates)
      only after verifying that it has a durable, user-editable configuration file and fits the
      app’s product scope.

## Follow-ups from Phase 5.5 (docs accuracy)

- [ ] Add a README screenshot or GIF to `assets/screenshots/` (blocked on user — an agent cannot capture a running Flutter desktop GUI). README currently shows a placeholder badge.

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

## Deferred from Phase 10 / CodeRabbit Hy3 review

- [ ] **Discovery `handleError` stack traces** — per-entry glob listing warnings
      now prefer `FileSystemException.path` when present; still record `$error`
      only (no stack). Consider logging `StackTrace` via the app logger
      (if/when one exists) for harder permission/IO failures.
- [ ] **Windows case-insensitivity tests** — non-glob matching uses `path.equals`
      (platform-aware); globs use `caseSensitive: !Platform.isWindows`. Add an
      injectable `caseInsensitive` override (like discovery caps) so CI on
      ubuntu can exercise both Windows behaviors without a Windows runner.
- [ ] **Copilot `config.json` write policy** — file is labeled managed CLI state
      (auth/plugins) but remains a writable `structuredConfig` target. Decide
      whether to warn, mark read-only in UI, or leave editable; track as a
      follow-up (pre-existing risk, not introduced by Phase 10).

## AI Agent Integration

- [ ] If we ever integrate AI agent calls directly into the app (e.g., for automated config fixes), ensure that any secret-bearing configuration files (like `models.json` or `kilo.jsonc`) have their API keys and sensitive environment variables redacted *before* the context is sent to the agents.

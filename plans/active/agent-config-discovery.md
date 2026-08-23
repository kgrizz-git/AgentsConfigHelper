# Plan: Agent Config Discovery

**Status:** active — discovery + Riverpod runtime integration shipped (PR #5); deferred work tracked below
**Created:** 2026-08-11
**Revised:** 2026-08-13
**Depends on:** completed parser, `BackupService`, and `ConfigService` work
**Followed by:** Phase 4 application state/UI shell and Phase 5 raw-editor work

## Goal

Replace the static Claude/Cursor sidebar with a reliable, cross-platform list of
configuration files discovered from known user locations, explicitly selected
project roots, and persisted user-added file paths. Every item must carry its
tool identity and format, so loading never relies on path-substring guessing.

This plan turns the completed path research into the runtime source of truth. It
does **not** make the editor a full schema editor for every agent.

## Verified current state

- `DiscoveryService` probes nine home-relative structured files but returns only
  `List<String>`. It has no project-root input, persistent manual paths, error
  reporting, or UI consumer.
- `MainShell` contains two literal sidebar paths. Its dirty-change and stale-load
  safeguards must remain intact when the sidebar becomes dynamic.
- `ConfigService` identifies tools with substring heuristics, while parser choice
  is extension-based.
- `ToolConfig` normalizes only flat `rules` and `permissions`; other settings are
  preserved in `rawSettings` but cannot yet be edited.
- The tool reference also lists Markdown instructions (`AGENTS.md`, `CLAUDE.md`,
  `.cursorrules`, and `.mdc` files). The app has no Markdown parser or raw-text
  editor, so presenting them as normal editable configs would be misleading.
- `docs/supported-tools.md` and `DiscoveryService.defaultRelativePaths` duplicate
  discovery data and can drift.

## Scope decisions

| Area | Decision |
| --- | --- |
| Runtime source of truth | A pure-Dart `ToolDescriptor` registry owns tool identity, fixed targets, display labels, and formats. |
| Documentation | `docs/supported-tools.md` remains explanatory; remove its duplicate detection list and link it to the registry. |
| V1 auto-discovery | Discover exact parser-supported JSON/JSONC, YAML, and TOML files, plus Markdown/text instruction documents and wildcard (`*`) targets. **Shipped (PR #5).** |
| Markdown, directories, globs | Markdown/text and wildcard instruction sources are now discovered in the sidebar, capped at 100 entries per glob target. **Shipped (PR #5).** |
| Project discovery | Scan only roots explicitly selected by the user. Never substitute process CWD for a selected root. |
| Manual additions | Persist explicit file paths and selected project roots in app-support storage. Never persist file contents. |
| Model scope | Retain narrow `ToolConfig` plus `rawSettings`; defer typed model/MCP/environment editors. |
| CLI integration | V1 is file-only: discovery must not invoke installed agent CLIs. |
| Icons | Map descriptor IDs to `IconData` in the UI, not in pure-Dart domain code. |

## Initial executable catalog

The first implementation must include these user-level structured targets in this
order. Confirm any changed path against its primary source before changing the
registry and record the version caveat in `.context/research/`.

| Tool ID | Display name | User-relative path | Format |
| --- | --- | --- | --- |
| `claudeCode` | Claude Code | `.claude/settings.json` | JSON |
| `codex` | Codex | `.codex/config.toml` | TOML |
| `opencode` | Opencode | `.config/opencode/opencode.json` | JSON/JSONC |
| `paseo` | Paseo | `.paseo/config.json` | JSON |
| `cursor` | Cursor | `.cursor/permissions.json` | JSON |
| `kiro` | Kiro | `.kiro/settings/permissions.yaml` | YAML |
| `devin` | Devin | `.config/devin/config.json` | JSON |
| `antigravity` | Antigravity | `.gemini/antigravity-cli/settings.json` | JSON |
| `agyAcp` | agy-acp | `.openab/agy-acp/sessions.json` | JSON |

The registry may also contain exact project-relative structured targets (for
example `.claude/settings.json`, `.codex/config.toml`,
`.opencode/opencode.json`, `paseo.json`, `.cursor/permissions.json`, and
`.devin/config.json`). Add a project target only after defining its supported
format and editable contract. Do not represent wildcard rule directories in this
phase.

## Target types and ownership

| File | Responsibility |
| --- | --- |
| `lib/models/tool_descriptor.dart` | Immutable `ToolId`, `ConfigLocationScope` (`user`, `project`, `manual`), `ConfigSourceKind` (`structuredConfig`, later `instructionDocument`), `ConfigTarget`, and `ToolDescriptor`. A target has an exact relative path and `ConfigFormat`. |
| `lib/catalog/tool_descriptor_registry.dart` | Unmodifiable descriptor list, lookup by ID, exact path matching, and deterministic display order. It must not import Flutter. |
| `lib/models/discovered_config.dart` | Immutable `DiscoveredConfig`: stable ID, normalized absolute `filePath`, nullable descriptor, scope, and source label. An unknown manual file is labelled `Unknown configuration`. |
| `lib/services/discovery_service.dart` | Filesystem probing only. Accepts home, project roots, and manual paths through a request object; returns records plus non-fatal warnings. |
| `lib/services/discovery_preferences_store.dart` | Persists versioned manual file paths and project roots in app-support storage. |
| `lib/services/config_service.dart` | Loads a descriptor-aware discovered record. Uses registry matching only for a manual path; remove `_guessToolNameFromPath` after migration. |
| `lib/state/` | Riverpod providers/controllers compose the store and discovery service. Widgets do not call the filesystem directly. |

Derive `DiscoveredConfig.id` from normalized absolute path and source kind, not
display name. This keeps duplicate configurations for one tool independently
selectable. Normalize with `path`, but do not resolve symlinks; that can fail or
change a user-visible path.

## Phase 0 — reconcile research and documentation

1. Create `.context/research/README.md` stating that it holds versioned raw
   discovery notes, while `docs/supported-tools.md` is the curated reference.
2. Add a dated note covering all nine catalog targets: primary URL, documentation
   date/version, user path, project candidates, supported format, custom
   environment overrides, and unresolved facts. Never include real config data
   or tokens.
3. Update `docs/supported-tools.md` to retain its per-tool tables but replace the
   numbered detection list with the explicit v1 boundary and registry reference.
   Clearly separate structured editable files from Markdown/instruction sources.
4. Record file-only v1 and raw-editor deferral in the plan changelog.

**Exit criteria:** no silent `TBD` catalog items; no docs claim that Markdown is
editable today; future maintainers can find path evidence.

## Phase 1 — introduce a single executable catalog

1. Add the descriptor and discovered-config models. Keep them immutable and
   value-comparable, consistent with `ToolConfig`.
2. Add the registry with the nine targets in catalog order. Each target must
   explicitly state its scope and format.
3. Define exact matching rules before implementation:
   - compare normalized platform paths;
   - exact target matches win over any fallback;
   - a project target is matched relative to its supplied root;
   - a manual file with a supported but unknown path loads as unknown;
   - an unsupported extension returns a user-facing validation error, not a
     silent JSON parse attempt.
4. Add a descriptor-aware `ConfigService` load entry point. Migrate callers and
   tests to it, then delete `_guessToolNameFromPath`.
5. Keep a narrow manual-path helper only for the add-file flow; it must first ask
   the registry whether the normalized path is known.

**Exit criteria:** production code has no second hardcoded default-path list or
substring-based tool-name chain, and each discovered item can be rendered and
loaded without extra path inference.

## Phase 2 — implement deterministic, safe discovery

1. Replace `discoverConfigs(): Future<List<String>>` with
   `discover(DiscoveryRequest): Future<DiscoveryResult>` (or an equivalent named
   request/result API). The request supplies home, ordered project roots, and
   manual paths. Keep environment/home injection at the service boundary.
2. Probe exact registry targets only:
   - join user targets to home;
   - join project targets once to every selected root;
   - check manual entries as files only, never recursive directories.
3. Normalize then deduplicate by absolute path, retaining first occurrence.
   Present catalog user items first, then each project root in selected order
   with catalog order inside it, then manual files in stored order.
4. Missing files are normal. A failed stat/existence/readability check becomes a
   per-path warning in the result; it must not hide successfully found entries.
5. Never read file content during discovery. Parsing happens only after explicit
   selection. Keep strict home resolution: unresolved `~` throws the existing
   `FileSystemException` and never falls back to CWD.

**Exit criteria:** typed discovery is ordered, deduplicated, bounded, and
resilient to one bad source.

## Phase 3 — persist user-managed sources

1. Implement `DiscoveryPreferencesStore` behind a small interface so tests can
   use a temporary directory or fake. Persist versioned JSON:

   ```json
   {
     "version": 1,
     "manualFilePaths": ["/absolute/path/config.json"],
     "projectRoots": ["/absolute/path/project"]
   }
   ```

2. Reads must tolerate: no file, malformed JSON, wrong top-level shape,
   non-string entries, duplicates, unknown future keys, and paths that no longer
   exist. Preserve valid entries where possible and return recoverable warnings.
3. Normalize and deduplicate before writing. Write a temporary sibling then
   replace the preferences file; ensure the parent exists. Never store config
   contents, parsed settings, or backups.
4. Provide controller operations: add/remove manual file, add/remove project
   root, and refresh. Removal deletes only the app's reference, never a user file
   or directory.
5. Use a desktop-compatible file/directory selector in the eventual UI. If a
   package is added, isolate it in a UI helper; services remain platform-neutral.
   A typed-path fallback must validate before persisting.

**Exit criteria:** manual files/project roots survive restart, corrupt preferences
cannot brick startup, and all removal is non-destructive.

## Phase 4 — add state and wire the shell

1. Add `flutter_riverpod`; wrap the app in `ProviderScope` in `main.dart`.
   Provide `ConfigService`, `DiscoveryService`, preferences store, and a
   `DiscoveryController`. Construct filesystem services once at the app boundary,
   never during widget builds.
2. On startup, the controller loads preferences and runs discovery. Its state
   distinguishes initial loading, populated, empty, and populated-with-warnings.
   Protect refreshes with a generation/cancellation guard so stale scans cannot
   overwrite newer results.
3. Replace both literal `SidebarItem`s in `MainShell` with discovered records.
   Map `ToolId` to `IconData` in the UI and use a generic file icon for unknown
   manual entries. Show display name plus filename/scope to distinguish configs
   from the same tool.
4. Track selection by `DiscoveredConfig.id`, not `ToolConfig.toolName`. Add
   Refresh, Add configuration file, and Add project root controls. Only
   user-managed sources expose a remove control.
5. Preserve current editor safety:
   - selection with unsaved changes requires existing discard confirmation;
   - cancel leaves editor and selection unchanged;
   - only newest config load updates active config/error/loading state;
   - refresh never auto-loads or discards edits;
   - if the active source disappears, retain its loaded editor and show a small
     missing-source state until the next selection.
6. Add a no-configurations empty state with Refresh/Add controls. Warnings must
   not replace valid results with an empty state.

**Exit criteria:** a normal launch displays actual local config files, sources
can be safely managed, multiple configs for one tool work, and no static sidebar
path remains.

## Phase 5 — status

Items 1, 2, and 4 shipped in PR #5. Item 3 (typed editors) and line-level
diffing remain deferred (see `plans/archive/phase_5_editors.md`).

1. **Shipped (PR #5).** Raw-text editor/save contract that preserves original
   content and uses backup-before-write.
2. **Shipped (PR #5).** `instructionDocument` discovery for `AGENTS.md`,
   `CLAUDE.md`, `.cursorrules`, `.cursor/rules/*.mdc`, and related text sources,
   with a 100-entry cap per glob target and no recursive arbitrary-tree scans.
3. **Deferred.** Typed model/environment/MCP/nested-permission editors — only
   with documented semantics and parser round-trip coverage.
4. **Shipped (PR #5).** History/Backups remains separate from discovery; it may
   use a selected file path but must not mutate discovery preferences.

## Test plan

Use synthetic temporary files/directories only. Never use the real home directory
or real agent configuration files in tests.

### Catalog and model tests

- Assert exactly nine user descriptors, their order, labels, paths, and formats.
- Assert immutable/value semantics.
- Assert known user/project matches select the correct ID and look-alike paths
  (such as `mycodexnotes`) do not match.
- Assert unknown supported manual files become unknown records and unsupported
  extensions return the defined validation error.

### Discovery tests

- Discover mixed user, project, and manual sources; assert metadata, normalized
  absolute paths, and exact ordering.
- Assert all missing defaults yield a successful empty result.
- Assert a source reachable from more than one input appears once with the
  documented first-source precedence.
- Cover spaces, `..` segments, and platform separators.
- Assert a missing root, unreadable source, or malformed manual path produces a
  warning without hiding other results.
- Assert no project-root input means no project scan and CWD is never implicit.
- Retain the unresolved-home regression: `~` without a home throws and never
  reads/writes relative to CWD.

### Preferences tests

- Round-trip version 1 data in a temporary app-support directory.
- Verify stable normalization/de-duplication and non-destructive removal.
- Verify missing, malformed, partial, and future-version JSON produces usable
  state plus warnings rather than a startup exception.
- Verify an invalid temporary write cannot replace an existing valid file.

### Config-service regression tests

- Loading a discovered record supplies its descriptor display name for JSON, YAML,
  and TOML.
- Retain backup, parser selection, JSONC preservation, and tilde-resolution
  coverage.
- Assert known descriptor metadata wins over any manual fallback inference.

### Widget/integration tests

- Inject fake providers/services; never touch real filesystem or file selectors.
- Cover initial loading, populated sidebar, empty state, warning state, and
  refresh.
- Verify duplicate-tool entries are distinct and active state follows record ID.
- Verify add/remove updates controller state without deleting the target file.
- Retain dirty-editor cancel/discard coverage; add coverage that refresh neither
  prompts for discard nor replaces the active editor.
- Verify stale discovery and stale config-load completions cannot overwrite later
  requests/selections.

## Validation and completion

Run after every implementation phase and before completion:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Perform a desktop smoke test on every available target platform: empty home,
synthetic discovered files, persisted add/remove, selected project root, duplicate
sources, and a dirty editor followed by refresh/selection.

Mark the plan complete only when the registry is the sole runtime default-path
source; discovery returns typed deterministic records; the shell has no hardcoded
sidebar items; preferences are safe and non-destructive; docs match the v1
boundary; targeted tests exist; and all validation commands pass.

## Changelog

- **2026-08-13:** Research stage reclassified as complete; runtime integration
  made active. Chose a declarative registry, typed discovery results, explicit
  project roots, persisted manual paths, and Riverpod state. Confirmed file-only
  v1; Markdown/raw editing and richer typed schemas remain deferred.

# Plan: Config Write Safety

Last reviewed: 2026-11-23
Date: 2026-11-23
Author: maintainers
Status: active
Tracking: `TO_DO.md` → Config write safety

## Goal

Make every write to a user's real configuration file **fail closed**: never silently
delete data the editor cannot represent, never reactivate a shadowed value, never write
content that is invalid for the declared format, and never leave the live file truncated. The safety
features must also be truthful — the review dialog shows the bytes that will be written,
and a stale save is detected rather than silently discarding someone else's edit.

## Background

An independent data-safety audit of the read/write paths produced seven findings. The four
most serious were verified directly against the code:

**Finding 1 — Duplicate JSON keys can reactivate a hidden permission.** The serializer maps
every `rules`/`permissions` property into one variable, so the *last* duplicate wins in the
editor. Clearing the visible list calls `deleteNode` on that last property only, leaving the
earlier duplicate active. Removing a permission can re-enable an older, more permissive one.
`json_config_parser.dart:175-180, 230-255`.

**Finding 2 — Non-list shapes are deleted.** `extractStringList` returns `[]` for a
non-list, and JSON and YAML treat an empty result as "remove the key". A nested or scalar
`rules`/`permissions` value disappears on an unrelated structured save. Heterogeneous lists
lose non-string entries through `whereType<String>()`. `config_parser.dart:95-100`,
`json_config_parser.dart:166-173`, `yaml_config_parser.dart:119-129`. TOML already preserves
non-list shapes (`toml_config_parser.dart:62-85`).

**Finding 3 — Config writes truncate the live file.** `ConfigService` writes through
`FileOperations.writeText`, which calls `File.writeAsString` — truncating in place. A
crash, disk-full, or I/O error leaves the real config empty or partial.
`writeTextAtomically` exists but is used only for window bounds and discovery preferences.
Restores use `writeBytes`/`copyFile`, which are non-atomic in production.
`config_service.dart:116, 273`, `file_operations.dart:75-85`,
`backup_service.dart:87-94`.

**Finding 4 — Claude Code's strict JSON is validated as JSONC.** Every `.json` falls back
to the JSONC cleaner after a strict decode failure, regardless of the owning tool. Claude
Code documents its settings files as strict JSON, so the app can report a successful save
that the tool then rejects.
`json_config_parser.dart:53-68`.

Three further findings are in scope:

**Finding 5 — "Review Changes" does not show the serialized result.** A structured-only
save shows list diffs; a combined raw edit shows the raw buffer, not the merge output.
Serializer-induced deletions are invisible at confirmation time.
`structured_save_flow.dart:180-213`.

**Finding 6 — Raw saves overwrite external edits.** `saveConfig` re-reads the file before
serializing, but `saveRawConfig` writes the editor buffer without comparing it to disk.
`config_service.dart:192-274`.

**Finding 7 — A test writes into the real home directory.**
`config_service_test.dart:454-479`.

Two additional defects were found while reviewing this plan and are in scope:

**Finding 8 — A combined raw+structured save reverts the untouched field.** When either
structured field differs from the baseline, `saveRawConfig` overlays **both** fields onto
the raw parse (`config_service.dart:220-247`). Editing `permissions` structurally while
editing `rules` in the raw buffer silently restores the baseline `rules`.

**Finding 9 — Structured saves write before validating the final bytes.** `saveConfig`
serializes, backs up, writes, and only then re-parses (`config_service.dart:94-123`). The
JSON in-place serializer also always runs `JsoncCleaner.clean`, whatever the format
(`json_config_parser.dart:155-162`), so a strict target can be written as JSONC and fail
validation only afterwards.

## Scope and boundaries

### In scope

- Atomic, failure-safe writes for structured saves, raw saves, restores, **and backups**.
- Preserving file modes across an atomic replace on POSIX, applied before content is written.
- Symlink-target resolution so an atomic replace updates the target, not the link.
- Per-field ownership: only fields the user actually changed may be rewritten.
- Lossless handling of non-list and mixed-list `rules`/`permissions` values.
- Duplicate-key detection against the source being written.
- Format-accurate JSON strictness, driven by the catalog, with pre-write validation.
- A raw recovery path for existing files that are no longer valid for their tool.
- A preview carrying the exact bytes and source digest that the writer consumes.
- External-edit detection at load, preview, and immediately before replacement.
- Test isolation from the real home directory.

### Out of scope

- Rewriting the parsers or the `ToolConfig` model wholesale.
- New formats or new tools.
- Backup retention and naming policy.
- Exports (`lib/reports/report_save_service.dart` writes user-chosen new files directly and
  is deliberately not routed through the config write path) and report generation.
- The Flutter 3.50 upgrade (separate branch) and the windowing migration.

## Design principles

- **Fail closed.** A structured edit that cannot be represented without loss is refused
  with an actionable message. Raw editing remains available for shapes the structured
  editor does not model.
- **Per-field ownership.** Dirty state is per field, derived from the loaded baseline.
  Untouched fields retain their exact source node, including unsupported shapes and
  duplicates.
- **Validate the bytes.** The final serialized bytes are parsed for the target format
  *before* any backup or write. Nothing reaches disk that the tool would reject.
- **Atomic always.** There is no non-atomic fallback. If atomic replacement or metadata
  preservation fails, the save aborts and the original is untouched.
- **Preview is write.** A save consumes an immutable preview result; it never recomputes
  the output behind the user's back.

## Pull-request map

Each row is an independent PR. The branch is stacked on the Flutter 3.50.1 upgrade while
that PR is unmerged and will be rebased onto `main` before review.

| PR | Branch | Contents |
| --- | --- | --- |
| 1 | `fix/config-atomic-writes` | Atomic text/byte writes, mode preservation, symlink resolution, atomic backups, restore path, home-directory test isolation |
| 2 | `fix/config-lossless-fields` | Per-field dirty state, source-aware serialization, duplicate/shape refusal, combined-merge fix |
| 3 | `fix/config-strict-json` | Catalog-driven strictness, pre-write validation of final bytes, raw recovery for nonconforming files |
| 4 | `fix/config-save-preview` | Immutable preview carried into the writer, conflict detection at load/preview/replace |

## Phase 1 — Atomic writes (PR 1)

### Phase 1 changes

- Add `writeBytesAtomically` to `FileOperations`; make `writeTextAtomically` the only
  config write path.
- Route `saveConfig`, `saveRawConfig`, `restoreBackup`, and `writeRestoredFile` through the
  atomic paths. No write path keeps the old truncating behaviour.
- **No non-atomic fallback.** If the atomic path or metadata preservation fails, throw and
  leave the original untouched.
- Secure temporary file: exclusively created, never following a symlink, in the resolved
  target's directory, removed on every failure path.
- **Apply the destination mode before writing content.** On POSIX, open the temporary
  descriptor first, then apply the mode while it is open, then write: opening *after*
  applying a mode without owner-write (for example `0400`) would fail, and writing through
  an already-open descriptor is not re-checked. New files default to `0600` so a first save
  never widens access. See "Deviations and limitations" for the `fchmod` caveat.
- **Resolve symlink targets first**: write the temporary file in the target's directory and
  rename onto the resolved target so the link survives. Cover a link, a relative link, and
  a link to a missing target. A **dangling link is refused** with a clear error telling the
  user to create the target first; the app does not create configuration files through a
  link whose target does not exist. The test asserts refusal and no filesystem change.
- Make **backup creation atomic**: copy into a temporary file in the backup directory,
  flush, then publish by rename. A failed or partial copy is removed and never appears in
  `listBackups`. Backup temporary files use the same restrictive creation and inherit the
  source's mode before content is written, because backups carry the same secrets.
- Reuse the macOS test-root bridge's existing atomic primitive rather than adding a new
  operation. `AppDelegate.swift:221-266` already does `openat(O_EXCL|O_NOFOLLOW)` → `fsync`
  → `renameat` → parent `fsync`, and its `copyFile` (`:269-279`) uses it. The bridge stats
  the destination itself and applies mode internally, so no new channel parameter is
  needed; only mode preservation is added.
- Windows: use an operating-system atomic replacement primitive (`MoveFileExW` with
  `MOVEFILE_REPLACE_EXISTING`, or `ReplaceFileW`). If an atomic replace cannot be
  completed — for example because the file has an open handle — abort and leave the
  original untouched. **Never delete the live file to make replacement easier**: that
  creates a window where the original is gone and a failed rename destroys it.
- Fix the home-directory test to use an injected temporary home resolver.

### Phase 1 checks

- A failed write leaves the original bytes intact.
- A destination with mode `0400` is updated successfully and keeps `0400`.
- A newly created config defaults to `0600`.
- A successful save through a symlink updates the target; the link still exists.
- `0600` remains `0600` after a save; the temporary file is never wider than the
  destination.
- A failed mode application aborts the save with no change to the original.
- Backup creation that cannot complete leaves no `.bak` in `listBackups`.
- Test-root workflow contract tests still pass; the native bridge is exercised.
- Standard gates: format, `flutter analyze --fatal-infos`, metrics, tests, coverage gate,
  macOS release build.

## Phase 2 — Per-field lossless editing (PR 2)

### Phase 2 changes

- Introduce a per-field save model: for each of `rules` and `permissions`, record whether
  the editor value differs from the **loaded baseline projection** (not from the lossy
  source value). A mixed-list source projects to its strings, so source comparison cannot
  detect intent; baseline comparison can.
- Name the plumbing: a `StructuredField` enum (`rules`, `permissions`), a `FieldEditMask`
  carrying the dirty set computed once by `ConfigService` from `config.originalContent`, and
  a serialization request that carries the mask alongside the actual source. `ToolConfig`
  needs no new fields, but the current serializer signature (`ToolConfig` +
  `originalContent`) cannot express ownership. If a structured save cannot obtain a
  parseable baseline, it refuses rather than guessing which fields are dirty.
- Derive the mask when a caller omits it: `ConfigParser.resolveEdits` parses the baseline
  source and compares the projection, so direct serializer callers are safe too. A
  whole-document rewrite restores untouched owned fields from the source and refuses
  unsupported shapes; a non-object root has no owned fields to lose.
- Serialize against the **actual source being written**: current disk content for
  `saveConfig`, the raw buffer for a combined save.
- Overlay **only dirty fields**. Every untouched field keeps its exact source node.
- Detect duplicates and unsupported shapes **on the serialization source**, not only during
  the initial parse, because `saveConfig` re-reads the file immediately before serializing.
- A dirty field whose current source is duplicated, non-list, or mixed-list causes a
  refusal with an actionable message. An untouched field of that shape is preserved
  verbatim.
- Fix Finding 8: a combined save must overlay only the structured field that is actually
  dirty, so a raw edit to the other field survives.
- Refuse a combined save when the raw buffer and the structured editor both changed the
  **same** field to different values. Per-field ownership cannot choose between them, and
  silently preferring either one drops the user's other edit.
- TOML has no in-place path: it validates and rebuilds from the loaded `rawSettings`, not
  from the current disk content. A disk shape that changed externally is Phase 4's
  responsibility; TOML's refusal does not cover it.
- Raw-only saves remain allowed: they write the user's exact bytes and never invoke a
  serializer.
- `allowRewrite` must **not** bypass these protections. The whole-document fallback starts
  from a collapsed `rawSettings` map, so ambiguous or unrepresentable owned fields must
  block the rewrite; the fallback warning must name data loss, not only comments and
  formatting.
- Share one helper across JSON and YAML so the policy cannot drift.
- YAML note: `package:yaml` already **rejects** duplicate mapping keys with
  `YamlException: Duplicate mapping key`, which `YamlConfigParser` surfaces as a parse
  error, so YAML has no last-wins hole. Add a regression test locking that behaviour rather
  than new duplicate-handling code.

### Phase 2 checks

- Clearing a duplicated `permissions` key is refused; no bytes are written.
- An object/scalar `rules` survives a permissions-only save byte-for-byte.
- `rules: ["read", 42]` is refused when edited and preserved when untouched.
- A combined save that edits `rules` raw and `permissions` structurally keeps both edits.
- `allowRewrite` cannot collapse an ambiguous or unsupported field.
- YAML duplicate keys fail to load with a parse error (regression test).
- Standard gates.

## Phase 3 — Format-accurate strictness (PR 3)

### Phase 3 changes

- Define `ConfigFormat.json` as strict and `ConfigFormat.jsonc` as comments/trailing commas
  allowed. The JSONC cleaner runs **only** for `jsonc`, including inside the in-place
  serializer (`json_config_parser.dart:155-162`).
- Validate the **final serialized bytes for the target format before any backup or write**,
  on all three paths: structured save, raw save, and combined merge. Never write first and
  re-parse afterwards.
- Audit every `.json` target in `lib/catalog/tool_descriptor_registry.dart` against the
  owning tool's documentation and reclassify those that legitimately allow comments
  (VS Code-derived settings are the expected cases). Default to strict when documentation
  is ambiguous.
- Manual `.json` paths default to strict; document that behaviour.
- Provide a recovery path for files that no longer conform (existing JSONC content, or a
  reclassified target): load failure must offer a raw editor against the file so the user
  can correct it, and saving that raw content is validated strictly before writing. The
  structured editor must not be offered for a file that cannot be parsed strictly. This
  path already exists (`RecoveryAction.openRawEditor` reads the file without parsing and
  sets `rawRecoveryMode`); Phase 3 only needs to keep it and prove the save validates.
- Catalog audit result — every `.json` target was checked; strict remains the default and
  each exception cites a vendor doc:

  | Targets | Format | Basis |
  | --- | --- | --- |
  | Claude `settings.json` | strict | Claude documents strict JSON |
  | Cursor `permissions.json` | JSONC | Cursor documents comments there |
  | Cursor IDE `settings.json` | JSONC | VS Code documents comments and trailing commas in `settings.json`, which Cursor inherits |
  | Antigravity CLI/IDE/App `settings.json` | strict | Catalog docs classify them JSON; the IDE/App paths are not vendor-documented |
  | Devin `config.json` | JSONC | Devin documents JSON-with-comments |
  | Opencode, Copilot CLI/repo settings, Kilo `.jsonc` | JSONC | Documented comments |
  | Paseo, Agy-ACP sessions, Kilo `.json`, Cline, LM Studio, Copilot `config.json`/`mcp-config.json` | strict | Documented JSON |

- `rawContentParsedAsJsonc` and `currentSourceParsedAsJsonc` return false for strict
  targets by design: JSONC syntax is rejected outright, so there is no fallback to
  disclose. The structured-save JSONC notice therefore applies only to `jsonc` targets.
- Update `docs/supported-tools.md` where a classification changes.

### Phase 3 checks

- A comment or trailing comma in a strict target is rejected before the backup is created
  and before any write, with a clear message.
- The same content is accepted for a `jsonc` target.
- A structured save against a strict target with a comment-containing source produces no
  bytes on disk and a validation error (regression for Finding 9).
- A nonconforming existing file offers raw recovery and can be corrected, then saves.
- Catalog tests cover every reclassified target.
- Standard gates.

## Phase 4 — Immutable preview and conflict detection (PR 4)

### Phase 4 changes

- Introduce a `SavePreview` carrying: the exact content to write, the source content and
  existence it was computed from, the parsed result, and the fallback flag.
- `previewSaveConfig`/`previewSaveRaw` compute it without writing; `commitSavePreview`
  consumes that result and never re-serializes. The commit sink is the atomic text/byte
  write, encoding once.
- Before replacement, verify the current source still matches the captured content and
  existence. A preview also refuses when the source no longer matches
  `config.originalContent`, so an edit between load and Review Changes is surfaced instead
  of being absorbed as the new baseline. On mismatch, throw `SaveConflictException` with
  the current content. Reload recomputes from the new source. Deliberate overwrite
  re-renders the preview against the current source and displays the exact merged result
  (untouched external fields follow the format's serializer) before a second confirmation;
  the current source is still captured as the commit guard. Neither path reuses stale
  bytes.
- The preview compares source existence as well as content. Load paths record
  `originalFileExisted`, so deleting a loaded empty or whitespace-only file — or
  externally creating an empty file where a new file was expected — is a conflict.
- Review Changes opens only with a displayed preview when the shell supplies one. A
  stale-load conflict is prompted before the modal; Overwrite recomputes the preview and
  displays it, and any preview failure (including a failed re-preview) writes nothing.
- Render the preview in Review Changes as a real diff against the loaded content, under
  "Serialized result", in addition to the structured list diffs. The shell supplies a
  `previewSaveContent` callback; recovery/raw-only paths use the same preview object. The
  preview is computed with the rewrite allowed so a fallback rewrite is displayed before
  its separate consent, and a conflict overwrite reopens Review Changes with a fresh
  preview before a second confirmation; a one-shot overwrite consent covers only that
  save attempt.
- Document the residual race: compare-then-replace cannot be a hard guarantee against a
  non-cooperating external writer with portable Dart. Perform a final source check
  immediately before replacement to narrow the window, and state that the guarantee is
  best-effort rather than absolute.

### Phase 4 checks

- Preview bytes equal written bytes (assert on the same byte sequence).
- An external edit between preview and confirmation produces a conflict for both raw and
  structured saves.
- Reload and deliberate-overwrite both regenerate a preview; overwrite cannot reuse stale
  bytes computed against a superseded source.
- A load-to-preview external edit produces a conflict instead of becoming the new
  baseline, and both the fallback rewrite and conflict-overwrite outputs are displayed
  before their writes.
- Deleting a loaded empty file and external creation of an empty file both conflict; an
  explicit new-file save still succeeds. A failed preview or failed overwrite re-preview
  writes no bytes.
- External file creation and deletion are handled, not only modification.
- The structured-save preview test uses an allowed edit; a lossy/refused save asserts zero
  bytes written (Phase 2 policy).
- Standard gates.

## Check matrix

| Check | P1 | P2 | P3 | P4 |
| --- | --- | --- | --- | --- |
| New regression test fails before fix | yes | yes | yes | yes |
| No non-atomic config save/restore/backup path (reports excluded) | yes | yes | yes | yes |
| `dart format --output=none --set-exit-if-changed .` | yes | yes | yes | yes |
| `flutter analyze --fatal-infos` | yes | yes | yes | yes |
| `dart_code_linter` metrics | yes | yes | yes | yes |
| `flutter test --coverage` + 80% gate | yes | yes | yes | yes |
| macOS release build | yes | yes | yes | yes |
| Linux + Windows CI builds | CI | CI | CI | CI |
| Docs updated (`docs/supported-tools.md`) | — | — | yes | — |

## Deviations and limitations

- **No `fchmod` in `dart:io`.** The POSIX mode is applied by path with `chmod` while the
  exclusive, PID-and-timestamp-named temporary descriptor is open, and before content is
  written.
  A native/FFI `fchmod` would remove the remaining path-based window and is recorded as a
  follow-up rather than claimed here.
- **No directory `fsync` in `dart:io`.** File content is flushed before the rename, but the
  rename itself is not durably synced, so a power loss can still lose the update. The macOS
  test-root bridge does fsync the parent directory.
- **Test-root symlink policy.** The production path resolves a symlink and updates its
  target. The macOS test-root bridge refuses any symlink leaf as a containment measure.
  This divergence is deliberate: the disposable test root never follows links, so symlink
  saves are verified only against the production implementation.
- **Windows replacement.** Dart's `File.rename` is the platform replace primitive; there is
  no retry and no delete-then-rename. A locked destination aborts the save and leaves the
  original untouched. Windows is build-only in CI, so this is verified by build, not by a
  runtime test.
- **New files default to `0600`.** Config content can carry secrets; a first save is never
  wider than owner-only.
- **Raw-only fallback with an unparseable baseline.** `saveRawConfig` writes the raw buffer
  verbatim when `config.originalContent` cannot be parsed. The structured editor is
  unavailable for such files (`hasUsableBaseline` is false), so this is a raw save by
  construction; a caller that supplies structured values anyway must not expect them to be
  merged.
- **YAML alias structure.** A whole-document rewrite resolves anchors and aliases into plain
  values: the values survive, the alias structure does not. In-place updates are used
  whenever `YamlEditor` can handle the shape.
- **TOML is not source-aware.** It always rebuilds from the loaded `rawSettings`; external
  disk shapes are Phase 4's responsibility.

## Risks and open questions

1. **Metadata beyond mode.** Atomic replacement can change ownership, ACLs, extended
   attributes, and hard-link relationships. The plan preserves POSIX mode and documents the
   rest as a known limitation; widening the contract needs platform-specific work.
2. **Time-of-check/time-of-use.** A non-cooperating writer can still win between a final
   source check and `rename`. The plan narrows the window and states the residual rather
   than claiming an absolute guarantee.
3. **Catalog classification is research.** A wrong `jsonc` classification writes a file the
   tool rejects; a wrong strict classification blocks a legitimate save. Default strict, and
   cite the vendor doc for each reclassification.
4. **Combined raw+structured semantics.** Per-field dirty state is the only correct model;
   a global "any structured change" flag is what produced Finding 8.
5. **Windows replacement semantics.** `rename` over an existing or open file differs from
   POSIX; the plan requires a defined retry/replace sequence, never a truncating fallback.
6. **Concurrent instances.** Two app instances remain last-writer-wins; the Phase 4 check is
   best-effort detection, not locking.
7. **Strictness migration.** Users with commented `settings.json` files lose structured
   editing until they fix the file; the raw recovery path keeps them unblocked.

## Acceptance criteria

- [ ] No config save, restore, or backup publishes a partially written file.
- [ ] If atomic replacement or mode preservation fails, the original is unchanged.
- [ ] File modes are preserved on POSIX; the temporary file is never wider than the target.
- [ ] A symlinked config is updated through the link, not replaced by a regular file.
- [ ] Only fields the user changed are rewritten; untouched fields are byte-identical, and a
      structured save with an unparseable baseline is refused.
- [ ] Clearing a duplicated key never deletes only one duplicate.
- [ ] Non-list and mixed-list values are preserved or refused, never silently deleted.
- [ ] A combined raw+structured save preserves both edits.
- [ ] Final serialized bytes are validated for the target format before any backup or write.
- [ ] Strict targets reject comments; JSONC targets accept them; nonconforming files have a
      raw recovery path.
- [ ] The review dialog shows the exact bytes that will be written, and the writer commits
      those bytes without re-encoding.
- [ ] External edits are checked for at load, at preview, and immediately before
      replacement, with reload and deliberate overwrite both supported and re-previewed.
- [ ] Config-service tests write only inside their temporary root.
- [ ] All CI jobs green.

## Completion steps

Archive this plan as the final commit on the last phase branch, remove its `TO_DO.md` entry
at the same time, and record the user-visible behaviour changes (write safety, strict-JSON
classification, raw recovery) in `CHANGELOG.md` with developer detail in `CHANGELOG.dev.md`.

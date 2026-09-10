# Config Overview Report

Promotes the `TO_DO.md` items **Config reports and copies** and
**HTML (or other) config tree with links** into an implementable slice.

## Goal

Give users a single overview of every discovered/known config, permissions,
and rules file — as a tree grouped by tool, with a table of contents and
clickable links — in both HTML and Markdown, previewable in the app and
savable to disk so files can be opened in the editor of their choice.
Modern and sleek styling; no fancy functionality.

## Non-goals

- No file contents embedded in the report (listing + metadata only).
- No export bundle / zip of configs (the sibling `Config reports and copies`
  item covers copies; this plan is the read-only overview).
- No in-app editing from the report (links open the external editor or the
  app's existing editor tab — viewing only from here).
- No live refresh / file watching; the report is a generated snapshot with a
  "generated at" timestamp.

## Design

### Report model (pure Dart, testable)

New `lib/reports/config_overview_report.dart` (or `lib/services/` if it fits
better — decide at implementation):

- `ConfigOverviewEntry`: tool id + display name, file path, kind badge
  (`config` / `permissions` / `rules` / `other`), format (`JSON`, `TOML`,
  `YAML`, `Markdown`, `plain`), scope (`user` / `project` / `managed`),
  `secretBearing` flag, `missing` flag for known-but-absent paths.
- `buildOverviewModel(discovery, catalog)`: assemble from
  `DiscoveryService` results + the tool catalog, so managed paths that have
  not been discovered yet still appear flagged as missing and unlinked
  (confirmed: show, don't hide).
- Kind classification reuses the schema adapters / catalog metadata where
  available; unknown files fall back to `other` with the raw-editor path.
  Manually-added paths with no catalog match group under a trailing
  `Other` section (after all catalog tools, sorted by path).
- `secretBearing` sourcing (Chunk 1 must add this, not hard-code it): true
  when the basename matches a static sensitive-name pattern (`token`,
  `secret`, `credential`, `auth`, `private-key`, `.env`, …) OR the tool is
  in an explicit `toolsWithSecretBearingConfigs` set added to the tool
  registry; default false. Golden fixtures cover both a pattern hit and a
  registry hit.

### Builders (pure functions, golden-tested)

- `buildMarkdownReport(model)`: `#` title + generated-at stamp, ToC with
  anchor links per tool, one `##` section per tool with a nested list;
  each file row: kind badge (text), relative path as `file:` link, format
  and scope in muted text. Secret-bearing files get a `⚠ secrets` marker.
- `buildHtmlReport(model)`: single self-contained file, inline CSS only, no
  external assets, no JS, no `<base>`, no external `<link>` elements, no
  resource hints (`preconnect`/`prefetch`/etc.). Clean sans-serif, sticky
  ToC sidebar (collapses to top-nav on narrow widths), per-tool sections,
  kind badges as pills, `file:` links per row. Must render identically
  offline from disk.
- Shared ordering: tools in catalog order, files sorted by scope then path;
  the `Other` group always comes last.
- Escaping: no new package needed — use `dart:convert`'s `HtmlEscape`
  (`HtmlEscapeMode.element` for text nodes, `.attribute` for attribute
  values) for display names/paths in HTML output.
- Link construction: build `file:` URIs with `Uri.file(path).toString()`
  so separators and triple-slash form are correct per platform, then
  percent-encoding is handled by `Uri`. In HTML each row is
  `<a href="<encoded URI>"><code><readable path></code></a>` — no JS means
  no clipboard in the static file, so copy-path stays an in-app-screen
  action only. In Markdown each row keeps the plain readable path as text
   plus a `file:`-scheme link labeled with the readable path; note the
   limitation that `file:` links are clickable in VS Code but stripped by
   renderers like GitHub — acceptable since the `.md` is for local use.
- Missing-path rows render unlinked plain-text paths but still carry the
  kind badge and the secrets warning where applicable (golden fixture must
  include a missing row with a secrets badge).

### Screen + preview

- New `Overview` / `Report` destination in the main shell. `MainShell` is a
  two-pane `MultiSplitView` (sidebar list + content pane, selection via
  `_activeConfigId` in `lib/screens/main_shell.dart`): expose Overview as a
  toolbar button in the sidebar header that sets a dedicated
  `_showingOverview` flag (do not overload `_activeConfigId`), rendering
  `ConfigOverviewScreen` in the right pane instead of `ConfigEditor` while
  set.
- Preview renders the Markdown via `flutter_markdown_plus: ^1.0.12` (new
  dependency; note `flutter_markdown` itself is discontinued — use the
  maintained fork). Wire its `onTapLink` to `url_launcher` (already a
  dependency) so `file:` links work in the preview. No in-app HTML
  renderer — "Open in browser" hands the saved `.html` to the OS.
- Buttons: `Save .md`, `Save .html`, per-row `Open in editor` (default app
  for the extension via `url_launcher`) and per-row `Copy path`. "Open"
  strictly means launch-with-default-app; there is no reveal-in-file-manager
  in v1 (the existing `lib/utils/open_directory.dart` only handles
  directories — a file-reveal helper is follow-up material, not this plan).
- Save flow uses a native save dialog via `file_selector: ^1.1.0`
  (confirmed: dialog, not an automatic location). `file_selector` is a
  federated native plugin (not pure Dart): no macOS entitlement changes are
  expected since this app ships unsandboxed per
  `docs/adr/ADR-002-macos-file-access.md`, but Chunk 3 must verify the save
  dialog works in the release build on macOS. Keep the builder layer
  decoupled from the dialog so save-path tests run against test-root
  fixtures without UI. The dialog call itself sits behind a thin injectable
  seam: tests bypass the native dialog (which cannot appear on headless CI)
  and exercise the write-bytes-to-path function plus the dialog-cancel path.

### Secrets

- The report never embeds file contents or values — metadata only — so the
  blast radius is paths, not secrets. Secret-bearing rows carry a warning
  badge; both formats start with a short header noting the report lists
  paths only and that linked files may contain secrets. This satisfies the
  redact-before-it-leaves-the-machine constraint structurally.

### Styling

- Light + dark via `prefers-color-scheme` in the HTML; Markdown stays plain
  (rendered by whatever viewer the user prefers). One small inline
  stylesheet; no frameworks, no JS.

## Chunks

1. **Model + builders + unit tests.** `ConfigOverviewEntry`, model assembly
   from discovery/catalog fixtures, both builders; text-snapshot assertions
   (string-equality against checked-in expected outputs under
   `test/fixtures/` — no pixel goldens, no new test infrastructure) on a
   small fixture (ToC anchors, grouping, ordering incl. trailing `Other`,
   escaping, missing-path handling, secrets badge, generated-at stamp).
2. **Screen + Markdown preview.** New shell destination, `flutter_markdown`
   preview, per-row copy-path; widget tests.
3. **Save + open actions.** `.md` / `.html` export, `file:` links,
   open-in-editor via `url_launcher`, reveal; widget + integration coverage
   over the save path (test-root fixtures, never real home).
4. **Docs + changelog.** `docs/supported-tools.md` untouched (tool-agnostic);
   add the report to README.md `### Available now` + `CHANGELOG.md`
   Unreleased entry.

## Validation

- `flutter analyze --fatal-infos`, `dart format`, `flutter test`
  (builders + screen), doc-links check.
- Manual: generate both formats from a real discovery run, open the HTML
  from disk in a browser (no server), click every link class, confirm dark
  mode, confirm secret-bearing rows show the badge and no values.
- Whole-branch review per the standard workflow (stepfun + agy chunk
  reviews, opencode + stepfun whole-branch) before PR.

## Status

- [ ] Chunk 1 — model + builders + unit tests
- [ ] Chunk 2 — screen + Markdown preview
- [ ] Chunk 3 — save + open actions
- [ ] Chunk 4 — docs + changelog, archive per `AGENTS.md`

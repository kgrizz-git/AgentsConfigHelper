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

### Builders (pure functions, golden-tested)

- `buildMarkdownReport(model)`: `#` title + generated-at stamp, ToC with
  anchor links per tool, one `##` section per tool with a nested list;
  each file row: kind badge (text), relative path as `file:` link, format
  and scope in muted text. Secret-bearing files get a `⚠ secrets` marker.
- `buildHtmlReport(model)`: single self-contained file, inline CSS only, no
  external assets, no JS. Clean sans-serif, sticky ToC sidebar (collapses to
  top-nav on narrow widths), per-tool sections, kind badges as pills,
  `file:` links per row. Must render identically offline from disk.
- Shared ordering: tools in catalog order, files sorted by scope then path.
- Escaping: HTML-escape display names/paths; percent-encode `file:` URIs
  (spaces, `#`, non-ASCII).

### Screen + preview

- New `Overview` / `Report` destination in the main shell (alongside the
  existing tool views), reading discovery state via the existing providers.
- Preview renders the Markdown via the `flutter_markdown` package (new
  dependency; pure Dart, no platform plugins). No in-app HTML renderer —
  "Open in browser" hands the saved `.html` to the OS via `url_launcher`
  (already a dependency).
- Buttons: `Save .md`, `Save .html`, `Open in editor` per row (OS default
  app for the extension via `url_launcher`), `Copy path` per row.
- Save flow uses a native save dialog via the `file_selector` plugin
  (confirmed: dialog, not an automatic location). Keep the builder layer
  decoupled from the dialog so save-path tests run against test-root
  fixtures without UI.

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
   from discovery/catalog fixtures, both builders; golden assertions on a
   small fixture (ToC anchors, grouping, ordering, escaping, missing-path
   handling, secrets badge, generated-at stamp).
2. **Screen + Markdown preview.** New shell destination, `flutter_markdown`
   preview, per-row copy-path; widget tests.
3. **Save + open actions.** `.md` / `.html` export, `file:` links,
   open-in-editor via `url_launcher`, reveal; widget + integration coverage
   over the save path (test-root fixtures, never real home).
4. **Docs + changelog.** `docs/supported-tools.md` untouched (tool-agnostic);
   short section in user docs + `CHANGELOG.md` Unreleased entry.

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

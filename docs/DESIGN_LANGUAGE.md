# Design language

Dark-first, muted, modern. One neutral ramp, one accent, flat surfaces.
This file is the source of truth for colors, type, and shape in both the
Flutter app (`lib/theme/`) and the exported HTML report
(`plans/active/config-overview-report.md`). Keep it in sync with both.

## Principles

1. **Dark-first.** The app ships dark-only today; the HTML export supports
   light via `prefers-color-scheme` as a secondary rendering. New surfaces
   are designed dark, then mapped to light.
2. **Muted neutrals, single accent.** Backgrounds and text live on a near-
   neutral ramp (existing app values lean zinc); the VS Code blue accent is
   reserved for interactive elements (links, active states, primary
   buttons). Everything else is neutral.
3. **Flat depth.** Separation comes from layered backgrounds
   (canvas → sidebar → card), not shadows or heavy borders. Dividers are
   1px low-contrast lines.
4. **Quiet status.** Status colors appear as tinted badge backgrounds with
   colored text, never solid fills, except small dots.
5. **No decorative motion.** Animation only for state transitions; keep it
   under 300ms. The static HTML export has no JS and no animation at all.

## Type

- **UI:** `Manrope` (Regular 400, Medium 500, SemiBold 600). Bundled in
  `assets/fonts/`; never web-loaded. No fallback list is declared —
  Flutter falls back to platform system fonts automatically. Evaluated alternatives, kept on the table if Manrope feels
  off at small sizes: `Plus Jakarta Sans` (warmer, rounder) and `Outfit`
  (more distinctive, techy edge). Swapping later is the same 4-file change
  (fonts, `pubspec.yaml`, `app_text_styles.dart`, this file).
- **Code/paths:** `JetBrains Mono`, falling back to `ui-monospace, SF Mono,
  Cascadia Code, Consolas, monospace`.
- **Export constraint:** the HTML report must render offline from disk, so
  it uses system stacks only — no webfont downloads:
  `-apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`
  for UI and the mono stack above for paths. Same visual intent, zero
  network.
- **Scale:** 13 meta/secondary, 14 body, 16 section titles, 24 page title.
  Code/paths at 13. These match `AppTextStyles` — the spec follows the
  code, not the other way round.
- **Weights:** `uiBase` Regular 400 (implicit default), `uiSecondary`
  Regular 400, `uiSubheader` Medium 500, `uiHeader` SemiBold 600,
  `codeBase` Regular 400. Name the weight when adding a style.

## Color tokens

Dark values are canonical (they match `AppColors` today). Light values are
for the HTML export's `prefers-color-scheme: light` block.

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| `background` | `#1E1E1E` | `#FAFAFA` | App canvas / page |
| `sidebar` | `#181818` | `#F4F4F5` | Sidebar / ToC column |
| `surface` | `#252526` | `#FFFFFF` | Cards, sections, dialogs |
| `surface-hover` | `#2D2D2D` | `#F4F4F5` | Hover states |
| `border` | `#333333` | `#E4E4E7` | Dividers, card outlines |
| `text` | `#E0E0E0` | `#18181B` | Primary text |
| `text-muted` | `#A0A0A0` | `#52525B` | Secondary text, meta |
| `accent` | `#007ACC` | `#007ACC` | Links, active, primary actions |
| `accent-hover` | `#005999` | `#005999` | Accent hover/press |
| `success` | `#4CAF50` | `#15803D` | Success text/dots |
| `warning` | `#FFA000` | `#B45309` | Warning text/dots |
| `error` | `#F44336` | `#DC2626` | Error text/dots |
| `diff-add` | `#274028` | `#DCFCE7` | Added-row background |
| `diff-remove` | `#4C2727` | `#FEE2E2` | Removed-row background |

Status tints are darkened/lightened so text contrast holds in both modes.

## Badges

Kind pills (`config` / `permissions` / `rules` / `other`) and the secrets
warning follow one pattern: tinted token background + matching foreground
text + 999px radius + 12px semibold label. Example dark values: neutral
pill `#2D2D2D` bg / `#E0E0E0` text; warning pill `#3A2406`-class bg /
`#FFA000` text. Never solid status fills for text-bearing badges.
Kind pills live in report rows and editor headers — not in sidebar items,
which stay icon + title + path.
Explicit exception: full-width alert banners (e.g. the test-root banner)
may use a solid `warning` fill with dark text; the no-solid-fills rule
covers badges and pills, not banners.
Active selection is `surface-hover` background plus a 3px accent left rail
(the `SidebarItem` pattern) — no separate `surface-active` token; the rail,
not the fill, is the differentiator.

## Shape and spacing

- Radius: 8px cards and buttons, 999px pills, 6px inputs.
- Spacing base 4px; section padding 16–24px; ToC sidebar 240–280px,
  collapsing to a top nav under ~720px width.

## States

- **Focus:** 2px accent ring, 2px offset. `InkWell` ripple is the current
  mechanism; a dedicated focus-ring token is deferred, not omitted.
- **Empty:** empty states use `uiSecondary` (`text-muted`).
- **Loading:** the default Material spinner is intentional on dark
  surfaces; override only if it clashes with a new surface.

## Export mapping

The HTML builder maps tokens 1:1 to CSS variables (`--bg`, `--surface`,
`--sidebar`, `--border`, `--text`, `--text-muted`, `--accent`, …) with the
dark set as default and the light set inside
`@media (prefers-color-scheme: light)`. No `<base>`, no external `<link>`,
no resource hints, no JS (per the report plan's offline rule).

## Agent rules

1. Use `AppColors` / `AppTextStyles` in widgets — never raw hex, and never
   `Colors.*` constants (e.g. `Colors.red`, which duplicates
   `AppColors.error`), outside `lib/theme/` and this file. Narrow
   exceptions, both deliberate contrast choices on dark fills — leave them,
   don't proliferate them: the diff `Before:` / `After:` labels in
   `raw_diff_view.dart` (brighter Material accent variants), and the
   `Colors.black` text on the solid-warning test-root banner in
   `main_shell.dart`.
2. Use the token table for export CSS — never ad-hoc colors in builders.
3. When adding a token, add it here, in `AppColors`, and (if it renders in
   the report) in the export CSS mapping in the same PR.

import 'dart:convert';

import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';

String _groupName(List<ConfigOverviewEntry> entries, ToolId? group) {
  if (group == null) return 'Other';
  return entries.firstWhere((e) => e.toolId == group).displayName;
}

String _slugify(String text) {
  return text
      .toLowerCase()
      .replaceAll(' ', '-')
      .replaceAll(RegExp('[^a-z0-9-]'), '');
}

String _formatTimestamp(DateTime dt) {
  return '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')} UTC';
}

String _escapeMarkdown(String text) {
  final sb = StringBuffer();
  for (final char in text.runes) {
    final c = String.fromCharCode(char);
    if (c == r'\' || c == '[' || c == ']' || c == '(' || c == ')' || c == '`') {
      sb.write(r'\');
    }
    sb.write(c);
  }
  return sb.toString().replaceAll('\n', ' ').replaceAll('\r', ' ');
}

/// Builds a Markdown report from the overview model.
String buildMarkdownReport(
  List<ConfigOverviewEntry> entries, {
  DateTime? generatedAt,
}) {
  final stamp = _formatTimestamp(generatedAt ?? DateTime.now().toUtc());

  final groups = <ToolId?, List<ConfigOverviewEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.toolId, () => []).add(entry);
  }

  final sb = StringBuffer()
    ..writeln('# Config Overview Report')
    ..writeln()
    ..writeln('Generated at $stamp')
    ..writeln()
    ..writeln(
      '> This report lists paths and metadata only — no file contents. '
      'Linked files may contain secrets.',
    )
    ..writeln()
    ..writeln('## Contents')
    ..writeln();
  for (final group in groups.keys) {
    final name = _groupName(entries, group);
    final anchor = _slugify(name);
    sb.writeln('- [$name](#$anchor)');
  }
  sb.writeln();

  var firstGroup = true;
  for (final group in groups.keys) {
    if (firstGroup) {
      firstGroup = false;
    } else {
      sb.writeln();
    }
    final name = _groupName(entries, group);
    sb
      ..writeln('## $name')
      ..writeln();

    final groupEntries = groups[group]!;
    final secretEntries = groupEntries.where((e) => e.secretBearing).toList();
    if (secretEntries.isNotEmpty) {
      sb
        ..writeln(
          '⚠ **Secrets**: The following files may contain sensitive values:',
        )
        ..writeln();
      for (final entry in secretEntries) {
        sb.writeln('- ${_escapeMarkdown(entry.displayPath)}');
      }
      sb.writeln();
    }

    for (final entry in groupEntries) {
      final kindText = kindLabel(entry.kind);
      final escapedPath = _escapeMarkdown(entry.displayPath);
      final uri = Uri.file(entry.filePath ?? '')
          .toString()
          .replaceAll('(', '%28')
          .replaceAll(')', '%29');
      final formatText = formatLabel(entry.format);
      final scopeText = scopeLabel(entry.scope);
      final secretMarker = entry.secretBearing ? ' ⚠ secrets' : '';

      if (entry.missing) {
        sb.writeln(
          '- **$kindText** $escapedPath — '
          '$formatText, $scopeText$secretMarker',
        );
      } else {
        sb.writeln(
          '- **$kindText** [$escapedPath]($uri) — '
          '$formatText, $scopeText$secretMarker',
        );
      }
    }
  }

  return sb.toString();
}

const _htmlCss = '''
:root {
  --bg: #1E1E1E;
  --sidebar: #181818;
  --surface: #252526;
  --surface-hover: #2D2D2D;
  --border: #333333;
  --text: #E0E0E0;
  --text-muted: #A0A0A0;
  --accent: #007ACC;
  --accent-hover: #005999;
  --warning: #FFA000;
}
@media (prefers-color-scheme: light) {
  :root {
    --bg: #FAFAFA;
    --sidebar: #F4F4F5;
    --surface: #FFFFFF;
    --surface-hover: #F4F4F5;
    --border: #E4E4E7;
    --text: #18181B;
    --text-muted: #52525B;
    --accent: #007ACC;
    --accent-hover: #005999;
    --warning: #B45309;
  }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.5;
  display: flex;
  min-height: 100vh;
}

.toc-sidebar {
  width: 260px;
  flex-shrink: 0;
  background: var(--sidebar);
  border-right: 1px solid var(--border);
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
  padding: 16px;
}

.content {
  flex: 1;
  padding: 24px;
  max-width: 900px;
}

@media (max-width: 720px) {
  body { flex-direction: column; }
  .toc-sidebar {
    width: 100%;
    height: auto;
    position: static;
    border-right: none;
    border-bottom: 1px solid var(--border);
  }
}

h1 { font-size: 24px; font-weight: 600; margin-bottom: 8px; }
h2 { font-size: 16px; font-weight: 600; margin-top: 24px; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border); }
.meta { color: var(--text-muted); font-size: 13px; margin-bottom: 24px; }
a { color: var(--accent); text-decoration: none; }
a:hover { color: var(--accent-hover); text-decoration: underline; }

.toc-title { font-size: 13px; font-weight: 500; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 12px; }
.toc-list { list-style: none; }
.toc-list li { margin-bottom: 6px; }
.toc-list a { color: var(--text); font-size: 14px; }
.toc-list a:hover { color: var(--accent); }

.file-list { list-style: none; }
.file-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  border-radius: 6px;
  margin-bottom: 4px;
  background: var(--surface);
  border: 1px solid var(--border);
}
.file-item.missing { opacity: 0.7; }
.file-path {
  font-family: ui-monospace, SF Mono, Cascadia Code, Consolas, monospace;
  font-size: 13px;
  flex: 1;
  word-break: break-all;
}
.file-path a { color: var(--accent); }
.file-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
  line-height: 1.4;
  flex-shrink: 0;
}
.badge-config { background: #2D2D2D; color: #E0E0E0; }
.badge-permissions { background: #1E3A2F; color: #4CAF50; }
.badge-rules { background: #3A2E1E; color: #FFA000; }
.badge-other { background: #2D2D2D; color: #E0E0E0; }
.badge-warning { background: #3A2406; color: #FFA000; }

@media (prefers-color-scheme: light) {
  .badge-config { background: #F4F4F5; color: #18181B; }
  .badge-permissions { background: #DCFCE7; color: #15803D; }
  .badge-rules { background: #FEF3C7; color: #B45309; }
  .badge-other { background: #F4F4F5; color: #18181B; }
  .badge-warning { background: #FEF3C7; color: #B45309; }
}
''';

/// Builds a self-contained HTML report from the overview model.
String buildHtmlReport(
  List<ConfigOverviewEntry> entries, {
  DateTime? generatedAt,
}) {
  final stamp = _formatTimestamp(generatedAt ?? DateTime.now().toUtc());
  const elementEscaper = HtmlEscape(HtmlEscapeMode.element);
  const attributeEscaper = HtmlEscape(HtmlEscapeMode.attribute);

  final groups = <ToolId?, List<ConfigOverviewEntry>>{};
  for (final entry in entries) {
    groups.putIfAbsent(entry.toolId, () => []).add(entry);
  }

  final sb = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln(
      '<meta name="viewport" '
      'content="width=device-width, initial-scale=1.0">',
    )
    ..writeln('<title>Config Overview Report</title>')
    ..writeln('<style>')
    ..write(_htmlCss)
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<div class="toc-sidebar">')
    ..writeln('<div class="toc-title">Contents</div>')
    ..writeln('<ul class="toc-list">');
  for (final group in groups.keys) {
    final name = _groupName(entries, group);
    final anchor = _slugify(name);
    sb.writeln(
      '<li><a href="#$anchor">${elementEscaper.convert(name)}</a></li>',
    );
  }
  sb
    ..writeln('</ul>')
    ..writeln('</div>')
    ..writeln('<div class="content">')
    ..writeln('<h1>Config Overview Report</h1>')
    ..writeln('<p class="meta">Generated at $stamp</p>')
    ..writeln(
      '<p class="meta">This report lists paths and metadata only — '
      'no file contents. Linked files may contain secrets.</p>',
    );

  for (final group in groups.keys) {
    final name = _groupName(entries, group);
    final anchor = _slugify(name);
    sb.writeln('<h2 id="$anchor">${elementEscaper.convert(name)}</h2>');

    final groupEntries = groups[group]!;
    sb.writeln('<ul class="file-list">');
    for (final entry in groupEntries) {
      final kindClass = 'badge-${kindLabel(entry.kind)}';
      final kindText = kindLabel(entry.kind);
      final escapedPath = elementEscaper.convert(entry.displayPath);
      final formatText = formatLabel(entry.format);
      final scopeText = scopeLabel(entry.scope);

      String pathHtml;
      if (entry.missing || entry.filePath == null) {
        pathHtml = '<code>$escapedPath</code>';
      } else {
        final uri = attributeEscaper.convert(
          Uri.file(entry.filePath!).toString(),
        );
        pathHtml = '<a href="$uri"><code>$escapedPath</code></a>';
      }

      sb
        ..writeln(
          '<li class="file-item${entry.missing ? ' missing' : ''}">',
        )
        ..writeln(
          '  <span class="badge $kindClass">$kindText</span>',
        )
        ..writeln('  <span class="file-path">$pathHtml</span>')
        ..writeln(
          '  <span class="file-meta">$formatText · $scopeText</span>',
        );
      if (entry.secretBearing) {
        sb.writeln('  <span class="badge badge-warning">⚠ secrets</span>');
      }
      sb.writeln('</li>');
    }
    sb.writeln('</ul>');
  }

  sb
    ..writeln('</div>')
    ..writeln('</body>')
    ..writeln('</html>');

  return sb.toString();
}

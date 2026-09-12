import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/config_overview_builders.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('buildOverviewModel + builders', () {
    test('matches checked-in markdown and html snapshots', () async {
      final homeDir = await Directory.systemTemp.createTemp(
        'ach-overview-home',
      );
      final outsideDir = await Directory.systemTemp.createTemp(
        'ach-overview-outside',
      );
      try {
        final homePath = homeDir.path;
        final catalog = <ToolDescriptor>[
          const ToolDescriptor(
            id: ToolId.claudeCode,
            displayName: 'Alpha Tool',
            targets: [
              ConfigTarget(
                relativePath: '.config/alpha.json',
                format: ConfigFormat.json,
                scope: ConfigLocationScope.user,
                kind: ConfigSourceKind.structuredConfig,
              ),
              ConfigTarget(
                relativePath: 'AGENTS.md',
                format: ConfigFormat.markdown,
                scope: ConfigLocationScope.project,
                kind: ConfigSourceKind.instructionDocument,
              ),
            ],
          ),
          const ToolDescriptor(
            id: ToolId.codex,
            displayName: 'Beta Tool',
            targets: [
              ConfigTarget(
                relativePath: 'auth.json',
                format: ConfigFormat.json,
                scope: ConfigLocationScope.user,
                kind: ConfigSourceKind.structuredConfig,
              ),
              ConfigTarget(
                relativePath: 'rules.md',
                format: ConfigFormat.markdown,
                scope: ConfigLocationScope.project,
                kind: ConfigSourceKind.instructionDocument,
              ),
              ConfigTarget(
                relativePath: 'token.json',
                format: ConfigFormat.json,
                scope: ConfigLocationScope.user,
                kind: ConfigSourceKind.structuredConfig,
              ),
            ],
          ),
          const ToolDescriptor(
            id: ToolId.cursor,
            displayName: 'Cursor Agent',
            targets: [
              ConfigTarget(
                relativePath: '.cursor/rules/*.mdc',
                format: ConfigFormat.markdown,
                scope: ConfigLocationScope.project,
                kind: ConfigSourceKind.instructionDocument,
              ),
            ],
          ),
        ];

        DiscoveredConfig found(
          String relativePath,
          ToolDescriptor tool,
          ConfigLocationScope scope,
          ConfigSourceKind kind,
          ConfigFormat format,
        ) {
          final filePath = p.join(homePath, relativePath);
          return DiscoveredConfig(
            id: '${kind.name}:$filePath',
            filePath: filePath,
            descriptor: tool,
            scope: scope,
            kind: kind,
            format: format,
            sourceLabel: tool.displayName,
            fromCatalog: true,
          );
        }

        final weirdPath = p.join(homePath, 'weird] ( path.md');
        final parenPath = p.join(homePath, 'notes) done.md');
        final outsidePath = p.join(outsideDir.path, 'shared-notes.md');
        final discovery = DiscoveryResult(
          items: [
            found(
              '.config/alpha.json',
              catalog[0],
              ConfigLocationScope.user,
              ConfigSourceKind.structuredConfig,
              ConfigFormat.json,
            ),
            found(
              p.join('proj1', 'AGENTS.md'),
              catalog[0],
              ConfigLocationScope.project,
              ConfigSourceKind.instructionDocument,
              ConfigFormat.markdown,
            ),
            found(
              p.join('proj2', 'AGENTS.md'),
              catalog[0],
              ConfigLocationScope.project,
              ConfigSourceKind.instructionDocument,
              ConfigFormat.markdown,
            ),
            found(
              'auth.json',
              catalog[1],
              ConfigLocationScope.user,
              ConfigSourceKind.structuredConfig,
              ConfigFormat.json,
            ),
            found(
              p.join('proj1', 'rules.md'),
              catalog[1],
              ConfigLocationScope.project,
              ConfigSourceKind.instructionDocument,
              ConfigFormat.markdown,
            ),
            found(
              p.join('proj1', '.cursor', 'rules', 'foo.mdc'),
              catalog[2],
              ConfigLocationScope.project,
              ConfigSourceKind.instructionDocument,
              ConfigFormat.markdown,
            ),
            DiscoveredConfig(
              id: 'instructionDocument:$outsidePath',
              filePath: outsidePath,
              descriptor: null,
              scope: ConfigLocationScope.manual,
              kind: ConfigSourceKind.instructionDocument,
              format: ConfigFormat.markdown,
              sourceLabel: 'Unknown configuration',
              fromManual: true,
            ),
            DiscoveredConfig(
              id: 'instructionDocument:$weirdPath',
              filePath: weirdPath,
              descriptor: null,
              scope: ConfigLocationScope.manual,
              kind: ConfigSourceKind.instructionDocument,
              format: ConfigFormat.markdown,
              sourceLabel: 'Unknown configuration',
              fromManual: true,
            ),
            DiscoveredConfig(
              id: 'instructionDocument:$parenPath',
              filePath: parenPath,
              descriptor: null,
              scope: ConfigLocationScope.manual,
              kind: ConfigSourceKind.instructionDocument,
              format: ConfigFormat.text,
              sourceLabel: 'Unknown configuration',
              fromManual: true,
            ),
          ],
        );

        final model = buildOverviewModel(
          discovery,
          catalog,
          homePath: homePath,
          projectRoots: [
            p.join(homePath, 'proj1'),
            p.join(homePath, 'proj2'),
          ],
        );

        String scrub(String report) => report
            .replaceAll(homePath, '<HOME>')
            .replaceAll(outsideDir.path, '<OUTSIDE>');

        final markdown = scrub(
          buildMarkdownReport(
            model,
            generatedAt: DateTime.utc(2026, 9, 11, 22, 27, 2),
          ),
        );
        final html = scrub(
          buildHtmlReport(
            model,
            generatedAt: DateTime.utc(2026, 9, 11, 22, 27, 2),
          ),
        );

        final expectedMarkdown = File(
          'test/fixtures/config_overview_expected.md',
        ).readAsStringSync();
        final expectedHtml = File('test/fixtures/config_overview_expected.html')
            .readAsStringSync();

        expect(markdown, expectedMarkdown);
        expect(html, expectedHtml);
      } finally {
        await homeDir.delete(recursive: true);
        await outsideDir.delete(recursive: true);
      }
    });

    test('missing project target with zero roots emits no rows', () {
      final catalog = <ToolDescriptor>[
        const ToolDescriptor(
          id: ToolId.claudeCode,
          displayName: 'Alpha Tool',
          targets: [
            ConfigTarget(
              relativePath: 'AGENTS.md',
              format: ConfigFormat.markdown,
              scope: ConfigLocationScope.project,
              kind: ConfigSourceKind.instructionDocument,
            ),
          ],
        ),
      ];

      const discovery = DiscoveryResult(items: []);

      final model = buildOverviewModel(
        discovery,
        catalog,
        homePath: 'test-home',
        projectRoots: const [],
      );

      expect(model, isEmpty);
    });

    test('plural secret basenames flag secret-bearing', () async {
      final homeDir = await Directory.systemTemp.createTemp(
        'ach-overview-home',
      );
      try {
        final homePath = homeDir.path;
        DiscoveredConfig manual(String name) {
          final filePath = p.join(homePath, name);
          return DiscoveredConfig(
            id: 'manual:$filePath',
            filePath: filePath,
            descriptor: null,
            scope: ConfigLocationScope.manual,
            kind: ConfigSourceKind.structuredConfig,
            format: ConfigFormat.json,
            sourceLabel: 'Unknown configuration',
            fromManual: true,
          );
        }

        final model = buildOverviewModel(
          DiscoveryResult(
            items: [
              manual('secrets.json'),
              manual('tokens.json'),
              manual('notes.json'),
            ],
          ),
          const [],
          homePath: homePath,
          projectRoots: const [],
        );

        final byPath = {for (final e in model) e.filePath: e};
        expect(byPath[p.join(homePath, 'secrets.json')]!.secretBearing, isTrue);
        expect(byPath[p.join(homePath, 'tokens.json')]!.secretBearing, isTrue);
        expect(byPath[p.join(homePath, 'notes.json')]!.secretBearing, isFalse);
      } finally {
        await homeDir.delete(recursive: true);
      }
    });

    test(
      'copilotHome resolves Copilot user target without missing row',
      () async {
        final homeDir = await Directory.systemTemp.createTemp(
          'ach-overview-home',
        );
        final copilotDir = await Directory.systemTemp.createTemp(
          'ach-overview-copilot',
        );
        try {
          final homePath = homeDir.path;
          final copilotHomePath = copilotDir.path;
          final settingsFile = p.join(copilotHomePath, 'settings.json');
          await File(settingsFile).create(recursive: true);

          final catalog = <ToolDescriptor>[
            const ToolDescriptor(
              id: ToolId.copilot,
              displayName: 'GitHub Copilot',
              targets: [
                ConfigTarget(
                  relativePath: '.copilot/settings.json',
                  format: ConfigFormat.jsonc,
                  scope: ConfigLocationScope.user,
                  kind: ConfigSourceKind.structuredConfig,
                ),
              ],
            ),
          ];

          final discovery = DiscoveryResult(
            items: [
              DiscoveredConfig(
                id: 'structuredConfig:$settingsFile',
                filePath: settingsFile,
                descriptor: catalog[0],
                scope: ConfigLocationScope.user,
                kind: ConfigSourceKind.structuredConfig,
                format: ConfigFormat.jsonc,
                sourceLabel: 'GitHub Copilot',
                fromCatalog: true,
              ),
            ],
          );

          final model = buildOverviewModel(
            discovery,
            catalog,
            homePath: homePath,
            projectRoots: const [],
            copilotHome: copilotHomePath,
          );

          expect(model, hasLength(1));
          expect(model.first.missing, isFalse);
          expect(model.first.displayPath, settingsFile);
          expect(model.first.filePath, settingsFile);
        } finally {
          await homeDir.delete(recursive: true);
          await copilotDir.delete(recursive: true);
        }
      },
    );

    test(
      'without copilotHome, Copilot user target shows missing at home',
      () async {
        final homeDir = await Directory.systemTemp.createTemp(
          'ach-overview-home',
        );
        try {
          final homePath = homeDir.path;
          final catalog = <ToolDescriptor>[
            const ToolDescriptor(
              id: ToolId.copilot,
              displayName: 'GitHub Copilot',
              targets: [
                ConfigTarget(
                  relativePath: '.copilot/settings.json',
                  format: ConfigFormat.jsonc,
                  scope: ConfigLocationScope.user,
                  kind: ConfigSourceKind.structuredConfig,
                ),
              ],
            ),
          ];

          const discovery = DiscoveryResult(items: []);

          final model = buildOverviewModel(
            discovery,
            catalog,
            homePath: homePath,
            projectRoots: const [],
          );

          expect(model, hasLength(1));
          expect(model.first.missing, isTrue);
          expect(model.first.displayPath, '.copilot/settings.json');
          expect(
            model.first.filePath,
            p.join(homePath, '.copilot/settings.json'),
          );
        } finally {
          await homeDir.delete(recursive: true);
        }
      },
    );

    test('dual-provenance glob match attributes to owning tool', () async {
      final homeDir = await Directory.systemTemp.createTemp(
        'ach-overview-home',
      );
      try {
        final homePath = homeDir.path;
        final catalog = <ToolDescriptor>[
          const ToolDescriptor(
            id: ToolId.cursor,
            displayName: 'Cursor Agent',
            targets: [
              ConfigTarget(
                relativePath: '.cursor/rules/*.mdc',
                format: ConfigFormat.markdown,
                scope: ConfigLocationScope.project,
                kind: ConfigSourceKind.instructionDocument,
              ),
            ],
          ),
        ];
        final rulePath = p.join(
          homePath,
          'proj1',
          '.cursor',
          'rules',
          'mine.mdc',
        );

        final model = buildOverviewModel(
          DiscoveryResult(
            items: [
              DiscoveredConfig(
                id: 'instructionDocument:$rulePath',
                filePath: rulePath,
                descriptor: catalog[0],
                scope: ConfigLocationScope.project,
                kind: ConfigSourceKind.instructionDocument,
                format: ConfigFormat.markdown,
                sourceLabel: 'Cursor Agent',
                fromCatalog: true,
                fromManual: true,
              ),
            ],
          ),
          catalog,
          homePath: homePath,
          projectRoots: [p.join(homePath, 'proj1')],
        );

        expect(model, hasLength(1));
        expect(model.first.toolId, ToolId.cursor);
        expect(model.first.missing, isFalse);
        expect(
          model.first.displayPath,
          p.join('proj1', '.cursor', 'rules', 'mine.mdc'),
        );
      } finally {
        await homeDir.delete(recursive: true);
      }
    });
  });
}

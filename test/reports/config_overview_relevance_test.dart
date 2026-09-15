import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/config_overview_builders.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('overview relevance classification', () {
    const homePath = 'ach-rel-home';

    List<ToolDescriptor> catalog() => <ToolDescriptor>[
      const ToolDescriptor(
        id: ToolId.kilo,
        displayName: 'Kilo',
        targets: [
          ConfigTarget(
            relativePath: '.config/tool/primary.json',
            format: ConfigFormat.json,
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
          ),
          ConfigTarget(
            relativePath: '.config/tool/optional.json',
            format: ConfigFormat.json,
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
            optional: true,
          ),
          ConfigTarget(
            relativePath: '.config/tool/mac.json',
            format: ConfigFormat.json,
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
            platform: ConfigPlatform.macOS,
          ),
          ConfigTarget(
            relativePath: '.config/tool/win.json',
            format: ConfigFormat.json,
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
            platform: ConfigPlatform.windows,
          ),
        ],
      ),
    ];

    DiscoveryResult discoveryWithPrimary() {
      final path = p.normalize(p.join(homePath, '.config/tool/primary.json'));
      return DiscoveryResult(
        items: [
          DiscoveredConfig(
            id: 'structuredConfig:$path',
            filePath: path,
            descriptor: catalog().first,
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
            format: ConfigFormat.json,
            sourceLabel: 'Kilo',
            fromCatalog: true,
          ),
        ],
      );
    }

    OverviewRelevance relevanceOf(
      List<ConfigOverviewEntry> model,
      String relativePath,
    ) {
      final path = p.normalize(p.join(homePath, relativePath));
      return model.firstWhere((e) => e.filePath == path).relevance;
    }

    test('configured tool classifies optional and other-platform', () {
      final model = buildOverviewModel(
        discoveryWithPrimary(),
        catalog(),
        homePath: homePath,
        projectRoots: const [],
        platform: ConfigPlatform.linux,
      );

      expect(
        relevanceOf(model, '.config/tool/primary.json'),
        OverviewRelevance.present,
      );
      expect(
        relevanceOf(model, '.config/tool/optional.json'),
        OverviewRelevance.optionalMissing,
      );
      expect(
        relevanceOf(model, '.config/tool/mac.json'),
        OverviewRelevance.otherPlatform,
      );
      expect(
        relevanceOf(model, '.config/tool/win.json'),
        OverviewRelevance.otherPlatform,
      );
    });

    test('host platform turns an own-platform absent target into expected', () {
      final model = buildOverviewModel(
        discoveryWithPrimary(),
        catalog(),
        homePath: homePath,
        projectRoots: const [],
        platform: ConfigPlatform.macOS,
      );

      expect(
        relevanceOf(model, '.config/tool/mac.json'),
        OverviewRelevance.expectedMissing,
      );
      expect(
        relevanceOf(model, '.config/tool/win.json'),
        OverviewRelevance.otherPlatform,
      );
    });

    test('unconfigured tool suppresses absent targets as not configured', () {
      final model = buildOverviewModel(
        const DiscoveryResult(items: []),
        catalog(),
        homePath: homePath,
        projectRoots: const [],
        platform: ConfigPlatform.linux,
      );

      expect(
        relevanceOf(model, '.config/tool/primary.json'),
        OverviewRelevance.notConfigured,
      );
      expect(
        relevanceOf(model, '.config/tool/optional.json'),
        OverviewRelevance.notConfigured,
      );
      expect(
        relevanceOf(model, '.config/tool/mac.json'),
        OverviewRelevance.otherPlatform,
      );
    });
  });

  group('relevance labels in builders', () {
    ConfigOverviewEntry entry(
      OverviewRelevance relevance, {
      ConfigPlatform platform = ConfigPlatform.any,
      String? filePath,
    }) {
      return ConfigOverviewEntry(
        toolId: ToolId.kilo,
        displayName: 'Kilo',
        filePath: filePath,
        displayPath: 'kilo/file.json',
        kind: OverviewKind.config,
        format: ConfigFormat.json,
        scope: ConfigLocationScope.user,
        secretBearing: false,
        relevance: relevance,
        platform: platform,
      );
    }

    List<ConfigOverviewEntry> allRelevances() => [
      entry(OverviewRelevance.present, filePath: '/tmp/present.json'),
      entry(OverviewRelevance.expectedMissing),
      entry(OverviewRelevance.optionalMissing),
      entry(OverviewRelevance.otherPlatform, platform: ConfigPlatform.windows),
      entry(OverviewRelevance.notConfigured),
    ];

    test('markdown labels each relevance and links only present files', () {
      final report = buildMarkdownReport(
        allRelevances(),
        generatedAt: DateTime.utc(2026),
      );

      expect(report, contains('⚠ missing'));
      expect(report, contains(' optional'));
      expect(report, contains(' other OS (Windows)'));
      expect(report, contains(' not configured'));
      expect(
        report,
        contains('[kilo/file.json](file:///tmp/present.json)'),
      );
    });

    test('html uses muted badges and links only present files', () {
      final html = buildHtmlReport(
        allRelevances(),
        generatedAt: DateTime.utc(2026),
      );

      expect(html, contains('badge-missing'));
      expect(html, contains('badge-optional'));
      expect(html, contains('badge-audit'));
      expect(html, contains('other OS (Windows)'));
      expect(html, contains('not configured'));
      expect(RegExp('<a href="file:').allMatches(html).length, 1);
    });

    test('exports describe hidden and audit views', () {
      final relevant = buildMarkdownReport(
        const [],
        generatedAt: DateTime.utc(2026),
        hiddenCount: 4,
      );
      expect(relevant, contains('Relevant view'));
      expect(relevant, contains('4 catalog target(s)'));

      final audit = buildMarkdownReport(
        const [],
        generatedAt: DateTime.utc(2026),
        view: ReportView.audit,
      );
      expect(audit, contains('Audit view'));

      final html = buildHtmlReport(
        const [],
        generatedAt: DateTime.utc(2026),
        hiddenCount: 2,
      );
      expect(html, contains('Relevant view'));
    });
  });
}

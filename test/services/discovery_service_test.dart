import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DiscoveryService', () {
    late Directory mockHome;
    late Directory mockProject;
    late DiscoveryService discoveryService;

    setUp(() async {
      mockHome = await Directory.systemTemp.createTemp('discovery_test_home_');
      mockProject = await Directory.systemTemp.createTemp(
        'discovery_test_project_',
      );
      discoveryService = DiscoveryService();
    });

    tearDown(() async {
      // ignore: avoid_slow_async_io
      if (await mockHome.exists()) {
        await mockHome.delete(recursive: true);
      }
      // ignore: avoid_slow_async_io
      if (await mockProject.exists()) {
        await mockProject.delete(recursive: true);
      }
    });

    test(
      'discoverConfigs returns user and project targets that exist',
      () async {
        final claudeFile = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await claudeFile.create(recursive: true);

        final devinFile = File(
          p.join(mockProject.path, '.devin', 'config.json'),
        );
        await devinFile.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          normalizedProjectRoots: [mockProject.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        expect(result.items.length, equals(2));

        final claudeConfig = result.items.firstWhere(
          (item) => item.filePath == claudeFile.path,
        );
        expect(claudeConfig.scope, equals(ConfigLocationScope.user));
        expect(claudeConfig.sourceLabel, equals('Claude Code'));

        final devinConfig = result.items.firstWhere(
          (item) => item.filePath == devinFile.path,
        );
        expect(devinConfig.scope, equals(ConfigLocationScope.project));
        expect(devinConfig.sourceLabel, equals('Devin'));

        expect(result.warnings, isEmpty);
      },
    );

    test('discoverConfigs returns empty items if no configs exist', () async {
      final request = DiscoveryRequest(
        normalizedHomePath: mockHome.path,
      );
      final result = await discoveryService.discoverConfigs(request);
      expect(result.items, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test(
      'discoverConfigs deduplicates and sets isManual if manual path matches existing',
      () async {
        final manualFile = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await manualFile.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          manualPaths: [manualFile.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        // Should only appear once, prioritized as user target (since it is first)
        expect(result.items.length, equals(1));
        expect(result.items.first.scope, equals(ConfigLocationScope.user));
        // But it should retain manual provenance because the user added it manually
        expect(result.items.first.isManual, isTrue);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'discoverConfigs classifies manual paths and adds warnings for unsupported',
      () async {
        final validManualFile = File(p.join(mockHome.path, 'custom.json'));
        await validManualFile.create(recursive: true);

        final missingManualFile = p.join(mockHome.path, 'missing.json');
        final unsupportedManualFile = p.join(mockHome.path, 'unsupported.bin');

        final request = DiscoveryRequest(
          manualPaths: [
            validManualFile.path,
            missingManualFile,
            unsupportedManualFile,
          ],
        );

        final result = await discoveryService.discoverConfigs(request);

        expect(result.items.length, equals(1));
        expect(result.items.first.filePath, equals(validManualFile.path));
        expect(result.items.first.scope, equals(ConfigLocationScope.manual));
        expect(result.items.first.sourceLabel, equals('Unknown configuration'));

        expect(result.warnings.length, equals(2));
        expect(
          result.warnings.any(
            (w) =>
                w.path == missingManualFile &&
                w.message.contains('does not exist'),
          ),
          isTrue,
        );
        expect(
          result.warnings.any(
            (w) =>
                w.path == unsupportedManualFile &&
                w.message.contains('Unsupported configuration file extension'),
          ),
          isTrue,
        );
      },
    );

    test('discoverConfigs discovers exact instruction documents', () async {
      final claudeMd = File(p.join(mockProject.path, 'CLAUDE.md'));
      await claudeMd.create(recursive: true);

      final agentsMd = File(p.join(mockHome.path, '.codex', 'AGENTS.md'));
      await agentsMd.create(recursive: true);

      final cursorRules = File(p.join(mockProject.path, '.cursorrules'));
      await cursorRules.create(recursive: true);

      final request = DiscoveryRequest(
        normalizedHomePath: mockHome.path,
        normalizedProjectRoots: [mockProject.path],
      );

      final result = await discoveryService.discoverConfigs(request);

      expect(
        result.items.where((item) => item.filePath == claudeMd.path).length,
        equals(1),
      );
      expect(
        result.items.where((item) => item.filePath == agentsMd.path).length,
        equals(1),
      );
      expect(
        result.items.where((item) => item.filePath == cursorRules.path).length,
        equals(1),
      );
    });

    test(
      'discoverConfigs discovers bounded glob instruction documents',
      () async {
        final mdc1 = File(
          p.join(mockProject.path, '.cursor', 'rules', 'rule1.mdc'),
        );
        await mdc1.create(recursive: true);

        final mdc2 = File(
          p.join(mockProject.path, '.cursor', 'rules', 'rule2.mdc'),
        );
        await mdc2.create(recursive: true);

        final kiroMd = File(
          p.join(mockProject.path, '.kiro', 'steering', 'steer.md'),
        );
        await kiroMd.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedProjectRoots: [mockProject.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        expect(
          result.items.where((item) => item.filePath == mdc1.path).length,
          equals(1),
        );
        expect(
          result.items.where((item) => item.filePath == mdc2.path).length,
          equals(1),
        );
        expect(
          result.items.where((item) => item.filePath == kiroMd.path).length,
          equals(1),
        );
      },
    );
  });
}

import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/tool_config.dart';
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
      discoveryService = const DiscoveryService();
    });

    tearDown(() async {
      // Checking existence asynchronously avoids blocking the test isolate.
      // ignore: avoid_slow_async_io
      if (await mockHome.exists()) {
        await mockHome.delete(recursive: true);
      }
      // Checking existence asynchronously avoids blocking the test isolate.
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
      'discoverConfigs deduplicates a manual path matching a catalog target '
      'and sets both provenance flags',
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

        // Should only appear once.
        expect(result.items.length, equals(1));
        expect(result.items.first.scope, equals(ConfigLocationScope.user));
        // Dual provenance: both fromCatalog and fromManual are true.
        // isManual (derived getter) is true so the sidebar remove button
        // appears, and removeManualPath strips only the manual provenance.
        expect(result.items.first.fromCatalog, isTrue);
        expect(result.items.first.fromManual, isTrue);
        expect(result.items.first.isManual, isTrue);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'discoverConfigs classifies manual paths and adds warnings for '
      'unsupported',
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
        expect(result.items.first.fromCatalog, isFalse);
        expect(result.items.first.fromManual, isTrue);
        expect(result.items.first.isManual, isTrue);

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

    test(
      "discoverConfigs assigns the matched target's kind, not the first "
      'same-scope target',
      () async {
        // Claude Code's project-scope targets list a structuredConfig
        // target (.claude/settings.json) before this instructionDocument
        // target (CLAUDE.md); the manually-added file must be classified
        // by the target it actually matched, not by catalog order.
        final claudeMd = File(p.join(mockProject.path, 'CLAUDE.md'));
        await claudeMd.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedProjectRoots: [mockProject.path],
          manualPaths: [claudeMd.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        expect(result.items.length, equals(1));
        expect(result.items.first.format, equals(ConfigFormat.markdown));
        expect(
          result.items.first.kind,
          equals(ConfigSourceKind.instructionDocument),
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

    test(
      'glob enumeration error in one target does not abort other targets',
      () async {
        // Create a file that will be found by a known-good target.
        final claudeFile = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await claudeFile.create(recursive: true);

        // Create a directory with no read permissions to trigger an error
        // during glob enumeration.
        final restrictedDir = Directory(
          p.join(mockProject.path, '.cursor', 'rules'),
        );
        await restrictedDir.create(recursive: true);
        await Process.run('chmod', ['000', restrictedDir.path]);
        addTearDown(() async {
          await Process.run('chmod', ['755', restrictedDir.path]);
        });

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          normalizedProjectRoots: [mockProject.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        // The claude file should still be found despite the glob error.
        expect(
          result.items.any((item) => item.filePath == claudeFile.path),
          isTrue,
        );
        // There should be a warning about the failed glob target.
        expect(
          result.warnings.any(
            (w) =>
                w.path.contains('.cursor') &&
                (w.message.contains('Error enumerating glob target') ||
                    w.message.contains(
                      'Skipped unreadable entry while enumerating glob',
                    )),
          ),
          isTrue,
        );
      },
      skip: Platform.isWindows
          ? 'chmod-based permission denial is POSIX only'
          : false,
    );

    test(
      'glob enumeration emits warning when cap is hit',
      () async {
        final rulesDir = Directory(
          p.join(mockProject.path, '.cursor', 'rules'),
        );
        await rulesDir.create(recursive: true);

        // Create 105 matching .mdc files so the cap (100) is exceeded.
        for (var i = 0; i < 105; i++) {
          await File(p.join(rulesDir.path, 'rule$i.mdc')).create();
        }

        final request = DiscoveryRequest(
          normalizedProjectRoots: [mockProject.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        // At most 100 cursor rules should appear.
        final cursorItems = result.items
            .where((item) => item.filePath.contains('.cursor'))
            .toList();
        expect(cursorItems.length, equals(100));

        // A truncation warning should be present.
        expect(
          result.warnings.any(
            (w) =>
                w.path.contains('.cursor') &&
                w.message.contains('100-entry cap'),
          ),
          isTrue,
        );
      },
    );

    test(
      'manual path that is also auto-discovered has dual provenance '
      'and loses manual flag after removal',
      () async {
        // Create a file that is auto-discoverable via the user-scope scan.
        final claudeFile = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await claudeFile.create(recursive: true);

        // First scan: file is BOTH auto-discovered AND manually added.
        final requestWithManual = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          manualPaths: [claudeFile.path],
        );

        final result1 = await discoveryService.discoverConfigs(
          requestWithManual,
        );

        // Dual provenance: both flags are true, isManual getter is true.
        expect(result1.items.length, equals(1));
        expect(result1.items.first.fromCatalog, isTrue);
        expect(result1.items.first.fromManual, isTrue);
        expect(result1.items.first.isManual, isTrue);
        expect(result1.items.first.filePath, equals(claudeFile.path));

        // Second scan: the same path is no longer in manualPaths. The item is
        // still present (a real config) with only catalog provenance.
        final requestWithoutManual = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
        );

        final result2 = await discoveryService.discoverConfigs(
          requestWithoutManual,
        );

        expect(result2.items.length, equals(1));
        expect(result2.items.first.filePath, equals(claudeFile.path));
        expect(result2.items.first.fromCatalog, isTrue);
        expect(result2.items.first.fromManual, isFalse);
        expect(result2.items.first.isManual, isFalse);
      },
    );

    test(
      'regression: catalog-first dual-provenance file shows remove button '
      '(isManual is true via fromManual)',
      () async {
        // The original bug: catalog discovery runs first and sets
        // isManual:false. When the same path appears in manualPaths, the
        // dedup guard returned false without setting isManual, so the
        // sidebar remove button never appeared.
        final file = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await file.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          manualPaths: [file.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        expect(result.items.length, equals(1));
        // Both provenance flags are true.
        expect(result.items.first.fromCatalog, isTrue);
        expect(result.items.first.fromManual, isTrue);
        // The derived getter is true, so the sidebar remove button appears.
        expect(result.items.first.isManual, isTrue);
      },
    );

    test(
      'provenance is correct for manual-only and catalog+manual files in one '
      'discovery pass (order-independence is guaranteed by the union logic)',
      () async {
        // NOTE: discoverConfigs always processes catalog targets before manual
        // paths, so both orders cannot be exercised at the discoverConfigs
        // level (addIfValid is a private closure). Order-independence holds by
        // construction: addIfValid unions provenance on a duplicate, so
        // whichever source is seen first, the later source's flag is OR'd in.
        // This test
        // asserts the resulting flags for both a manual-only and a
        // catalog+manual (dual-provenance) file.
        // Manual-only file: no catalog target matches.
        final manualOnly = File(p.join(mockHome.path, 'custom.json'));
        await manualOnly.create(recursive: true);

        // Dual-provenance file: matches a catalog target AND manual list.
        final dual = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await dual.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          manualPaths: [manualOnly.path, dual.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        final manualOnlyConfig = result.items.firstWhere(
          (i) => i.filePath == manualOnly.path,
        );
        final dualConfig = result.items.firstWhere(
          (i) => i.filePath == dual.path,
        );

        expect(manualOnlyConfig.fromManual, isTrue);
        expect(manualOnlyConfig.fromCatalog, isFalse);
        expect(manualOnlyConfig.isManual, isTrue);

        // Dual-provenance: both flags true.
        expect(dualConfig.fromManual, isTrue);
        expect(dualConfig.fromCatalog, isTrue);
        expect(dualConfig.isManual, isTrue);
      },
    );

    test(
      'removing manual-only file drops it entirely '
      '(re-discovery without manual path)',
      () async {
        final manualOnly = File(p.join(mockHome.path, 'custom.json'));
        await manualOnly.create(recursive: true);

        // First discovery: file is manual-only.
        final requestWith = DiscoveryRequest(
          manualPaths: [manualOnly.path],
        );
        final result1 = await discoveryService.discoverConfigs(requestWith);
        expect(result1.items.length, equals(1));
        expect(result1.items.first.isManual, isTrue);

        // Simulate removeManualPath: re-discover without the manual path.
        const requestWithout = DiscoveryRequest();
        final result2 = await discoveryService.discoverConfigs(requestWithout);
        expect(result2.items, isEmpty);
      },
    );

    test(
      'removing manual from dual-provenance file keeps catalog entry',
      () async {
        final file = File(
          p.join(mockHome.path, '.claude', 'settings.json'),
        );
        await file.create(recursive: true);

        // First discovery: dual provenance.
        final requestWith = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          manualPaths: [file.path],
        );
        final result1 = await discoveryService.discoverConfigs(requestWith);
        expect(result1.items.length, equals(1));
        expect(result1.items.first.fromCatalog, isTrue);
        expect(result1.items.first.fromManual, isTrue);

        // Simulate removeManualPath: re-discover without manual path.
        // Catalog entry remains.
        final requestWithout = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
        );
        final result2 = await discoveryService.discoverConfigs(requestWithout);
        expect(result2.items.length, equals(1));
        expect(result2.items.first.fromCatalog, isTrue);
        expect(result2.items.first.fromManual, isFalse);
        expect(result2.items.first.isManual, isFalse);
      },
    );
  });
}

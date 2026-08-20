import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory mockHome;
  late Directory mockProject;
  late DiscoveryService discoveryService;

  setUp(() async {
    mockHome = await Directory.systemTemp.createTemp('discovery_home_');
    mockProject = await Directory.systemTemp.createTemp('discovery_project_');
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

  group('DiscoveryService Phase 10 coverage', () {
    test(
      'discoverConfigs discovers new Phase 10 tools',
      () async {
        final kiloFile = File(p.join(mockProject.path, 'kilo.jsonc'));
        await kiloFile.create(recursive: true);

        final clineFile = File(
          p.join(mockHome.path, '.cline', 'rules', 'coding.md'),
        );
        await clineFile.create(recursive: true);

        final lmStudioFile = File(
          p.join(
            mockHome.path,
            '.lmstudio',
            'hub',
            'models',
            'bytedance',
            'foo',
            'model.yaml',
          ),
        );
        await lmStudioFile.create(recursive: true);

        final clinerulesDirFile = File(
          p.join(mockProject.path, '.clinerules', '01-coding.md'),
        );
        await clinerulesDirFile.create(recursive: true);

        final copilotFile = File(
          p.join(mockProject.path, '.github', 'copilot-instructions.md'),
        );
        await copilotFile.create(recursive: true);

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
          normalizedProjectRoots: [mockProject.path],
        );

        final result = await discoveryService.discoverConfigs(request);

        final kiloConfig = result.items.firstWhere(
          (item) => item.filePath == kiloFile.path,
        );
        expect(kiloConfig.sourceLabel, equals('Kilo'));
        expect(kiloConfig.scope, equals(ConfigLocationScope.project));

        final clineConfig = result.items.firstWhere(
          (item) => item.filePath == clineFile.path,
        );
        expect(clineConfig.sourceLabel, equals('Cline'));
        expect(clineConfig.scope, equals(ConfigLocationScope.user));
        expect(clineConfig.kind, equals(ConfigSourceKind.instructionDocument));

        final lmStudioConfig = result.items.firstWhere(
          (item) => item.filePath == lmStudioFile.path,
        );
        expect(lmStudioConfig.sourceLabel, equals('LM Studio'));
        expect(lmStudioConfig.format, equals(ConfigFormat.yaml));

        final copilotConfig = result.items.firstWhere(
          (item) => item.filePath == copilotFile.path,
        );
        expect(copilotConfig.sourceLabel, equals('GitHub Copilot'));
        expect(copilotConfig.scope, equals(ConfigLocationScope.project));

        final clinerulesConfig = result.items.firstWhere(
          (item) => item.filePath == clinerulesDirFile.path,
        );
        expect(clinerulesConfig.sourceLabel, equals('Cline'));
        expect(clinerulesConfig.scope, equals(ConfigLocationScope.project));
        expect(
          clinerulesConfig.kind,
          equals(ConfigSourceKind.instructionDocument),
        );

        final sharedAgents = File(p.join(mockProject.path, 'AGENTS.md'));
        await sharedAgents.create(recursive: true);
        final sharedResult = await discoveryService.discoverConfigs(
          DiscoveryRequest(
            normalizedHomePath: mockHome.path,
            normalizedProjectRoots: [mockProject.path],
          ),
        );
        final sharedConfig = sharedResult.items.firstWhere(
          (item) => item.filePath == sharedAgents.path,
        );
        expect(sharedConfig.sourceLabel, equals('AGENTS.md (shared)'));
        expect(sharedConfig.scope, equals(ConfigLocationScope.project));

        final kiloJson = File(p.join(mockProject.path, 'kilo.json'));
        await kiloJson.create(recursive: true);
        final clineLinuxRules = File(
          p.join(mockHome.path, 'Cline', 'Rules', 'linux.md'),
        );
        await clineLinuxRules.create(recursive: true);
        final copilotPersonal = File(
          p.join(mockHome.path, '.copilot', 'copilot-instructions.md'),
        );
        await copilotPersonal.create(recursive: true);
        final copilotModular = File(
          p.join(
            mockHome.path,
            '.copilot',
            'instructions',
            'style',
            'code.instructions.md',
          ),
        );
        await copilotModular.create(recursive: true);

        final coverageResult = await discoveryService.discoverConfigs(
          DiscoveryRequest(
            normalizedHomePath: mockHome.path,
            normalizedProjectRoots: [mockProject.path],
          ),
        );
        expect(
          coverageResult.items.any((i) => i.filePath == kiloJson.path),
          isTrue,
        );
        expect(
          coverageResult.items.any((i) => i.filePath == clineLinuxRules.path),
          isTrue,
        );
        expect(
          coverageResult.items.any((i) => i.filePath == copilotPersonal.path),
          isTrue,
        );
        expect(
          coverageResult.items.any((i) => i.filePath == copilotModular.path),
          isTrue,
        );
      },
    );

    test(
      'single-segment glob does not miss direct children amid deep noise',
      () async {
        // Low visit cap: if recursion were wrongly enabled for `*.mdc`,
        // deep noise would trip the cap before the direct sibling is seen.
        const capped = DiscoveryService(maxGlobEntitiesVisited: 40);
        final rulesDir = Directory(
          p.join(mockProject.path, '.cursor', 'rules'),
        );
        await rulesDir.create(recursive: true);
        final direct = File(p.join(rulesDir.path, 'keep.mdc'));
        await direct.create();

        final deep = Directory(p.join(rulesDir.path, 'archive', 'nested'));
        await deep.create(recursive: true);
        for (var i = 0; i < 80; i++) {
          await File(p.join(deep.path, 'noise$i.bin')).create();
        }

        final result = await capped.discoverConfigs(
          DiscoveryRequest(normalizedProjectRoots: [mockProject.path]),
        );

        expect(
          result.items.any((item) => item.filePath == direct.path),
          isTrue,
        );
        expect(
          result.warnings.any((w) => w.message.contains('visit cap')),
          isFalse,
        );
      },
    );

    test(
      'glob enumeration emits warning when visit cap is hit',
      () async {
        // Nested glob under a large tree of non-matching files must stop
        // walking (visit cap) rather than scanning forever waiting for matches.
        const capped = DiscoveryService(maxGlobEntitiesVisited: 40);
        final modelsDir = Directory(
          p.join(mockHome.path, '.lmstudio', 'hub', 'models'),
        );
        await modelsDir.create(recursive: true);

        for (var i = 0; i < 80; i++) {
          await File(p.join(modelsDir.path, 'noise$i.bin')).create();
        }

        final request = DiscoveryRequest(
          normalizedHomePath: mockHome.path,
        );

        final result = await capped.discoverConfigs(request);

        expect(
          result.warnings.any(
            (w) =>
                w.path.contains('.lmstudio') &&
                w.message.contains('40-entity visit cap'),
          ),
          isTrue,
        );
      },
    );
  });
}

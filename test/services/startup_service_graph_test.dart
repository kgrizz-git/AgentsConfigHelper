import 'dart:io';

import 'package:agents_config_helper/main.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('ordinary startup keeps the unguarded service graph', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'startup_service_graph_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    TestRootConfiguration? resolvedTestRoot;

    final services = await buildStartupServiceGraph(
      const [],
      backupDirectoryResolver: (testRoot) async {
        resolvedTestRoot = testRoot;
        return Directory(p.join(temporaryDirectory.path, 'backups'));
      },
    );

    expect(resolvedTestRoot, isNull);
    expect(services.testRoot, isNull);
    expect(services.fileOperations, isA<LocalFileOperations>());
    expect(services.preferencesStore, isNull);
    expect(services.discoveryService, isNull);

    final configFile = File(p.join(temporaryDirectory.path, 'settings.json'));
    await configFile.writeAsString('{"mode":"before"}');
    final config = ToolConfig(
      toolName: 'Test',
      filePath: configFile.path,
      format: ConfigFormat.json,
      originalContent: '{"mode":"before"}',
    );

    await services.configService.saveRawConfig(config, '{"mode":"after"}');

    expect(await configFile.readAsString(), '{"mode":"after"}');
    expect(
      await services.configService.backupService.listBackups(configFile.path),
      hasLength(1),
    );
  });
}

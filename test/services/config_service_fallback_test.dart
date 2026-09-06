import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ConfigService fallback and allowRewrite', () {
    late Directory tempDir;
    late BackupService backupService;
    late ConfigService configService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'config_service_fallback_test_',
      );
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      backupService = BackupService(backupDirectory: backupDir);
      configService = ConfigService(backupService: backupService);
    });

    tearDown(() async {
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveConfig blocks YAML fallback and does not write', () async {
      final yamlFile = File(p.join(tempDir.path, 'alias_config.yaml'));
      await yamlFile.create(recursive: true);
      const originalContent = '''
base: &base
  timeout: 30
override:
  <<: *base
  timeout: 60
rules:
  - rule1
''';
      await yamlFile.writeAsString(originalContent);

      final config = await _load(configService, yamlFile.path);
      final updated = config.copyWith(
        rawSettings: {
          'base': {'timeout': 45},
          'override': {'timeout': 90},
        },
      );

      await expectLater(
        () => configService.saveConfig(updated),
        throwsA(isA<SerializationFallbackException>()),
      );

      // File and backup must be untouched.
      expect(await yamlFile.readAsString(), equals(originalContent));
      if (backupService.backupDirectory.existsSync()) {
        expect(backupService.backupDirectory.listSync(), isEmpty);
      }
    });

    test('saveConfig allows rewrite when explicitly opted in', () async {
      final yamlFile = File(p.join(tempDir.path, 'alias_config_rewrite.yaml'));
      await yamlFile.create(recursive: true);
      const originalContent = '''
base: &base
  timeout: 30
override:
  <<: *base
  timeout: 60
rules:
  - rule1
''';
      await yamlFile.writeAsString(originalContent);

      final config = await _load(configService, yamlFile.path);
      final updated = config.copyWith(
        rawSettings: {
          'base': {'timeout': 45},
          'override': {'timeout': 90},
        },
      );

      final result = await configService.saveConfig(
        updated,
        allowRewrite: true,
      );

      expect(result.rules, equals(['rule1']));
      expect(await yamlFile.readAsString(), contains('timeout: 45'));
      expect(await yamlFile.readAsString(), contains('timeout: 90'));

      final backups = backupService.backupDirectory.listSync();
      expect(backups.length, equals(1));
    });

    test(
      'saveRawConfig merge blocks YAML fallback and does not write',
      () async {
        final yamlFile = File(p.join(tempDir.path, 'raw_alias_config.yaml'));
        await yamlFile.create(recursive: true);
        const originalContent = '''
base: &b
  - rule1
rules: *b
''';
        await yamlFile.writeAsString(originalContent);

        final config = await _load(configService, yamlFile.path);
        final structurallyEdited = config.copyWith(
          rules: ['rule1', 'rule2'],
          rawSettings: {
            'defaults': {'timeout': 45},
            'service': {'timeout': 90},
          },
        );
        const rawEdit = '''
base: &b
  - rule1
rules: *b
''';

        await expectLater(
          () => configService.saveRawConfig(structurallyEdited, rawEdit),
          throwsA(isA<SerializationFallbackException>()),
        );

        expect(await yamlFile.readAsString(), equals(originalContent));
        expect(
          !backupService.backupDirectory.existsSync() ||
              backupService.backupDirectory.listSync().isEmpty,
          isTrue,
        );
      },
    );

    test('saveRawConfig direct raw write is never blocked', () async {
      final yamlFile = File(p.join(tempDir.path, 'direct_raw.yaml'));
      await yamlFile.create(recursive: true);
      const originalContent = '# comment\nrules:\n  - old\n';
      await yamlFile.writeAsString(originalContent);

      // rules match the baseline, so there is NO structured divergence: this
      // is a true direct raw write of rawEdit, never a merge/serialize.
      final config = ToolConfig(
        toolName: 'Test',
        filePath: yamlFile.path,
        format: ConfigFormat.yaml,
        originalContent: originalContent,
        rules: const ['old'],
      );

      const rawEdit = '# new comment\nrules:\n  - new\n';
      final updated = await configService.saveRawConfig(config, rawEdit);

      expect(await yamlFile.readAsString(), equals(rawEdit));
      expect(updated.originalContent, equals(rawEdit));
    });

    test('saveConfig new-file YAML is not spuriously blocked', () async {
      final newFile = File(p.join(tempDir.path, 'newdir', 'config.yaml'));
      final config = ToolConfig(
        toolName: 'Unknown',
        format: ConfigFormat.yaml,
        filePath: newFile.path,
        rules: const ['rule1'],
      );

      // A brand-new file has no baseline to lose; saveConfig must not throw a
      // SerializationFallbackException even though it serializes from scratch.
      final saved = await configService.saveConfig(config);
      expect(saved.format, equals(ConfigFormat.yaml));
      expect(newFile.existsSync(), isTrue);
    });
  });
}

Future<ToolConfig> _load(
  ConfigService service,
  String path, {
  String? home,
}) async {
  final match = ToolDescriptorRegistry.matchPath(
    path,
    normalizedHomePath: home ?? Directory.systemTemp.path,
  );
  return service.loadDiscoveredConfig(
    DiscoveredConfig.fromPath(
      filePath: path,
      sourceLabel: match.sourceLabel,
      format: match.format,
      scope: ConfigLocationScope.manual,
      kind: ConfigSourceKind.structuredConfig,
    ),
  );
}

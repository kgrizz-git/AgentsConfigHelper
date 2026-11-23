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
  group('ConfigService write safety', () {
    late Directory tempDir;
    late BackupService backupService;
    late ConfigService configService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'config_service_write_safety_test_',
      );
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      backupService = BackupService(backupDirectory: backupDir);
      configService = ConfigService(backupService: backupService);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveConfig refuses to clear a duplicated JSON key', () async {
      final file = File(p.join(tempDir.path, 'duplicate.json'));
      const original =
          '{"permissions": ["Bash(rm *)"], "permissions": ["Read"]}';
      await file.writeAsString(original);

      final config = await _load(configService, file.path);
      final cleared = config.copyWith(permissions: const []);

      await expectLater(
        configService.saveConfig(cleared),
        throwsA(isA<StructuredEditRefusedException>()),
      );

      expect(await file.readAsString(), original);
      expect(await backupService.listBackups(file.path), isEmpty);
    });

    test(
      'saveConfig preserves a non-list rules value while editing permissions',
      () async {
        final file = File(p.join(tempDir.path, 'nested_rules.json'));
        const original = '''
{
  "rules": {"custom": ["keep me"]},
  "permissions": ["read"]
}
''';
        await file.writeAsString(original);

        final config = await _load(configService, file.path);
        final updated = config.copyWith(permissions: ['read', 'write']);

        final saved = await configService.saveConfig(updated);
        final content = await file.readAsString();

        expect(saved.rules, isEmpty);
        expect(content, contains('"custom"'));
        expect(content, contains('"keep me"'));
        expect(content, contains('"write"'));
      },
    );

    test('saveConfig refuses to edit a mixed rules list', () async {
      final file = File(p.join(tempDir.path, 'mixed_rules.json'));
      const original = '{"rules": ["read", 42]}';
      await file.writeAsString(original);

      final config = await _load(configService, file.path);
      final updated = config.copyWith(rules: ['read', 'write']);

      await expectLater(
        configService.saveConfig(updated),
        throwsA(isA<StructuredEditRefusedException>()),
      );
      expect(await file.readAsString(), original);
    });

    test(
      'saveRawConfig keeps a raw rules edit and a structured permissions edit',
      () async {
        final file = File(p.join(tempDir.path, 'combined.json'));
        const original = '{"rules": ["read"], "permissions": ["a"]}';
        await file.writeAsString(original);

        final config = await _load(configService, file.path);
        final updated = config.copyWith(permissions: ['b']);
        const rawEdited = '{"rules": ["write"], "permissions": ["a"]}';

        final saved = await configService.saveRawConfig(updated, rawEdited);
        final content = await file.readAsString();

        expect(saved.rules, ['write']);
        expect(saved.permissions, ['b']);
        expect(content, contains('"write"'));
        expect(content, contains('"b"'));
      },
    );

    test(
      'allowRewrite cannot clear duplicates or unsupported shapes',
      () async {
        final file = File(p.join(tempDir.path, 'duplicate_rewrite.json'));
        const original = '{"permissions": ["a"], "permissions": ["b"]}';
        await file.writeAsString(original);

        final config = await _load(configService, file.path);
        final cleared = config.copyWith(permissions: const []);

        await expectLater(
          configService.saveConfig(cleared, allowRewrite: true),
          throwsA(isA<StructuredEditRefusedException>()),
        );
        expect(await file.readAsString(), original);
      },
    );
    test('saveRawConfig refuses same-field raw and structured edits', () async {
      final file = File(p.join(tempDir.path, 'contention.json'));
      const original = '{"rules": ["read"], "permissions": ["a"]}';
      await file.writeAsString(original);

      final config = await _load(configService, file.path);
      final updated = config.copyWith(rules: ['structured']);
      const rawEdited = '{"rules": ["raw"], "permissions": ["a"]}';

      await expectLater(
        configService.saveRawConfig(updated, rawEdited),
        throwsA(isA<StructuredEditRefusedException>()),
      );
      expect(await file.readAsString(), original);
    });
    test(
      'saveConfig refuses a strict JSON source with comments before writing',
      () async {
        final file = File(
          p.join(tempDir.path, '.claude', 'settings.json'),
        );
        await file.parent.create(recursive: true);
        const original = '{\n  // comment\n  "rules": ["a"]\n}';
        await file.writeAsString(original);
        final config = ToolConfig(
          toolName: 'Claude Code',
          filePath: file.path,
          format: ConfigFormat.json,
          rules: const ['a'],
          rawSettings: const {
            'rules': ['a'],
          },
          originalContent: original,
        );

        await expectLater(
          configService.saveConfig(config.copyWith(rules: const ['b'])),
          throwsA(isA<ConfigParseException>()),
        );

        expect(await file.readAsString(), original);
        expect(await backupService.listBackups(file.path), isEmpty);
      },
    );

    test(
      'saveRawConfig refuses JSONC for a strict target before writing',
      () async {
        final file = File(
          p.join(tempDir.path, '.claude', 'settings.json'),
        );
        await file.parent.create(recursive: true);
        const original = '{"rules": ["a"]}';
        await file.writeAsString(original);
        final config = await _load(configService, file.path);

        await expectLater(
          configService.saveRawConfig(
            config,
            '// comment\n{"rules": ["a"]}',
          ),
          throwsA(isA<ConfigParseException>()),
        );

        expect(await file.readAsString(), original);
        expect(await backupService.listBackups(file.path), isEmpty);
      },
    );
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
  return await service.loadDiscoveredConfig(
    DiscoveredConfig.fromPath(
      filePath: path,
      sourceLabel: match.sourceLabel,
      format: match.format,
      scope: ConfigLocationScope.manual,
      kind: ConfigSourceKind.structuredConfig,
    ),
  );
}

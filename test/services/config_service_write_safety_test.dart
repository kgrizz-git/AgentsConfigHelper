import 'dart:convert';
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
    test('previewSaveConfig commits exactly the previewed bytes', () async {
      final file = File(p.join(tempDir.path, 'preview.json'));
      await file.writeAsString('{"rules": ["old"], "permissions": ["a"]}');
      final config = await _load(configService, file.path);
      final updated = config.copyWith(rules: ['new']);

      final preview = await configService.previewSaveConfig(updated);

      expect(preview.content, contains('new'));
      await configService.commitSavePreview(preview);
      expect(await file.readAsBytes(), utf8.encode(preview.content));
    });

    test(
      'commitSavePreview refuses a source changed after preview',
      () async {
        final file = File(p.join(tempDir.path, 'conflict.json'));
        await file.writeAsString('{"rules": ["old"]}');
        final config = await _load(configService, file.path);
        final preview = await configService.previewSaveConfig(
          config.copyWith(rules: ['new']),
        );

        await file.writeAsString('{"rules": ["external"]}');

        await expectLater(
          configService.commitSavePreview(preview),
          throwsA(isA<SaveConflictException>()),
        );
        expect(await file.readAsString(), '{"rules": ["external"]}');
        expect(await backupService.listBackups(file.path), isEmpty);

        // Reloading and previewing against the new source commits.
        final reloaded = await _load(configService, file.path);
        final fresh = await configService.previewSaveConfig(
          reloaded.copyWith(rules: ['new']),
        );
        await configService.commitSavePreview(fresh);
        expect(await file.readAsString(), contains('"new"'));
      },
    );

    test('commitSavePreview refuses a created or deleted source', () async {
      final created = File(p.join(tempDir.path, 'created.json'));
      final createdConfig = ToolConfig(
        toolName: 'Test',
        filePath: created.path,
        format: ConfigFormat.json,
      );
      final createPreview = await configService.previewSaveConfig(
        createdConfig.copyWith(rules: ['a']),
      );
      await created.writeAsString('{"rules": ["external"]}');
      await expectLater(
        configService.commitSavePreview(createPreview),
        throwsA(isA<SaveConflictException>()),
      );

      final deleted = File(p.join(tempDir.path, 'deleted.json'));
      await deleted.writeAsString('{"rules": ["old"]}');
      final deletedConfig = await _load(configService, deleted.path);
      final deletePreview = await configService.previewSaveConfig(
        deletedConfig.copyWith(rules: ['new']),
      );
      await deleted.delete();
      await expectLater(
        configService.commitSavePreview(deletePreview),
        throwsA(isA<SaveConflictException>()),
      );
      expect(deleted.existsSync(), isFalse);
    });
    test('preview refuses a source changed after load', () async {
      final file = File(p.join(tempDir.path, 'stale.json'));
      await file.writeAsString('{"rules": ["old"]}');
      final config = await _load(configService, file.path);
      await file.writeAsString('{"rules": ["external"]}');

      await expectLater(
        configService.previewSaveConfig(config.copyWith(rules: ['new'])),
        throwsA(isA<SaveConflictException>()),
      );
      await expectLater(
        configService.previewSaveRaw(config, '{"rules": ["raw"]}'),
        throwsA(isA<SaveConflictException>()),
      );
      expect(await file.readAsString(), '{"rules": ["external"]}');
    });

    test('preview with allowRewrite renders a TOML rewrite', () async {
      final file = File(p.join(tempDir.path, 'commented.toml'));
      await file.writeAsString('# keep this comment\nrules = ["old"]\n');
      final config = await _load(configService, file.path);
      final updated = config.copyWith(rules: ['new']);

      await expectLater(
        configService.previewSaveConfig(updated),
        throwsA(isA<SerializationFallbackException>()),
      );
      final preview = await configService.previewSaveConfig(
        updated,
        allowRewrite: true,
      );
      expect(preview.usedFallback, isTrue);
      expect(preview.content, contains('new'));
    });

    test(
      'confirmed overwrite commits over a changed structured source',
      () async {
        final file = File(p.join(tempDir.path, 'overwrite.json'));
        await file.writeAsString('{"rules": ["old"]}');
        final config = await _load(configService, file.path);
        await file.writeAsString('{"rules": ["external"]}');

        await expectLater(
          configService.previewSaveConfig(config.copyWith(rules: ['mine'])),
          throwsA(isA<SaveConflictException>()),
        );

        final preview = await configService.previewSaveConfig(
          config.copyWith(rules: ['mine']),
          overwriteConfirmed: true,
        );
        expect(preview.sourceContent, '{"rules": ["external"]}');
        expect(preview.content, contains('mine'));
        expect(preview.content, isNot(contains('external')));

        final saved = await configService.commitSavePreview(preview);
        expect(saved.rules, ['mine']);
        expect(await file.readAsString(), isNot(contains('external')));
      },
    );

    test(
      'confirmed overwrite commits raw content over a changed source',
      () async {
        final file = File(p.join(tempDir.path, 'overwrite-raw.json'));
        await file.writeAsString('{"rules": ["old"]}');
        final config = await _load(configService, file.path);
        await file.writeAsString('{"rules": ["external"]}');

        final preview = await configService.previewSaveRaw(
          config,
          '{"rules": ["raw"]}',
          overwriteConfirmed: true,
        );
        expect(preview.sourceContent, '{"rules": ["external"]}');

        await configService.commitSavePreview(preview);
        expect(await file.readAsString(), '{"rules": ["raw"]}');
      },
    );

    test('confirmed overwrite recreates a deleted source', () async {
      final file = File(p.join(tempDir.path, 'overwrite-deleted.json'));
      await file.writeAsString('{"rules": ["old"]}');
      final config = await _load(configService, file.path);
      await file.delete();

      await expectLater(
        configService.previewSaveConfig(config.copyWith(rules: ['mine'])),
        throwsA(isA<SaveConflictException>()),
      );

      final preview = await configService.previewSaveConfig(
        config.copyWith(rules: ['mine']),
        overwriteConfirmed: true,
      );
      expect(preview.sourceExists, isFalse);
      await configService.commitSavePreview(preview);
      expect(await file.readAsString(), contains('mine'));
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

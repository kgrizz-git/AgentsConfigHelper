import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ConfigService', () {
    late Directory tempDir;
    late BackupService backupService;
    late ConfigService configService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('config_service_test_');
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

    test(
      'loadConfig correctly identifies JSON and parses based on known target',
      () async {
        final homeStr =
            Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            tempDir.path;
        final jsonFile = File(p.join(homeStr, '.claude', 'settings.json'));
        await jsonFile.parent.create(recursive: true);
        await jsonFile.writeAsString('{"rules": ["r1"]}');

        final serviceWithHome = ConfigService(
          backupService: backupService,
          homeDirectoryResolver: () => homeStr,
        );

        final config = await _load(serviceWithHome, jsonFile.path);

        expect(config.toolName, equals('Claude Code'));
        expect(config.rules, equals(['r1']));
      },
    );

    test('saveConfig creates backup and writes to disk', () async {
      final jsonFile = File(
        p.join(tempDir.path, '.cursor', 'permissions.json'),
      );
      await jsonFile.create(recursive: true);
      await jsonFile.writeAsString('{"rules": ["old"]}');

      final config = await _load(configService, jsonFile.path);
      final updatedConfig = config.copyWith(rules: ['new']);

      await configService.saveConfig(updatedConfig);

      // Verify file was updated
      final newContent = await jsonFile.readAsString();
      expect(newContent, contains('"new"'));
      expect(newContent, isNot(contains('"old"')));

      // Verify backup was created
      final backupDir = backupService.backupDirectory;
      final backups = backupDir.listSync();
      expect(backups.length, equals(1));

      final backupContent = await File(backups.first.path).readAsString();
      expect(backupContent, contains('"old"'));
    });

    test('loadConfig maps YAML correctly based on known target', () async {
      final homeStr =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          tempDir.path;
      final yamlFile = File(
        p.join(homeStr, '.kiro', 'settings', 'permissions.yaml'),
      );
      await yamlFile.parent.create(recursive: true);
      await yamlFile.writeAsString('rules:\n  - r1');

      final serviceWithHome = ConfigService(
        backupService: backupService,
        homeDirectoryResolver: () => homeStr,
      );

      final config = await _load(serviceWithHome, yamlFile.path);
      expect(config.toolName, equals('Kiro'));
    });

    test('loadConfig maps TOML correctly based on known target', () async {
      final homeStr =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          tempDir.path;
      final tomlFile = File(p.join(homeStr, '.codex', 'config.toml'));
      await tomlFile.parent.create(recursive: true);
      await tomlFile.writeAsString('rules = ["r1"]');

      final serviceWithHome = ConfigService(
        backupService: backupService,
        homeDirectoryResolver: () => homeStr,
      );

      final config = await _load(serviceWithHome, tomlFile.path);
      expect(config.toolName, equals('Codex'));
    });

    test('loadConfig falls back to manual unknown configuration', () async {
      final manualFile = File(p.join(tempDir.path, 'some_manual.json'));
      await manualFile.writeAsString('{"rules": ["r1"]}');

      final config = await _load(configService, manualFile.path);
      expect(config.toolName, equals('Unknown configuration'));
    });

    test(
      'loadDiscoveredConfig loads configuration using explicitly passed DiscoveredConfig',
      () async {
        final jsonFile = File(p.join(tempDir.path, 'some_config.json'));
        await jsonFile.writeAsString('{"rules": ["r1"]}');

        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: jsonFile.path,
          scope: ConfigLocationScope.manual,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'My Label',
        );

        final config = await configService.loadDiscoveredConfig(
          discoveredConfig,
        );
        expect(config.toolName, equals('My Label'));
        expect(config.rules, equals(['r1']));
        expect(p.isAbsolute(config.filePath), isTrue);
      },
    );

    test('loadConfig successfully loads .jsonc manual path', () async {
      final jsoncFile = File(p.join(tempDir.path, 'manual_config.jsonc'));
      await jsoncFile.writeAsString('// comment\n{"rules": ["r2"]}');

      final config = await _load(configService, jsoncFile.path);

      expect(config.toolName, equals('Unknown configuration'));
      expect(config.rules, equals(['r2']));
      expect(config.format, equals(ConfigFormat.jsonc));
      expect(p.isAbsolute(config.filePath), isTrue);
    });

    test('saveConfig creates parent directory for new file', () async {
      final newFile = File(p.join(tempDir.path, 'newdir', 'config.json'));
      final config = ToolConfig(
        toolName: 'Unknown',
        format: ConfigFormat.json,
        filePath: newFile.path,
        rawSettings: const <String, dynamic>{},
      );

      await configService.saveConfig(config);
      expect(newFile.existsSync(), isTrue);
    });

    test(
      'saveRawConfig throws on invalid raw content and does not write',
      () async {
        final jsonFile = File(p.join(tempDir.path, 'raw_config.json'));
        await jsonFile.create(recursive: true);
        const originalContent = '{"rules": ["old"]}';
        await jsonFile.writeAsString(originalContent);

        final config = await _load(configService, jsonFile.path);

        await expectLater(
          () => configService.saveRawConfig(config, '{ invalid json'),
          throwsA(isA<Exception>()),
        );

        // Verify file is untouched
        final content = await jsonFile.readAsString();
        expect(content, equals(originalContent));

        // Verify no backup was created because validation failed early
        if (backupService.backupDirectory.existsSync()) {
          final backups = backupService.backupDirectory.listSync();
          expect(backups, isEmpty);
        }
      },
    );

    test('saveRawConfig creates backup and writes on valid content', () async {
      final jsonFile = File(p.join(tempDir.path, 'raw_config_2.json'));
      await jsonFile.create(recursive: true);
      const originalContent = '{"rules": ["old"]}';
      await jsonFile.writeAsString(originalContent);

      final config = await _load(configService, jsonFile.path);

      const validContent = '{"rules": ["new"]}';
      final updatedConfig = await configService.saveRawConfig(
        config,
        validContent,
      );

      expect(updatedConfig.rules, equals(['new']));

      // Verify file was updated
      final content = await jsonFile.readAsString();
      expect(content, equals(validContent));

      // Verify backup was created
      final backups = backupService.backupDirectory.listSync();
      expect(backups.length, equals(1));
    });
    test('loadConfig identifies JSONC and parses', () async {
      final jsoncPath = '${tempDir.path}/test_config.jsonc';
      final jsoncFile = File(jsoncPath);
      await jsoncFile.writeAsString('{"rules": ["test"]} // a comment\n');

      final config = await _load(configService, jsoncPath);
      expect(
        config.format,
        ConfigFormat.jsonc,
      ); // Parses as JSONC format under the hood
      expect(config.rules, ['test']);
    });

    test('saveConfig throws UnsupportedError for unknown format', () async {
      final config = ToolConfig(
        toolName: 'Unknown Tool',
        filePath: '${tempDir.path}/unknown_config.txt',
        format: ConfigFormat.unknown,
      );

      expect(() => configService.saveConfig(config), throwsUnsupportedError);
    });

    test('saveConfig expands bare ~ and saves correctly', () async {
      final homeStr =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          tempDir.path;
      final fileName =
          'config_service_expand_${DateTime.now().microsecondsSinceEpoch}.json';
      final configPath = '~/$fileName';
      final file = File(p.join(homeStr, fileName));
      addTearDown(() async {
        // Synchronous existence checks keep this cleanup concise.
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          await file.delete();
        }
      });

      final config = ToolConfig(
        toolName: 'Test Tool',
        format: ConfigFormat.json,
        filePath: configPath,
        rawSettings: const <String, dynamic>{},
      );

      await configService.saveConfig(config);
      expect(file.existsSync(), isTrue);
    });

    test('rejects a home-relative path when home cannot be resolved', () {
      final serviceWithoutHome = ConfigService(
        backupService: backupService,
        homeDirectoryResolver: () => null,
      );

      expect(
        () => serviceWithoutHome.resolvePath('~/.claude/settings.json'),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('Cannot resolve home directory'),
          ),
        ),
      );
    });
  });
}

Future<ToolConfig> _load(ConfigService service, String path) async {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  final match = ToolDescriptorRegistry.matchPath(
    path,
    normalizedHomePath: home,
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

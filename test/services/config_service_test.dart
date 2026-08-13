import 'dart:io';
import 'package:agents_config_helper/models/tool_config.dart';
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

    test('loadConfig correctly identifies JSON and parses', () async {
      final jsonFile = File(p.join(tempDir.path, '.claude', 'settings.json'));
      await jsonFile.create(recursive: true);
      await jsonFile.writeAsString('{"rules": ["r1"]}');

      final config = await configService.loadConfig(jsonFile.path);

      expect(config.toolName, equals('Claude'));
      expect(config.rules, equals(['r1']));
    });

    test('saveConfig creates backup and writes to disk', () async {
      final jsonFile = File(
        p.join(tempDir.path, '.cursor', 'permissions.json'),
      );
      await jsonFile.create(recursive: true);
      await jsonFile.writeAsString('{"rules": ["old"]}');

      final config = await configService.loadConfig(jsonFile.path);
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

    test('loadConfig throws FileSystemException if file does not exist', () {
      final missingFile = p.join(tempDir.path, 'missing.json');
      expect(
        () => configService.loadConfig(missingFile),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('loadConfig maps YAML correctly', () async {
      final yamlFile = File(
        p.join(tempDir.path, '.kiro', 'settings', 'permissions.yaml'),
      );
      await yamlFile.create(recursive: true);
      await yamlFile.writeAsString('rules:\n  - r1');

      final config = await configService.loadConfig(yamlFile.path);
      expect(config.toolName, equals('Kiro'));
    });

    test('loadConfig maps TOML correctly', () async {
      final tomlFile = File(p.join(tempDir.path, '.codex', 'config.toml'));
      await tomlFile.create(recursive: true);
      await tomlFile.writeAsString('rules = ["r1"]');

      final config = await configService.loadConfig(tomlFile.path);
      expect(config.toolName, equals('Codex'));
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
    test('loadConfig identifies JSONC and parses', () async {
      final jsoncPath = '${tempDir.path}/test_config.jsonc';
      final jsoncFile = File(jsoncPath);
      await jsoncFile.writeAsString('{"rules": ["test"]} // a comment\n');

      final config = await configService.loadConfig(jsoncPath);
      expect(
        config.format,
        ConfigFormat.json,
      ); // Parses as JSON format under the hood
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
  });
}

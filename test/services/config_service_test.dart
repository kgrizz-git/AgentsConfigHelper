import 'dart:io';
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
      if (tempDir.existsSync()) {
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
  });
}

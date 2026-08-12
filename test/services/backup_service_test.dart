import 'dart:io';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BackupService', () {
    late Directory tempDir;
    late Directory backupDir;
    late BackupService backupService;
    late File originalFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'agents_config_helper_test_',
      );
      backupDir = Directory(p.join(tempDir.path, 'backups'));
      backupService = BackupService(backupDirectory: backupDir);

      originalFile = File(p.join(tempDir.path, 'config.json'));
      await originalFile.writeAsString('{"key": "value"}');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('createBackup copies file and encodes original path', () async {
      final backupPath = await backupService.createBackup(originalFile.path);

      final backupFile = File(backupPath);
      expect(backupFile.existsSync(), isTrue);

      final content = await backupFile.readAsString();
      expect(content, equals('{"key": "value"}'));

      // Ensure the path was encoded correctly (e.g. slashes turned into __)
      final basename = p.basename(backupPath);
      expect(basename, contains('__config.json_'));
      expect(basename, endsWith('.bak'));
    });

    test(
      'createBackup throws FileSystemException if original file missing',
      () async {
        final missingPath = p.join(tempDir.path, 'missing.json');

        expect(
          () => backupService.createBackup(missingPath),
          throwsA(isA<FileSystemException>()),
        );
      },
    );

    test('restoreBackup overwrites target with backup contents', () async {
      final backupPath = await backupService.createBackup(originalFile.path);

      // Modify original file to simulate an edit
      await originalFile.writeAsString('{"key": "modified"}');
      expect(await originalFile.readAsString(), equals('{"key": "modified"}'));

      // Restore the backup
      await backupService.restoreBackup(backupPath, originalFile.path);

      // Verify original file has original contents again
      expect(await originalFile.readAsString(), equals('{"key": "value"}'));
    });

    test(
      'restoreBackup throws FileSystemException if backup missing',
      () async {
        final missingBackup = p.join(backupDir.path, 'missing.bak');

        expect(
          () => backupService.restoreBackup(missingBackup, originalFile.path),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  });
}

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
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('createBackup copies file and encodes original path', () async {
      final backupPath = await backupService.createBackup(originalFile.path);

      final backupFile = File(backupPath);
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      expect(await backupFile.exists(), isTrue);

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

    test(
      "listBackups does not return another path's backups when one path "
      'is a string prefix of another',
      () async {
        final shortPathFile = File(p.join(tempDir.path, 'app'));
        await shortPathFile.writeAsString('short');
        final longPathFile = File(p.join(tempDir.path, 'app_old'));
        await longPathFile.writeAsString('long');

        await backupService.createBackup(shortPathFile.path);
        await backupService.createBackup(longPathFile.path);

        final shortBackups = await backupService.listBackups(
          shortPathFile.path,
        );
        final longBackups = await backupService.listBackups(
          longPathFile.path,
        );

        expect(shortBackups, hasLength(1));
        expect(p.basename(shortBackups.single.path), contains('__app_'));
        expect(
          p.basename(shortBackups.single.path),
          isNot(contains('__app_old_')),
        );

        expect(longBackups, hasLength(1));
        expect(p.basename(longBackups.single.path), contains('__app_old_'));
      },
    );

    test('listBackups returns backups sorted most-recent first', () async {
      final backupPath1 = await backupService.createBackup(
        originalFile.path,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final backupPath2 = await backupService.createBackup(
        originalFile.path,
      );

      final backups = await backupService.listBackups(originalFile.path);

      expect(backups, hasLength(2));
      expect(backups.first.path, equals(backupPath2));
      expect(backups.last.path, equals(backupPath1));
    });

    test(
      'createBackup prunes backups per path beyond maxBackupsPerPath',
      () async {
        String? lastBackupPath;
        for (var i = 0; i < BackupService.maxBackupsPerPath + 3; i++) {
          lastBackupPath = await backupService.createBackup(originalFile.path);
        }

        final backups = await backupService.listBackups(originalFile.path);

        expect(backups, hasLength(BackupService.maxBackupsPerPath));
        expect(backups.first.path, equals(lastBackupPath));
      },
    );
  });
}

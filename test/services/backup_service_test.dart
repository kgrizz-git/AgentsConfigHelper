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

      // Ensure the path was encoded correctly (separators become %2F).
      final basename = p.basename(backupPath);
      expect(basename, contains('%2Fconfig.json_'));
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
        expect(p.basename(shortBackups.single.path), contains('%2Fapp_'));
        expect(
          p.basename(shortBackups.single.path),
          isNot(contains('%2Fapp_old_')),
        );

        expect(longBackups, hasLength(1));
        expect(p.basename(longBackups.single.path), contains('%2Fapp_old_'));
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
      'listBackups keeps paths distinct when the old encoding would collide',
      () async {
        // Under the previous "separator -> __" encoding, "<dir>/a/b" and a
        // file literally named "<dir>/a__b" both encoded to the same token, so
        // their backups listed and pruned together. The percent-style encoding
        // keeps them distinct.
        final nestedDir = Directory(p.join(tempDir.path, 'a'));
        await nestedDir.create();
        final nestedFile = File(p.join(nestedDir.path, 'b'));
        await nestedFile.writeAsString('nested');
        final literalFile = File(p.join(tempDir.path, 'a__b'));
        await literalFile.writeAsString('literal');

        final nestedBackup = await backupService.createBackup(nestedFile.path);
        final literalBackup = await backupService.createBackup(
          literalFile.path,
        );

        final nestedBackups = await backupService.listBackups(nestedFile.path);
        final literalBackups = await backupService.listBackups(
          literalFile.path,
        );

        expect(nestedBackups, hasLength(1));
        expect(nestedBackups.single.path, equals(nestedBackup));
        expect(literalBackups, hasLength(1));
        expect(literalBackups.single.path, equals(literalBackup));
      },
    );

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

    test(
      'restore over existing file should be preceded by createBackup '
      'to preserve current contents',
      () async {
        // Simulate the A1 safety pattern: backup before restore.
        final backupPath = await backupService.createBackup(originalFile.path);

        // Modify the original to simulate user edits.
        await originalFile.writeAsString('{"key": "edited"}');

        // Backup the edited version before restoring (the A1 fix).
        await backupService.createBackup(originalFile.path);

        // Restore the original backup.
        await backupService.restoreBackup(backupPath, originalFile.path);
        expect(await originalFile.readAsString(), equals('{"key": "value"}'));

        // The edited version should be available as a backup.
        final backups = await backupService.listBackups(originalFile.path);
        expect(backups.length, greaterThanOrEqualTo(2));
      },
    );

    test('restore of deleted file skips createBackup and succeeds', () async {
      final backupPath = await backupService.createBackup(originalFile.path);

      await originalFile.delete();
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      expect(await originalFile.exists(), isFalse);

      // The A1 pattern: guard createBackup with exists-check.
      // ignore: avoid_slow_async_io
      if (await originalFile.exists()) {
        await backupService.createBackup(originalFile.path);
      }
      await backupService.restoreBackup(backupPath, originalFile.path);

      expect(await originalFile.readAsString(), equals('{"key": "value"}'));
    });

    test('writeRestoredFile creates missing parent directories', () async {
      final backupPath = await backupService.createBackup(originalFile.path);
      final bytes = await File(backupPath).readAsBytes();
      final nestedTarget = File(
        p.join(tempDir.path, 'gone', 'nested', 'config.json'),
      );

      await backupService.writeRestoredFile(nestedTarget.path, bytes);

      expect(await nestedTarget.readAsString(), equals('{"key": "value"}'));
    });
  });
}

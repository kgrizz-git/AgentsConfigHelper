import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

/// A service responsible for backing up and restoring configuration files.
class BackupService {
  /// Creates backups in [backupDirectory].
  const BackupService({required this.backupDirectory});

  /// The application-managed directory that stores backups.
  final Directory backupDirectory;

  /// Creates a backup of the file at [originalPath].
  ///
  /// The backup is stored in [backupDirectory] with a timestamp appended
  /// to its filename. The original path is encoded into the filename to avoid
  /// collisions and maintain origin context without needing an external index.
  ///
  /// Returns the absolute path to the newly created backup file.
  /// Throws a [FileSystemException] if the original file does not exist.
  Future<String> createBackup(String originalPath) async {
    final originalFile = File(originalPath);
    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await originalFile.exists()) {
      throw FileSystemException(
        'Cannot backup non-existent file',
        originalPath,
      );
    }

    // Checking backup storage asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomId = Random().nextInt(1000000);

    // Encode the absolute path safely in the filename.
    // Replace OS path separators and colons (Windows drive letters) with '__'
    final safeOriginalPath = originalPath
        .replaceAll(Platform.pathSeparator, '__')
        .replaceAll(':', '_drive_');

    final backupNameWithContext =
        '${safeOriginalPath}_${timestamp}_$randomId.bak';
    final backupFile = File(
      p.join(backupDirectory.path, backupNameWithContext),
    );

    await originalFile.copy(backupFile.path);

    return backupFile.path;
  }

  /// Restores a backup from [backupPath] to [targetPath].
  ///
  /// Overwrites [targetPath] if it exists.
  /// Throws a [FileSystemException] if the backup file does not exist.
  Future<void> restoreBackup(String backupPath, String targetPath) async {
    final backupFile = File(backupPath);
    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await backupFile.exists()) {
      throw FileSystemException(
        'Cannot restore from non-existent backup',
        backupPath,
      );
    }

    final targetFile = File(targetPath);
    // Ensure the target directory exists before restoring
    final targetDir = targetFile.parent;
    // The asynchronous check avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    await backupFile.copy(targetPath);
  }

  /// Lists all backups for the given [originalPath].
  ///
  /// Returns a list of [File] objects representing the backups,
  /// sorted by creation time (most recent first, assuming timestamp in filename).
  Future<List<File>> listBackups(String originalPath) async {
    // Checking directory existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await backupDirectory.exists()) {
      return [];
    }

    final safeOriginalPath = originalPath
        .replaceAll(Platform.pathSeparator, '__')
        .replaceAll(':', '_drive_');

    final prefix = '${safeOriginalPath}_';

    final allEntities = await backupDirectory.list().toList();
    final backupFiles = allEntities
        .whereType<File>()
        .where((file) {
          final name = p.basename(file.path);
          return name.startsWith(prefix) && name.endsWith('.bak');
        })
        .toList();

    // Sort descending by filename (which includes the timestamp)
    backupFiles.sort((a, b) => b.path.compareTo(a.path));

    return backupFiles;
  }
}

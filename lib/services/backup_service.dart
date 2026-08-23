import 'dart:io';
import 'dart:math';

import 'package:agents_config_helper/services/file_operations.dart';
import 'package:path/path.dart' as p;

/// A service responsible for backing up and restoring configuration files.
class BackupService {
  /// Creates backups in [backupDirectory].
  const BackupService({
    required this.backupDirectory,
    FileOperations? fileOperations,
  }) : _fileOperations = fileOperations ?? const LocalFileOperations();

  /// The application-managed directory that stores backups.
  final Directory backupDirectory;
  final FileOperations _fileOperations;

  /// Maximum number of backups retained per original path. Older snapshots
  /// beyond this limit are pruned after each backup is created.
  static const int maxBackupsPerPath = 10;

  /// Creates a backup of the file at [originalPath].
  ///
  /// The backup is stored in [backupDirectory] with a timestamp appended
  /// to its filename. The original path is encoded into the filename to avoid
  /// collisions and maintain origin context without needing an external index.
  ///
  /// Returns the absolute path to the newly created backup file.
  /// Throws a [FileSystemException] if the original file does not exist.
  Future<String> createBackup(String originalPath) async {
    if (!await _fileOperations.fileExists(originalPath)) {
      throw FileSystemException(
        'Cannot backup non-existent file',
        originalPath,
      );
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomId = Random().nextInt(1000000);

    // Encode the absolute path into a collision-free, filename-safe token.
    final safeOriginalPath = _encodeOriginalPath(originalPath);

    final backupNameWithContext =
        '${safeOriginalPath}_${timestamp}_$randomId.bak';
    final backupPath = p.join(backupDirectory.path, backupNameWithContext);

    await _fileOperations.copyFile(originalPath, backupPath);

    await _pruneOldBackups(originalPath);

    return backupPath;
  }

  /// Enforces [maxBackupsPerPath] for [originalPath] by deleting the oldest
  /// snapshots beyond the cap. Best-effort: failures in listing or deleting
  /// never fail the save that just created the backup.
  Future<void> _pruneOldBackups(String originalPath) async {
    try {
      final backups = await listBackups(originalPath);
      if (backups.length <= maxBackupsPerPath) return;
      for (final backup in backups.sublist(maxBackupsPerPath)) {
        try {
          await _fileOperations.deleteFile(backup.path);
        } on Object {
          // One failed deletion must not abort pruning the rest.
        }
      }
    } on Object {
      // Retention is best-effort and must never fail a save.
    }
  }

  /// Restores a backup from [backupPath] to [targetPath].
  ///
  /// Overwrites [targetPath] if it exists.
  /// Throws a [FileSystemException] if the backup file does not exist.
  Future<void> restoreBackup(String backupPath, String targetPath) async {
    if (!await _fileOperations.fileExists(backupPath)) {
      throw FileSystemException(
        'Cannot restore from non-existent backup',
        backupPath,
      );
    }

    await _fileOperations.copyFile(backupPath, targetPath);
  }

  /// Writes restored [bytes] to [targetPath], creating missing parent
  /// directories first. Used when the caller already read the backup into
  /// memory (so retention pruning cannot delete the selected snapshot).
  Future<void> writeRestoredFile(String targetPath, List<int> bytes) async {
    await _fileOperations.writeBytes(targetPath, bytes);
  }

  /// Reads bytes from a backup using the configured file operation boundary.
  Future<List<int>> readBackupBytes(String backupPath) =>
      _fileOperations.readBytes(backupPath);

  /// Lists all backups for the given [originalPath].
  ///
  /// Returns a list of [File] objects representing the backups, sorted by
  /// creation time (most recent first, assuming timestamp in filename).
  Future<List<File>> listBackups(String originalPath) async {
    await _fileOperations.validatePath(originalPath);

    final safeOriginalPath = _encodeOriginalPath(originalPath);

    final backupFiles = (await _fileOperations.listFiles(backupDirectory.path))
        .map(File.new)
        .where((file) {
          final name = p.basename(file.path);
          // Match on the exact encoded-path prefix, not a string prefix: a
          // startsWith check would also match e.g. "%2Fapp_old_..." backups
          // when listing backups for "%2Fapp", since "app_old" starts with
          // "app_". Anchoring on the trailing "_<timestamp>_<random>.bak"
          // suffix and comparing the remainder for exact equality avoids that.
          final match = _backupFilenamePattern.firstMatch(name);
          return match != null && match.group(1) == safeOriginalPath;
        })
        .toList();

    // Sort by the parsed timestamp (most recent first) rather than by raw path
    // comparison, which is fragile for timestamps of differing digit lengths.
    return backupFiles..sort((a, b) {
      final byTime = _backupTimestamp(b).compareTo(_backupTimestamp(a));
      if (byTime != 0) return byTime;
      return b.path.compareTo(a.path);
    });
  }

  /// Extracts the microsecond timestamp embedded in a backup filename, or 0
  /// if the name does not match the expected pattern.
  static int _backupTimestamp(File file) {
    final match = _backupFilenamePattern.firstMatch(p.basename(file.path));
    final timestamp = match != null ? int.tryParse(match.group(2)!) : null;
    return timestamp ?? 0;
  }

  /// Encodes [originalPath] into a collision-free, filename-safe token.
  ///
  /// Percent-escapes the escape character (`%`) first, then the OS path
  /// separator and the drive colon. Escaping `%` first keeps the encoding
  /// injective: a literal marker in one path can no longer alias a separator
  /// in another (e.g. `/x%2Fy` and `/x/y` encode distinctly), which a plain
  /// separator substitution — `/` → `__` — did not guarantee.
  static String _encodeOriginalPath(String originalPath) {
    return originalPath
        .replaceAll('%', '%25')
        .replaceAll(Platform.pathSeparator, '%2F')
        .replaceAll(':', '%3A');
  }

  static final _backupFilenamePattern = RegExp(r'^(.*)_(\d+)_(\d+)\.bak$');
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Filesystem operations used by configuration, backup, and preference
/// services.
///
/// The default implementation uses `dart:io`. Test-root mode supplies a macOS
/// implementation backed by descriptor-relative native operations.
abstract interface class FileOperations {
  /// Validates that [absolutePath] is permitted for this implementation.
  Future<void> validatePath(String absolutePath);

  /// Returns whether [absolutePath] exists as a file.
  Future<bool> fileExists(String absolutePath);

  /// Returns whether [absolutePath] exists as a directory.
  Future<bool> directoryExists(String absolutePath);

  /// Reads UTF-8 text from [absolutePath].
  Future<String> readText(String absolutePath);

  /// Reads bytes from [absolutePath].
  Future<List<int>> readBytes(String absolutePath);

  /// Writes UTF-8 [text] to [absolutePath].
  Future<void> writeText(String absolutePath, String text);

  /// Writes [bytes] to [absolutePath].
  Future<void> writeBytes(String absolutePath, List<int> bytes);

  /// Copies [sourcePath] to [destinationPath].
  Future<void> copyFile(String sourcePath, String destinationPath);

  /// Lists immediate file paths below [absoluteDirectoryPath].
  Future<List<String>> listFiles(String absoluteDirectoryPath);

  /// Deletes the file at [absolutePath].
  Future<void> deleteFile(String absolutePath);

  /// Writes [text] atomically to [absolutePath].
  Future<void> writeTextAtomically(String absolutePath, String text);

  /// Writes [bytes] atomically to [absolutePath].
  ///
  /// The temporary file is created in the destination's directory so the
  /// final rename stays on one filesystem. A symlinked destination is resolved
  /// first; a dangling link is refused rather than replaced.
  Future<void> writeBytesAtomically(String absolutePath, List<int> bytes);

  /// Copies [sourcePath] to [destinationPath] atomically.
  ///
  /// The source file's mode is preserved where the platform exposes it.
  Future<void> copyFileAtomically(String sourcePath, String destinationPath);
}

/// The ordinary production filesystem implementation.
class LocalFileOperations implements FileOperations {
  /// Creates the production filesystem implementation.
  ///
  /// [temporaryFile] and [openFile] are test seams; production uses the
  /// short PID/timestamp/random temp name and the platform file handle.
  const new({this.temporaryFile, this.openFile});

  /// Returns the temporary path for the destination, or null for the default.
  final String Function(File destination)? temporaryFile;

  /// Opens the temporary file for writing, or null for the default handle.
  final RandomAccessFile Function(File file)? openFile;

  static final _random = Random();

  @override
  Future<void> validatePath(String absolutePath) async {
    if (!p.isAbsolute(absolutePath)) {
      throw FileSystemException('Path must be absolute', absolutePath);
    }
  }

  @override
  Future<bool> fileExists(String absolutePath) async =>
      File(absolutePath).existsSync();

  @override
  Future<bool> directoryExists(String absolutePath) async =>
      Directory(absolutePath).existsSync();

  @override
  Future<String> readText(String absolutePath) async {
    return await File(absolutePath).readAsString();
  }

  @override
  Future<List<int>> readBytes(String absolutePath) async {
    return await File(absolutePath).readAsBytes();
  }

  @override
  Future<void> writeText(String absolutePath, String text) async {
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  @override
  Future<void> writeBytes(String absolutePath, List<int> bytes) async {
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) async {
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    await File(sourcePath).copy(destinationPath);
  }

  @override
  Future<List<String>> listFiles(String absoluteDirectoryPath) async {
    final directory = Directory(absoluteDirectoryPath);
    if (!directory.existsSync()) return [];
    final entities = await directory.list().toList();
    return entities.whereType<File>().map((file) => file.path).toList();
  }

  @override
  Future<void> deleteFile(String absolutePath) => File(absolutePath).delete();

  @override
  Future<void> writeTextAtomically(String absolutePath, String text) =>
      writeBytesAtomically(absolutePath, utf8.encode(text));

  @override
  Future<void> writeBytesAtomically(
    String absolutePath,
    List<int> bytes,
  ) async {
    await validatePath(absolutePath);
    final targetPath = _resolveWriteTarget(absolutePath);
    final destination = File(targetPath);
    await destination.parent.create(recursive: true);
    await _writeAtomically(destination, bytes, _modeOf(targetPath));
  }

  @override
  Future<void> copyFileAtomically(
    String sourcePath,
    String destinationPath,
  ) async {
    await validatePath(sourcePath);
    await validatePath(destinationPath);
    final bytes = await File(sourcePath).readAsBytes();
    final sourceMode = _modeOf(sourcePath);
    final targetPath = _resolveWriteTarget(destinationPath);
    final destination = File(targetPath);
    await destination.parent.create(recursive: true);
    await _writeAtomically(
      destination,
      bytes,
      sourceMode ?? _modeOf(targetPath),
    );
  }

  /// Resolves a symlinked destination to its target so the link survives the
  /// rename. A dangling link is refused: the app never creates a file through
  /// a link whose target does not exist.
  String _resolveWriteTarget(String absolutePath) {
    if (FileSystemEntity.typeSync(absolutePath, followLinks: false) !=
        FileSystemEntityType.link) {
      return absolutePath;
    }
    try {
      return File(absolutePath).resolveSymbolicLinksSync();
    } on FileSystemException {
      throw FileSystemException(
        'Refusing to write through a symlink whose target does not exist; '
        'create the target first',
        absolutePath,
      );
    }
  }

  /// Returns the destination's permission bits, or null when it does not exist
  /// or the platform has no POSIX mode.
  int? _modeOf(String path) {
    if (Platform.isWindows) return null;
    try {
      final stat = FileStat.statSync(path);
      if (stat.type != FileSystemEntityType.file) return null;
      return stat.mode & 0x1FF;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeAtomically(
    File destination,
    List<int> bytes,
    int? mode,
  ) async {
    final temporary = File(
      temporaryFile?.call(destination) ?? _defaultTemporaryPath(destination),
    );
    var created = false;
    var published = false;
    RandomAccessFile? handle;
    try {
      temporary.createSync(exclusive: true);
      created = true;
      if (FileSystemEntity.isLinkSync(temporary.path)) {
        throw FileSystemException(
          'Refusing to write through a symlink',
          temporary.path,
        );
      }
      // Open the descriptor before applying the destination mode. Opening a
      // file whose preserved mode lacks owner-write (for example 0400) would
      // fail, so the mode is applied while the writable descriptor is already
      // open; writes through that descriptor are not re-checked.
      final opener = openFile;
      handle = opener != null
          ? opener(temporary)
          : temporary.openSync(mode: FileMode.writeOnly);
      try {
        // Dart has no public fchmod. The mode is therefore applied by path
        // while the exclusive, PID/timestamp/random-named temporary descriptor
        // is open. New files default to owner-only so a first save never
        // widens access.
        final effectiveMode = mode ?? (Platform.isWindows ? null : 0x180);
        if (effectiveMode != null && !Platform.isWindows) {
          final ProcessResult result;
          try {
            result = await Process.run('chmod', [
              effectiveMode.toRadixString(8),
              temporary.path,
            ]);
          } on ProcessException catch (error) {
            throw FileSystemException(
              'Could not apply the destination file mode: ${error.message}',
              destination.path,
            );
          }
          if (result.exitCode != 0) {
            throw FileSystemException(
              'Could not preserve the destination file mode',
              destination.path,
            );
          }
        }
        handle
          ..writeFromSync(bytes)
          ..flushSync();
      } finally {
        handle.closeSync();
        handle = null;
      }
      temporary.renameSync(destination.path);
      published = true;
    } finally {
      try {
        handle?.closeSync();
      } on Object {
        // The handle may already be closed, including a post-publication close
        // failure; cleanup must still run and the original failure must
        // rethrow.
      }
      if (created && !published && temporary.existsSync()) {
        try {
          temporary.deleteSync();
        } on FileSystemException {
          // Cleanup is best effort; the destination is untouched.
        }
      }
    }
  }

  static String _defaultTemporaryPath(File destination) {
    final unique = _random.nextInt(1 << 31).toRadixString(16);
    return p.join(
      destination.parent.path,
      '.agents-config-helper-'
      '${pid}_${DateTime.now().microsecondsSinceEpoch}_$unique.tmp',
    );
  }
}

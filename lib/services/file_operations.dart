import 'dart:io';

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
}

/// The ordinary production filesystem implementation.
class LocalFileOperations implements FileOperations {
  const LocalFileOperations();

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
    return File(absolutePath).readAsString();
  }

  @override
  Future<List<int>> readBytes(String absolutePath) async {
    return File(absolutePath).readAsBytes();
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
  Future<void> writeTextAtomically(String absolutePath, String text) async {
    final file = File(absolutePath);
    final parent = file.parent;
    await parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(file.path);
  }
}

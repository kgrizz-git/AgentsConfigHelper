import 'dart:io';

import 'package:agents_config_helper/services/file_operations.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Uses the macOS descriptor-relative test-root bridge for every file
/// operation.
class MacOSTestRootFileOperations implements FileOperations {
  /// Creates operations rooted at a canonical macOS test directory.
  MacOSTestRootFileOperations({
    required this.rootPath,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName) {
    if (!Platform.isMacOS) {
      throw UnsupportedError(
        'Test-root file operations are currently macOS-only.',
      );
    }
  }

  static const _channelName = 'agents_config_helper/test_root_file_operations';

  /// The canonical, non-symlink root accepted at startup.
  final String rootPath;
  final MethodChannel _channel;

  @override
  Future<void> validatePath(String absolutePath) async {
    _relativePath(absolutePath);
  }

  @override
  Future<bool> fileExists(String absolutePath) async {
    final result = await _channel.invokeMethod<bool>('fileExists', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
    });
    return result ?? false;
  }

  @override
  Future<bool> directoryExists(String absolutePath) async {
    final result = await _channel.invokeMethod<bool>('directoryExists', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
    });
    return result ?? false;
  }

  @override
  Future<String> readText(String absolutePath) async {
    final result = await _channel.invokeMethod<String>('readText', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
    });
    if (result == null) {
      throw FileSystemException(
        'Native read returned no content',
        absolutePath,
      );
    }
    return result;
  }

  @override
  Future<List<int>> readBytes(String absolutePath) async {
    final result = await _channel.invokeMethod<Uint8List>('readBytes', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
    });
    if (result == null) {
      throw FileSystemException('Native read returned no bytes', absolutePath);
    }
    return result;
  }

  @override
  Future<void> writeText(String absolutePath, String text) {
    return _channel.invokeMethod<void>('writeText', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
      'text': text,
    });
  }

  @override
  Future<void> writeBytes(String absolutePath, List<int> bytes) {
    return _channel.invokeMethod<void>('writeBytes', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) {
    return _channel.invokeMethod<void>('copyFile', {
      'rootPath': rootPath,
      'sourceRelativePath': _relativePath(sourcePath),
      'destinationRelativePath': _relativePath(destinationPath),
    });
  }

  @override
  Future<List<String>> listFiles(String absoluteDirectoryPath) async {
    final result = await _channel.invokeListMethod<String>('listFiles', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absoluteDirectoryPath),
    });
    return [
      for (final name in result ?? const <String>[])
        p.join(absoluteDirectoryPath, name),
    ];
  }

  @override
  Future<void> deleteFile(String absolutePath) {
    return _channel.invokeMethod<void>('deleteFile', {
      'rootPath': rootPath,
      'relativePath': _relativePath(absolutePath),
    });
  }

  @override
  Future<void> writeTextAtomically(String absolutePath, String text) {
    return writeText(absolutePath, text);
  }

  String _relativePath(String absolutePath) {
    // Reject before the native bridge sees an untrusted, outside-root path.
    final normalized = p.normalize(p.absolute(absolutePath));
    if (!p.isWithin(rootPath, normalized)) {
      throw FileSystemException('Path is outside the test root', normalized);
    }
    return p.relative(normalized, from: rootPath);
  }
}

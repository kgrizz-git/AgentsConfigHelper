import 'dart:io';

import 'package:path/path.dart' as p;

/// The marker a staging script must create before test-root mode can start.
const testRootMarkerFileName = '.agents-config-helper-test-root';

/// The exact marker content shared with the staging and cleanup scripts.
const testRootMarkerContents = 'agents-config-helper staging root v1';

/// Validated startup configuration for macOS test-root mode.
class TestRootConfiguration {
  const TestRootConfiguration._(this.rootPath);

  /// Canonical path of the staging root.
  final String rootPath;

  /// Parses and validates an optional `--test-root=<absolute-path>` argument.
  static Future<TestRootConfiguration?> fromArguments(
    List<String> arguments, {
    bool? platformIsMacOS,
  }) async {
    final matches = arguments
        .where((argument) => argument.startsWith('--test-root='))
        .toList();
    if (matches.isEmpty) return null;
    if (matches.length != 1) {
      throw ArgumentError('Pass --test-root exactly once.');
    }
    if (!(platformIsMacOS ?? Platform.isMacOS)) {
      throw UnsupportedError(
        'Test-root mode is currently supported only on macOS.',
      );
    }

    final rawPath = matches.single.substring('--test-root='.length);
    if (rawPath.isEmpty || !p.isAbsolute(rawPath)) {
      throw ArgumentError('Test root must be a non-empty absolute path.');
    }

    final normalized = p.normalize(rawPath);
    final entityType = FileSystemEntity.typeSync(
      normalized,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.link) {
      throw ArgumentError('Test root must not be a symbolic link.');
    }
    if (entityType != FileSystemEntityType.directory) {
      throw ArgumentError('Test root must be an existing directory.');
    }

    final canonicalPath = Directory(normalized).resolveSymbolicLinksSync();
    final markerPath = p.join(canonicalPath, testRootMarkerFileName);
    if (FileSystemEntity.typeSync(markerPath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw ArgumentError(
        'Test root must contain $testRootMarkerFileName created by the staging '
        'script.',
      );
    }
    if (await File(markerPath).readAsString() != testRootMarkerContents) {
      throw ArgumentError('Test root has an unexpected staging marker.');
    }
    return TestRootConfiguration._(canonicalPath);
  }
}

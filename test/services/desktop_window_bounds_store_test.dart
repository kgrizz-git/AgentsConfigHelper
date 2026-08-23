import 'dart:io';
import 'dart:ui';

import 'package:agents_config_helper/services/desktop_window_bounds_store.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopWindowBoundsStore', () {
    late Directory temporaryDirectory;
    late DesktopWindowBoundsStore store;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'window-bounds',
      );
      store = DesktopWindowBoundsStore(
        getDirectory: () async => temporaryDirectory,
      );
    });

    tearDown(() => temporaryDirectory.delete(recursive: true));

    test('saves and loads finite bounds', () async {
      const bounds = Rect.fromLTWH(100, 200, 1200, 800);

      await store.save(bounds);

      expect(await store.load(), bounds);
    });

    test('returns null for malformed or unusable stored values', () async {
      final file = File(
        '${temporaryDirectory.path}/desktop_window_bounds.json',
      );
      await file.writeAsString(
        '{"x": 0, "y": 0, "width": -1, "height": 600}',
      );

      expect(await store.load(), isNull);
    });

    test(
      'uses supplied file operations for contained preference I/O',
      () async {
        final operations = _RecordingFileOperations();
        final containedStore = DesktopWindowBoundsStore(
          getDirectory: () async => Directory('/contained/application-support'),
          fileOperations: operations,
        );

        await containedStore.save(const Rect.fromLTWH(10, 20, 800, 600));

        expect(
          operations.writtenPath,
          '/contained/application-support/desktop_window_bounds.json',
        );
      },
    );
  });
}

class _RecordingFileOperations implements FileOperations {
  String? writtenPath;

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) =>
      throw UnimplementedError();

  @override
  Future<void> deleteFile(String absolutePath) => throw UnimplementedError();

  @override
  Future<bool> directoryExists(String absolutePath) async => false;

  @override
  Future<bool> fileExists(String absolutePath) async => false;

  @override
  Future<List<String>> listFiles(String absoluteDirectoryPath) =>
      throw UnimplementedError();

  @override
  Future<List<int>> readBytes(String absolutePath) =>
      throw UnimplementedError();

  @override
  Future<String> readText(String absolutePath) => throw UnimplementedError();

  @override
  Future<void> validatePath(String absolutePath) => throw UnimplementedError();

  @override
  Future<void> writeBytes(String absolutePath, List<int> bytes) =>
      throw UnimplementedError();

  @override
  Future<void> writeText(String absolutePath, String text) =>
      throw UnimplementedError();

  @override
  Future<void> writeTextAtomically(String absolutePath, String text) async {
    writtenPath = absolutePath;
  }
}

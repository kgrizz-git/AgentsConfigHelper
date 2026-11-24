import 'dart:io';

import 'package:agents_config_helper/services/file_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalFileOperations atomic writes', () {
    late Directory tempDir;
    const operations = LocalFileOperations();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atomic_ops_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    String path(String name) => p.join(tempDir.path, name);

    Future<List<String>> entries() async {
      final names = await tempDir
          .list()
          .map((entity) => p.basename(entity.path))
          .toList();
      return names..sort();
    }

    test('writes text atomically and leaves no temporary files', () async {
      final target = path('config.json');

      await operations.writeTextAtomically(target, '{"a":1}');

      expect(await File(target).readAsString(), '{"a":1}');
      expect(await entries(), ['config.json']);
    });

    test('replaces an existing file without leaving temporary files', () async {
      final target = path('config.json');
      await File(target).writeAsString('old');

      await operations.writeTextAtomically(target, 'new');

      expect(await File(target).readAsString(), 'new');
      expect(await entries(), ['config.json']);
    });

    test('preserves the destination mode on POSIX', () async {
      if (Platform.isWindows) return;
      final target = path('config.json');
      await File(target).writeAsString('old');
      final chmod = Process.runSync('chmod', ['600', target]);
      expect(chmod.exitCode, 0);

      await operations.writeTextAtomically(target, 'new');

      final mode = (await FileStat.stat(target)).mode & 0x1FF;
      expect(mode, 0x180, reason: 'expected 0600 to be preserved');
    });

    test('writes through a symlink and keeps the link', () async {
      final target = path('target.json');
      final link = path('link.json');
      await File(target).writeAsString('old');
      await Link(link).create(target);

      await operations.writeTextAtomically(link, 'new');

      expect(FileSystemEntity.isLinkSync(link), isTrue);
      expect(await File(target).readAsString(), 'new');
      expect(await File(link).readAsString(), 'new');
    });

    test('refuses a dangling symlink and leaves it intact', () async {
      final link = path('link.json');
      final missing = path('missing.json');
      await Link(link).create(missing);

      await expectLater(
        operations.writeTextAtomically(link, 'new'),
        throwsA(isA<FileSystemException>()),
      );

      expect(FileSystemEntity.isLinkSync(link), isTrue);
      expect(File(missing).existsSync(), isFalse);
    });

    test('copyFileAtomically preserves content and source mode', () async {
      final source = path('source.json');
      final destination = path('destination.json');
      await File(source).writeAsString('source-content');
      if (!Platform.isWindows) {
        final chmod = Process.runSync('chmod', ['600', source]);
        expect(chmod.exitCode, 0);
      }

      await operations.copyFileAtomically(source, destination);

      expect(await File(destination).readAsString(), 'source-content');
      if (!Platform.isWindows) {
        expect((await FileStat.stat(destination)).mode & 0x1FF, 0x180);
      }
      expect(await entries(), ['destination.json', 'source.json']);
    });

    test('cleans up the temporary file when replacement fails', () async {
      final directory = Directory(path('dir'));
      await directory.create();

      await expectLater(
        operations.writeTextAtomically(directory.path, 'new'),
        throwsA(isA<FileSystemException>()),
      );

      expect(await entries(), ['dir']);
    });
    test('updates a destination whose mode lacks owner write', () async {
      if (Platform.isWindows) return;
      final target = path('read_only.json');
      await File(target).writeAsString('old');
      expect(Process.runSync('chmod', ['400', target]).exitCode, 0);

      await operations.writeTextAtomically(target, 'new');

      expect(await File(target).readAsString(), 'new');
      expect((await FileStat.stat(target)).mode & 0x1FF, 0x100);
    });

    test('creates a new file owner-only', () async {
      if (Platform.isWindows) return;
      final target = path('new.json');

      await operations.writeTextAtomically(target, 'new');

      expect((await FileStat.stat(target)).mode & 0x1FF, 0x180);
    });

    test(
      'concurrent writes to one destination leave no temporary files',
      () async {
        final target = path('concurrent.json');

        await Future.wait([
          operations.writeTextAtomically(target, 'one'),
          operations.writeTextAtomically(target, 'two'),
        ]);

        expect(await File(target).readAsString(), anyOf('one', 'two'));
        expect(await entries(), ['concurrent.json']);
      },
    );

    test(
      'does not delete a foreign file at a collided temporary path',
      () async {
        final target = path('config.json');
        await File(target).writeAsString('old');
        final temporary = path('fixed.tmp');
        await File(temporary).writeAsString('foreign');
        final operations = LocalFileOperations(
          temporaryFile: (_) => temporary,
        );

        await expectLater(
          operations.writeTextAtomically(target, 'new'),
          throwsA(isA<FileSystemException>()),
        );

        expect(await File(temporary).readAsString(), 'foreign');
        expect(await File(target).readAsString(), 'old');
      },
    );

    test('a non-FileSystemException close failure still cleans up', () async {
      final target = path('close.json');
      await File(target).writeAsString('old');
      final temporary = path('close.tmp');
      final operations = LocalFileOperations(
        temporaryFile: (_) => temporary,
        openFile: (_) => _CloseThrowingFile(),
      );

      await expectLater(
        operations.writeTextAtomically(target, 'new'),
        throwsA(isA<StateError>()),
      );

      expect(await File(target).readAsString(), 'old');
      expect(File(temporary).existsSync(), isFalse);
    });

    test('uses a short temporary basename for a long destination', () async {
      if (Platform.isWindows) return;
      final longName = '${'a' * 240}.json';
      final target = path(longName);

      await operations.writeTextAtomically(target, 'new');

      expect(await File(target).readAsString(), 'new');
      expect(await entries(), [longName]);
    });

    test('leaves the original untouched when the write cannot start', () async {
      if (Platform.isWindows || _isRoot()) return;
      final directory = Directory(path('locked'));
      await directory.create();
      final target = File(p.join(directory.path, 'config.json'));
      await target.writeAsString('original');
      expect(Process.runSync('chmod', ['500', directory.path]).exitCode, 0);
      addTearDown(() => Process.runSync('chmod', ['700', directory.path]));

      await expectLater(
        operations.writeTextAtomically(target.path, 'new'),
        throwsA(isA<FileSystemException>()),
      );

      expect(await target.readAsString(), 'original');
    });
  });
}

class _CloseThrowingFile implements RandomAccessFile {
  @override
  void closeSync() => throw StateError('close failed');

  @override
  void flushSync() {}

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool _isRoot() {
  final result = Process.runSync('id', ['-u']);
  return result.exitCode == 0 && '${result.stdout}'.trim() == '0';
}

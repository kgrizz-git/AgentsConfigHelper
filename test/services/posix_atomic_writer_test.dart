import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:agents_config_helper/services/posix_atomic_writer.dart';
import 'package:flutter_test/flutter_test.dart';

const _fileDescriptor = 10;
const _directoryDescriptor = 11;

class _FakeFileSystem implements PosixFileSystem {
  final calls = <String>[];
  final writes = <Uint8List>[];
  final unlinked = <String>[];
  final renamed = <(String, String)>[];
  int errno = 0;
  int? nextErrno;
  int openTemporaryResult = _fileDescriptor;
  int openDirectoryResult = _directoryDescriptor;
  int fchmodResult = 0;
  final fchmodResults = <int>[];
  int fsyncFileResult = 0;
  int fsyncDirectoryResult = 0;
  int closeFileResult = 0;
  int closeDirectoryResult = 0;
  final writeResults = <int>[];
  FileSystemException? renameError;

  @override
  int get errnoCode => errno;

  @override
  int openTemporary(String path, int mode) {
    calls.add('openTemporary');
    if (openTemporaryResult < 0) errno = nextErrno ?? 13;
    return openTemporaryResult;
  }

  @override
  int openDirectory(String path) {
    calls.add('openDirectory');
    if (openDirectoryResult < 0) errno = nextErrno ?? 13;
    return openDirectoryResult;
  }

  @override
  int fchmod(int fd, int mode) {
    calls.add('fchmod:$mode');
    final result = fchmodResults.isNotEmpty
        ? fchmodResults.removeAt(0)
        : fchmodResult;
    if (result != 0) errno = nextErrno ?? 13;
    return result;
  }

  @override
  int write(int fd, Uint8List bytes, int offset, int length) {
    calls.add('write');
    final requested = bytes.sublist(offset, offset + length);
    final result = writeResults.isNotEmpty ? writeResults.removeAt(0) : length;
    if (result < 0) {
      errno = nextErrno ?? 5;
      writes.add(Uint8List(0));
    } else {
      writes.add(Uint8List.fromList(requested.sublist(0, result)));
    }
    return result;
  }

  @override
  int fsync(int fd) {
    calls.add('fsync:$fd');
    final result = fd == _fileDescriptor
        ? fsyncFileResult
        : fsyncDirectoryResult;
    if (result != 0) errno = nextErrno ?? 5;
    return result;
  }

  @override
  int close(int fd) {
    calls.add('close:$fd');
    final result = fd == _fileDescriptor
        ? closeFileResult
        : closeDirectoryResult;
    if (result != 0) errno = nextErrno ?? 5;
    return result;
  }

  @override
  void rename(String from, String to) {
    calls.add('rename');
    final error = renameError;
    if (error != null) throw error;
    renamed.add((from, to));
  }

  @override
  void unlink(String path) {
    calls.add('unlink');
    unlinked.add(path);
  }
}

void main() {
  group('PosixAtomicWriter', () {
    late _FakeFileSystem files;
    late PosixAtomicWriter writer;
    final destination = File('/tmp/work/config.json');
    const tempPath = '/tmp/work/config.tmp';

    setUp(() {
      files = _FakeFileSystem();
      writer = PosixAtomicWriter(
        fileSystem: files,
        temporaryFile: (_) => tempPath,
      );
    });

    Future<void> write([List<int> bytes = const [1, 2, 3]]) {
      return writer.write(destination, bytes, 0x1A4);
    }

    test('applies the mode before writing and fsyncs the parent', () async {
      await write();

      expect(files.calls, [
        'openTemporary',
        'fchmod:420',
        'write',
        'fsync:10',
        'close:10',
        'openDirectory',
        'rename',
        'fsync:11',
        'close:11',
      ]);
      expect(files.writes.map((write) => write.toList()).toList(), [
        [1, 2, 3],
      ]);
      expect(files.renamed, [(tempPath, destination.path)]);
      expect(files.unlinked, isEmpty);
    });

    test('loops over partial writes', () async {
      files.writeResults.addAll([2, 1]);

      await write();

      expect(files.writes.map((write) => write.toList()).toList(), [
        [1, 2],
        [3],
      ]);
    });

    test('retries write after EINTR', () async {
      files
        ..writeResults.add(-1)
        ..nextErrno = 4;

      await write();

      expect(files.writes, hasLength(2));
      expect(files.renamed, hasLength(1));
    });

    test('refuses a zero-byte write and removes the temp', () async {
      files.writeResults.add(0);

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
      expect(files.calls, contains('close:10'));
    });

    test('aborts when the temporary file cannot be opened', () async {
      files
        ..openTemporaryResult = -1
        ..nextErrno = 13;

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.calls, ['openTemporary']);
      expect(files.unlinked, isEmpty);
    });

    test('retries fchmod after EINTR', () async {
      files
        ..fchmodResults.addAll([-1, 0])
        ..nextErrno = 4;

      await write();

      expect(
        files.calls.where((call) => call.startsWith('fchmod:')),
        hasLength(2),
      );
      expect(files.renamed, hasLength(1));
    });

    test('aborts when fchmod fails', () async {
      files
        ..fchmodResult = -1
        ..nextErrno = 13;

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.writes, isEmpty);
      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
    });

    test('aborts when the file fsync fails', () async {
      files.fsyncFileResult = -1;

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
    });

    test('aborts when the file close fails without closing twice', () async {
      files.closeFileResult = -1;

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.calls.where((call) => call == 'close:10'), hasLength(1));
      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
    });

    test('aborts when the parent directory cannot be opened', () async {
      files
        ..openDirectoryResult = -1
        ..nextErrno = 5;

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
      expect(files.calls, isNot(contains('fsync:11')));
    });

    test('skips directory fsync when the parent is not readable', () async {
      files
        ..openDirectoryResult = -1
        ..nextErrno = 13;

      await write();

      expect(files.renamed, hasLength(1));
      expect(files.calls, isNot(contains('fsync:11')));
      expect(files.unlinked, isEmpty);
    });

    test('bounds repeated EINTR retries', () async {
      files
        ..nextErrno = 4
        ..writeResults.addAll(List<int>.filled(9, -1));

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(
        files.calls.where((call) => call == 'write'),
        hasLength(9),
      );
      expect(files.unlinked, [tempPath]);
    });

    test('aborts and cleans up when rename fails', () async {
      files.renameError = const FileSystemException('rename failed');

      await expectLater(write(), throwsA(isA<FileSystemException>()));

      expect(files.renamed, isEmpty);
      expect(files.unlinked, [tempPath]);
      expect(files.calls, contains('close:11'));
    });

    test('post-publication parent failures keep the save successful', () async {
      files
        ..fsyncDirectoryResult = -1
        ..closeDirectoryResult = -1;

      await write();

      expect(files.renamed, hasLength(1));
      expect(files.unlinked, isEmpty);
    });
  });

  group('LibcPosixFileSystem open flags', () {
    test('uses arm64 Linux directory and no-follow flags', () {
      expect(
        LibcPosixFileSystem.temporaryFlagsFor(
          macOS: false,
          abi: Abi.linuxArm64,
        ),
        0x880C1,
      );
      expect(
        LibcPosixFileSystem.directoryFlagsFor(
          macOS: false,
          abi: Abi.linuxArm64,
        ),
        0x84000,
      );
    });

    test('keeps the existing x64 Linux flag values', () {
      expect(
        LibcPosixFileSystem.temporaryFlagsFor(
          macOS: false,
          abi: Abi.linuxX64,
        ),
        0xA00C1,
      );
      expect(
        LibcPosixFileSystem.directoryFlagsFor(
          macOS: false,
          abi: Abi.linuxX64,
        ),
        0x90000,
      );
    });
  });
}

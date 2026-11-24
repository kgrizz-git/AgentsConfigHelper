import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Low-level POSIX operations used by [PosixAtomicWriter].
abstract interface class PosixFileSystem {
  /// Opens an exclusive temporary file with owner-only creation.
  int openTemporary(String path, int mode);

  /// Opens a directory read-only for fsync.
  int openDirectory(String path);

  /// Applies [mode] to [fd].
  int fchmod(int fd, int mode);

  /// Writes a slice of [bytes] and returns the byte count or -1.
  int write(int fd, Uint8List bytes, int offset, int length);

  /// Flushes [fd] to the filesystem.
  int fsync(int fd);

  /// Closes [fd].
  int close(int fd);

  /// The errno captured by the last failed operation.
  int get errnoCode;

  /// Renames [from] onto [to].
  void rename(String from, String to);

  /// Removes [path] if it exists.
  void unlink(String path);
}

/// Replaces a destination through a POSIX descriptor with exact mode and fsync.
class PosixAtomicWriter {
  /// Creates a writer with an injectable native seam.
  const new({required this.fileSystem, this.temporaryFile});

  /// Native operations used by this writer.
  final PosixFileSystem fileSystem;

  /// Returns the temporary path for a destination, or null for the default.
  final String Function(File destination)? temporaryFile;

  static const _eintr = 4;
  static const _defaultMode = 0x180;
  static final _random = Random();

  /// Writes [bytes] to [destination] and publishes them atomically.
  ///
  /// A failure before the rename leaves the original untouched and removes
  /// only this call's temporary file. After the rename, parent-directory
  /// fsync/close failures are logged and the save still succeeds because the
  /// destination has already been replaced.
  Future<void> write(File destination, List<int> bytes, int? mode) async {
    final tempPath =
        temporaryFile?.call(destination) ?? _defaultTemporaryPath(destination);
    final data = Uint8List.fromList(bytes);
    final effectiveMode = mode ?? _defaultMode;
    var fd = -1;
    var dirFd = -1;
    var created = false;
    var published = false;
    try {
      fd = _retry(() => fileSystem.openTemporary(tempPath, _defaultMode));
      if (fd < 0) throw _error('open temporary file', tempPath);
      created = true;

      if (_retry(() => fileSystem.fchmod(fd, effectiveMode)) != 0) {
        throw _error('apply destination mode', tempPath);
      }

      var offset = 0;
      while (offset < data.length) {
        final written = _retry(
          () => fileSystem.write(fd, data, offset, data.length - offset),
        );
        if (written < 0) throw _error('write temporary file', tempPath);
        if (written == 0) {
          throw FileSystemException(
            'Temporary file write made no progress',
            tempPath,
          );
        }
        offset += written;
      }

      if (_retry(() => fileSystem.fsync(fd)) != 0) {
        throw _error('fsync temporary file', tempPath);
      }

      final fileFd = fd;
      fd = -1;
      if (fileSystem.close(fileFd) != 0) {
        throw _error('close temporary file', tempPath);
      }

      final parent = destination.parent.path;
      dirFd = _retry(() => fileSystem.openDirectory(parent));
      if (dirFd < 0) throw _error('open parent directory', parent);

      fileSystem.rename(tempPath, destination.path);
      published = true;

      _finishPublishedParent(dirFd);
      dirFd = -1;
    } on Object {
      if (fd >= 0) {
        try {
          fileSystem.close(fd);
        } on Object {
          // The descriptor state is unknown; do not retry a close.
        }
        fd = -1;
      }
      if (dirFd >= 0) {
        try {
          fileSystem.close(dirFd);
        } on Object {
          // Best effort after a failed publication path.
        }
        dirFd = -1;
      }
      if (created && !published) {
        try {
          fileSystem.unlink(tempPath);
        } on Object {
          // Cleanup is best effort; the destination is untouched.
        }
      }
      rethrow;
    }
  }

  void _finishPublishedParent(int dirFd) {
    try {
      final result = _retry(() => fileSystem.fsync(dirFd));
      if (result != 0) {
        debugPrint(
          'Parent-directory fsync failed after publication '
          '(errno ${fileSystem.errnoCode}); the new bytes remain.',
        );
      }
    } on Object catch (error) {
      debugPrint('Parent-directory fsync failed after publication: $error');
    }
    try {
      final result = fileSystem.close(dirFd);
      if (result != 0) {
        debugPrint(
          'Parent-directory close failed after publication '
          '(errno ${fileSystem.errnoCode}); the new bytes remain.',
        );
      }
    } on Object catch (error) {
      debugPrint('Parent-directory close failed after publication: $error');
    }
  }

  int _retry(int Function() operation) {
    while (true) {
      final result = operation();
      if (result < 0 && fileSystem.errnoCode == _eintr) continue;
      return result;
    }
  }

  FileSystemException _error(String operation, String path) {
    return FileSystemException(
      'Could not $operation (errno ${fileSystem.errnoCode})',
      path,
    );
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

/// libc-backed implementation for macOS and Linux.
class LibcPosixFileSystem implements PosixFileSystem {
  /// Creates a libc-backed filesystem.
  new();

  static final DynamicLibrary _lib = DynamicLibrary.process();

  static final int _tempFlags = Platform.isMacOS
      ? 0x1 | 0x200 | 0x800 | 0x100 | 0x1000000
      : 0x1 | 0x40 | 0x80 | 0x20000 | 0x80000;

  static final int _directoryFlags = Platform.isMacOS
      ? 0x100000 | 0x1000000
      : 0x10000 | 0x80000;

  static final int Function(Pointer<Utf8>, int, int) _open = _lib
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32, VarArgs<(Int,)>),
        int Function(Pointer<Utf8>, int, int)
      >('open');

  static final int Function(int, int) _fchmod = Platform.isMacOS
      ? _lib.lookupFunction<
          Int32 Function(Int32, Uint16),
          int Function(int, int)
        >(
          'fchmod',
        )
      : _lib.lookupFunction<
          Int32 Function(Int32, Uint32),
          int Function(int, int)
        >(
          'fchmod',
        );

  static final int Function(int, Pointer<Uint8>, int) _write = _lib
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
        int Function(int, Pointer<Uint8>, int)
      >('write');

  static final int Function(int) _fsync = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');

  static final int Function(int) _close = _lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  static final Pointer<Int32> Function() _errno = _lib
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        Platform.isMacOS ? '__error' : '__errno_location',
      );

  int _lastErrno = 0;

  @override
  int get errnoCode => _lastErrno;

  @override
  int openTemporary(String path, int mode) => _openPath(path, _tempFlags, mode);

  @override
  int openDirectory(String path) => _openPath(path, _directoryFlags, 0);

  @override
  int fchmod(int fd, int mode) => _record(_fchmod(fd, mode));

  @override
  int write(int fd, Uint8List bytes, int offset, int length) {
    final buffer = calloc<Uint8>(length);
    try {
      buffer
          .asTypedList(length)
          .setAll(0, bytes.sublist(offset, offset + length));
      return _record(_write(fd, buffer, length));
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  int fsync(int fd) => _record(_fsync(fd));

  @override
  int close(int fd) => _record(_close(fd));

  @override
  void rename(String from, String to) => File(from).renameSync(to);

  @override
  void unlink(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  int _openPath(String path, int flags, int mode) {
    final pathPointer = path.toNativeUtf8();
    try {
      final result = _open(pathPointer, flags, mode);
      if (result < 0) _lastErrno = _errno().value;
      return result;
    } finally {
      malloc.free(pathPointer);
    }
  }

  int _record(int result) {
    if (result < 0) _lastErrno = _errno().value;
    return result;
  }
}

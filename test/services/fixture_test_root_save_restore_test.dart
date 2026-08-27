// Fixture-level save → backup → restore under the test-root service layout
// (home resolver + application-support/backups).
//
// Two layers:
// 1. LocalFileOperations — portable ordinary-filesystem behavior on CI.
// 2. _RootBoundedLocalFileOperations — same layout plus the production-style
//    outside-root rejection that MacOSTestRootFileOperations enforces via
//    _relativePath. Native no-follow/symlink coverage stays in
//    macos_test_root_file_operations_test.dart.
//
// Restore steps mirror MainShell: readBackupBytes → optional createBackup when
// the live file still exists → writeRestoredFile.

import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const editedContent =
      '{\n'
      '  "permissions": {\n'
      '    "defaultMode": "default",\n'
      '    "allow": ["Read(./fixtures/**)"],\n'
      '    "ask": ["Bash(git status)"],\n'
      '    "deny": ["Read(./private/**)"]\n'
      '  },\n'
      '  "env": {\n'
      '    "FIXTURE_MODE": "true"\n'
      '  },\n'
      '  "model": "fixture-model-edited"\n'
      '}\n';

  group('portable LocalFileOperations fixture flow', () {
    late _FixtureHarness harness;

    setUp(() async {
      harness = await _FixtureHarness.create(
        const LocalFileOperations(),
      );
    });

    tearDown(() => harness.dispose());

    test(
      'staging fixture save backs up under application-support and restore '
      'recreates a deleted parent directory without backing up a missing file',
      () async {
        final backupPath = await harness.saveEditedFixture(editedContent);

        await Directory(
          p.join(harness.root.path, '.claude'),
        ).delete(recursive: true);
        expect(File(harness.configPath).existsSync(), isFalse);

        await harness.restoreLikeMainShell(backupPath);

        expect(
          await File(harness.configPath).readAsString(),
          harness.originalFixtureContent,
        );
        expect(
          await harness.backupService.listBackups(harness.configPath),
          hasLength(1),
        );
      },
    );

    test(
      'MainShell-style restore over an existing file backs up the live '
      'content before writing the selected snapshot',
      () async {
        final backupPath = await harness.saveEditedFixture(editedContent);

        await harness.restoreLikeMainShell(backupPath);

        expect(
          await File(harness.configPath).readAsString(),
          harness.originalFixtureContent,
        );
        final backups = await harness.backupService.listBackups(
          harness.configPath,
        );
        expect(backups, hasLength(2));
        expect(await backups.first.readAsString(), editedContent);
        expect(
          await File(backupPath).readAsString(),
          harness.originalFixtureContent,
        );
      },
    );
  });

  group('root-bounded FileOperations service boundary', () {
    late _FixtureHarness harness;

    setUp(() async {
      final root = await Directory.systemTemp.createTemp(
        'fixture_test_root_bounded_',
      );
      harness = await _FixtureHarness.create(
        _RootBoundedLocalFileOperations(rootPath: root.path),
        root: root,
      );
    });

    tearDown(() => harness.dispose());

    test(
      'in-root save, backup, and restore succeed through the bounded ops',
      () async {
        final backupPath = await harness.saveEditedFixture(editedContent);
        await harness.restoreLikeMainShell(backupPath);
        expect(
          await File(harness.configPath).readAsString(),
          harness.originalFixtureContent,
        );
      },
    );

    test(
      'save, backup, and restore reject paths outside the marked root',
      () async {
        final outsideDir = await Directory.systemTemp.createTemp(
          'fixture_outside_root_',
        );
        addTearDown(() async {
          if (outsideDir.existsSync()) {
            await outsideDir.delete(recursive: true);
          }
        });
        final outsidePath = p.join(outsideDir.path, 'escape.json');
        await File(outsidePath).writeAsString('{"escape":true}');

        final outsideConfig = ToolConfig(
          toolName: 'Outside',
          filePath: outsidePath,
          format: ConfigFormat.json,
          originalContent: '{"escape":true}',
        );

        await expectLater(
          harness.configService.saveRawConfig(
            outsideConfig,
            '{"escape":false}',
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('outside the test root'),
            ),
          ),
        );
        expect(await File(outsidePath).readAsString(), '{"escape":true}');

        await expectLater(
          harness.backupService.createBackup(outsidePath),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('outside the test root'),
            ),
          ),
        );

        final inRootBackup = await harness.saveEditedFixture(editedContent);
        final bytes = await harness.backupService.readBackupBytes(inRootBackup);
        await expectLater(
          harness.backupService.writeRestoredFile(outsidePath, bytes),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              contains('outside the test root'),
            ),
          ),
        );
        expect(await File(outsidePath).readAsString(), '{"escape":true}');
      },
    );
  });
}

class _FixtureHarness {
  _FixtureHarness._({
    required this.root,
    required this.backupDirectory,
    required this.backupService,
    required this.configService,
    required this.configPath,
    required this.originalFixtureContent,
  });

  final Directory root;
  final Directory backupDirectory;
  final BackupService backupService;
  final ConfigService configService;
  final String configPath;
  final String originalFixtureContent;

  static Future<_FixtureHarness> create(
    FileOperations fileOperations, {
    Directory? root,
  }) async {
    final resolvedRoot =
        root ??
        await Directory.systemTemp.createTemp(
          'fixture_test_root_save_restore_',
        );
    await File(
      p.join(resolvedRoot.path, testRootMarkerFileName),
    ).writeAsString(testRootMarkerContents);

    final originalFixtureContent = await File(
      p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'staging_home',
        '.claude',
        'settings.json',
      ),
    ).readAsString();
    final configPath = p.join(resolvedRoot.path, '.claude', 'settings.json');
    await File(configPath).parent.create(recursive: true);
    await File(configPath).writeAsString(originalFixtureContent);

    final backupDirectory = Directory(
      p.join(resolvedRoot.path, 'application-support', 'backups'),
    );
    final backupService = BackupService(
      backupDirectory: backupDirectory,
      fileOperations: fileOperations,
    );
    final configService = ConfigService(
      backupService: backupService,
      homeDirectoryResolver: () => resolvedRoot.path,
      fileOperations: fileOperations,
    );

    return _FixtureHarness._(
      root: resolvedRoot,
      backupDirectory: backupDirectory,
      backupService: backupService,
      configService: configService,
      configPath: configPath,
      originalFixtureContent: originalFixtureContent,
    );
  }

  Future<void> dispose() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }

  Future<String> saveEditedFixture(String editedContent) async {
    final match = ToolDescriptorRegistry.matchPath(
      configPath,
      normalizedHomePath: root.path,
    );
    final loaded = await configService.loadDiscoveredConfig(
      DiscoveredConfig.fromPath(
        filePath: configPath,
        sourceLabel: match.sourceLabel,
        format: match.format,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
      ),
    );
    expect(loaded.toolName, 'Claude Code');
    expect(loaded.originalContent, originalFixtureContent);

    await configService.saveRawConfig(loaded, editedContent);
    expect(await File(configPath).readAsString(), editedContent);

    final backupsAfterSave = await backupService.listBackups(configPath);
    expect(backupsAfterSave, hasLength(1));
    expect(
      p.isWithin(backupDirectory.path, backupsAfterSave.single.path),
      isTrue,
    );
    expect(
      await backupsAfterSave.single.readAsString(),
      originalFixtureContent,
    );
    return backupsAfterSave.single.path;
  }

  /// Same order as MainShell restore: read bytes first, then backup live
  /// target only when it still exists, then write the snapshot.
  Future<void> restoreLikeMainShell(String backupPath) async {
    final backupContent = await backupService.readBackupBytes(backupPath);
    if (await configService.fileExists(configPath)) {
      await backupService.createBackup(configPath);
    }
    await backupService.writeRestoredFile(configPath, backupContent);
  }
}

/// Portable stand-in for MacOSTestRootFileOperations outside-root rejection.
///
/// Delegates allowed I/O to [LocalFileOperations] after the same `isWithin`
/// check production test-root mode applies before the native bridge.
class _RootBoundedLocalFileOperations implements FileOperations {
  _RootBoundedLocalFileOperations({required this.rootPath});

  final String rootPath;
  final LocalFileOperations _inner = const LocalFileOperations();

  void _ensureWithinRoot(String absolutePath) {
    final normalized = p.normalize(p.absolute(absolutePath));
    if (!p.isWithin(rootPath, normalized)) {
      throw FileSystemException('Path is outside the test root', normalized);
    }
  }

  @override
  Future<void> validatePath(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    await _inner.validatePath(absolutePath);
  }

  @override
  Future<bool> fileExists(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    return _inner.fileExists(absolutePath);
  }

  @override
  Future<bool> directoryExists(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    return _inner.directoryExists(absolutePath);
  }

  @override
  Future<String> readText(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    return _inner.readText(absolutePath);
  }

  @override
  Future<List<int>> readBytes(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    return _inner.readBytes(absolutePath);
  }

  @override
  Future<void> writeText(String absolutePath, String text) async {
    _ensureWithinRoot(absolutePath);
    await _inner.writeText(absolutePath, text);
  }

  @override
  Future<void> writeBytes(String absolutePath, List<int> bytes) async {
    _ensureWithinRoot(absolutePath);
    await _inner.writeBytes(absolutePath, bytes);
  }

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) async {
    _ensureWithinRoot(sourcePath);
    _ensureWithinRoot(destinationPath);
    await _inner.copyFile(sourcePath, destinationPath);
  }

  @override
  Future<List<String>> listFiles(String absoluteDirectoryPath) async {
    _ensureWithinRoot(absoluteDirectoryPath);
    return _inner.listFiles(absoluteDirectoryPath);
  }

  @override
  Future<void> deleteFile(String absolutePath) async {
    _ensureWithinRoot(absolutePath);
    await _inner.deleteFile(absolutePath);
  }

  @override
  Future<void> writeTextAtomically(String absolutePath, String text) async {
    _ensureWithinRoot(absolutePath);
    await _inner.writeTextAtomically(absolutePath, text);
  }
}

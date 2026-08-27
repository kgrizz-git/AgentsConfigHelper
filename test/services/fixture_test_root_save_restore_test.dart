// Fixture-level save → backup → restore under the test-root service layout
// (home resolver + application-support/backups). Uses LocalFileOperations for
// CI portability; macOS no-follow coverage stays in
// macos_test_root_file_operations_test.dart.
//
// Restore steps mirror MainShell: readBackupBytes → optional createBackup when
// the live file still exists → writeRestoredFile.

import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory backupDirectory;
  late BackupService backupService;
  late ConfigService configService;
  late String configPath;
  late String originalFixtureContent;

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

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'fixture_test_root_save_restore_',
    );
    await File(
      p.join(root.path, testRootMarkerFileName),
    ).writeAsString(testRootMarkerContents);

    originalFixtureContent = await File(
      p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'staging_home',
        '.claude',
        'settings.json',
      ),
    ).readAsString();
    configPath = p.join(root.path, '.claude', 'settings.json');
    await File(configPath).parent.create(recursive: true);
    await File(configPath).writeAsString(originalFixtureContent);

    const fileOperations = LocalFileOperations();
    backupDirectory = Directory(
      p.join(root.path, 'application-support', 'backups'),
    );
    backupService = BackupService(
      backupDirectory: backupDirectory,
      fileOperations: fileOperations,
    );
    configService = ConfigService(
      backupService: backupService,
      homeDirectoryResolver: () => root.path,
      fileOperations: fileOperations,
    );
  });

  tearDown(() async {
    // Synchronous existence checks keep this filesystem assertion concise.
    // ignore: avoid_slow_async_io
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<String> saveEditedFixture() async {
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

  test(
    'staging fixture save backs up under application-support and restore '
    'recreates a deleted parent directory without backing up a missing file',
    () async {
      final backupPath = await saveEditedFixture();

      await Directory(p.join(root.path, '.claude')).delete(recursive: true);
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      expect(await File(configPath).exists(), isFalse);

      await restoreLikeMainShell(backupPath);

      expect(await File(configPath).readAsString(), originalFixtureContent);
      // Recreate skips createBackup, so the save-time snapshot remains alone.
      expect(await backupService.listBackups(configPath), hasLength(1));
    },
  );

  test(
    'MainShell-style restore over an existing file backs up the live content '
    'before writing the selected snapshot',
    () async {
      final backupPath = await saveEditedFixture();

      await restoreLikeMainShell(backupPath);

      expect(await File(configPath).readAsString(), originalFixtureContent);
      final backups = await backupService.listBackups(configPath);
      expect(backups, hasLength(2));
      expect(await backups.first.readAsString(), editedContent);
      expect(await File(backupPath).readAsString(), originalFixtureContent);
    },
  );
}

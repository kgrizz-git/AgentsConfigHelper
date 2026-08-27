// Fixture-level save → backup → restore-as-recreate under the test-root
// service layout (home resolver + application-support/backups). Uses
// LocalFileOperations for CI portability; macOS no-follow coverage stays in
// macos_test_root_file_operations_test.dart.

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
  test(
    'staging fixture save backs up under test-root application-support and '
    'restore recreates a deleted parent directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'fixture_test_root_save_restore_',
      );
      addTearDown(() async {
        // Synchronous existence checks keep this filesystem assertion concise.
        // ignore: avoid_slow_async_io
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      await File(
        p.join(root.path, testRootMarkerFileName),
      ).writeAsString(testRootMarkerContents);

      final fixtureSource = File(
        p.join(
          Directory.current.path,
          'test',
          'fixtures',
          'staging_home',
          '.claude',
          'settings.json',
        ),
      );
      final originalFixtureContent = await fixtureSource.readAsString();
      final configPath = p.join(root.path, '.claude', 'settings.json');
      await File(configPath).parent.create(recursive: true);
      await File(configPath).writeAsString(originalFixtureContent);

      const fileOperations = LocalFileOperations();
      final backupDirectory = Directory(
        p.join(root.path, 'application-support', 'backups'),
      );
      final backupService = BackupService(
        backupDirectory: backupDirectory,
        fileOperations: fileOperations,
      );
      final configService = ConfigService(
        backupService: backupService,
        homeDirectoryResolver: () => root.path,
        fileOperations: fileOperations,
      );

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

      // Capture the pre-edit snapshot, then remove the live tree so restore
      // must recreate missing parents (restore-as-recreate).
      final snapshotBytes = await backupService.readBackupBytes(
        backupsAfterSave.single.path,
      );
      await Directory(p.join(root.path, '.claude')).delete(recursive: true);
      // Synchronous existence checks keep this filesystem assertion concise.
      // ignore: avoid_slow_async_io
      expect(await File(configPath).exists(), isFalse);

      if (await configService.fileExists(configPath)) {
        await backupService.createBackup(configPath);
      }
      await backupService.writeRestoredFile(configPath, snapshotBytes);

      expect(await File(configPath).readAsString(), originalFixtureContent);
      expect(
        backupDirectory.listSync().every(
          (entity) => p.isWithin(root.path, entity.path),
        ),
        isTrue,
      );
    },
  );
}

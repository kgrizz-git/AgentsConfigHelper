/// Widget tests for [RecoveryHandler].
///
/// Real `dart:io` futures do not complete during normal `pump()` in widget
/// tests. Wrap every filesystem operation (including per-test setup) in
/// [WidgetTester.runAsync], then `pump` before asserting.
library;

import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/screens/recovery_handler.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

part 'recovery_handler_test_harness.dart';

void main() {
  group('RecoveryHandler', () {
    testWidgets('resolve-path failure shows error and Skip only', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
        homeDirectoryResolver: () => null,
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath('~/missing.json');

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
        errorValue: 'Cannot resolve home',
      );

      expect(find.text('Configuration could not be loaded'), findsOneWidget);
      expect(find.text('Cannot resolve home'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Open raw editor'), findsNothing);
      expect(find.text('View backups'), findsNothing);
      expect(find.text('Remove'), findsNothing);

      await tester.tap(find.text('Skip'));
      await _awaitRecovery(tester, state);

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
    });

    testWidgets('unresolved-path Skip does not clear a newer load', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
        homeDirectoryResolver: () => null,
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath('~/missing.json');

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
        errorValue: 'Cannot resolve home',
      );

      state.bumpLoadGeneration();
      const newerId = 'newer-load';
      state.activeConfigId = newerId;
      state.activeConfig = ToolConfig(
        toolName: 'Newer',
        filePath: '/tmp/newer.json',
        format: ConfigFormat.json,
      );
      state.error = null;
      await _pumpFrames(tester);

      await tester.tap(find.text('Skip'));
      await _awaitRecovery(tester, state);

      expect(state.activeConfigId, newerId);
      expect(state.activeConfig?.toolName, 'Newer');
      expect(state.error, isNull);
    });

    testWidgets('skip on existing file shows raw editor action only', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      await tester.runAsync(() => configFile.writeAsString('{"ok": true}'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('Open raw editor'), findsOneWidget);
      expect(find.text('View backups'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await _awaitRecovery(tester, state);

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
    });

    testWidgets('open raw editor loads file content into recovery mode', (
      tester,
    ) async {
      const fileContent = '{"raw": "editor"}';
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      await tester.runAsync(() => configFile.writeAsString(fileContent));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      await _tapRecoveryAction(tester, state, 'Open raw editor');

      expect(state.rawRecoveryMode, isTrue);
      expect(state.activeConfig?.originalContent, fileContent);
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.error, isNull);
    });

    testWidgets('view backups opens history modal with raw recovery config', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      late BackupService backupService;
      await tester.runAsync(() async {
        await configFile.writeAsString('{"backup": true}');
        backupService = BackupService(backupDirectory: backupDir);
        await backupService.createBackup(configFile.path);
      });

      final configService = ConfigService(backupService: backupService);
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('View backups'), findsOneWidget);

      await _tapRecoveryAction(tester, state, 'View backups');

      expect(state.historyModalShown, isTrue);
      expect(state.rawRecoveryMode, isTrue);
      expect(state.activeConfig?.toolName, 'Test Tool');
      expect(state.activeConfig?.filePath, config.filePath);
      expect(state.activeConfig?.originalContent, '{"backup": true}');
      expect(state.error, isNull);
    });

    testWidgets('remove manual path clears error and calls preferences store', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'manual.json'));
      await tester.runAsync(() => configFile.writeAsString('{}'));

      final config = _discoveredConfigForPath(
        configFile.path,
        scope: ConfigLocationScope.manual,
      );
      final prefsStore = _FakePreferencesStore(
        manualFilePaths: [config.filePath],
      );
      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: prefsStore,
        discoveredConfig: config,
      );

      expect(find.text('Remove'), findsOneWidget);

      await _tapRecoveryAction(tester, state, 'Remove');

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
      expect(prefsStore.removedManualPaths, [config.filePath]);
    });

    testWidgets('raw editor read failure shows snackbar and clears state', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configPath = p.join(tempDir.path, 'unreadable.json');
      final configFile = File(configPath);
      await tester.runAsync(() => configFile.writeAsString('{}'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configPath);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('Open raw editor'), findsOneWidget);

      // exists() already ran for the dialog. Replace the file with a directory
      // so readAsString() throws on every platform (chmod 000 is POSIX-only).
      await tester.runAsync(() async {
        await configFile.delete();
        await Directory(configPath).create();
      });

      await _tapRecoveryAction(tester, state, 'Open raw editor');

      expect(
        find.textContaining('Could not open the raw editor:'),
        findsOneWidget,
      );
      expect(state.rawRecoveryMode, isFalse);
      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
    });

    testWidgets('preferences load failure still shows dialog without Remove', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      await tester.runAsync(() => configFile.writeAsString('{}'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final config = _discoveredConfigForPath(
        configFile.path,
        scope: ConfigLocationScope.manual,
      );
      final prefsStore = _FakePreferencesStore(
        manualFilePaths: [config.filePath],
        loadError: Exception('prefs load failed'),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: prefsStore,
        discoveredConfig: config,
      );

      expect(find.text('Configuration could not be loaded'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await _awaitRecovery(tester, state);

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
    });

    testWidgets('stale generation ignores dialog actions', (tester) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      await tester.runAsync(() => configFile.writeAsString('{"stale": true}'));

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      state.bumpLoadGeneration();
      await _pumpFrames(tester);

      await _tapRecoveryAction(tester, state, 'Open raw editor');

      expect(state.rawRecoveryMode, isFalse);
      expect(state.historyModalShown, isFalse);
      expect(state.activeConfig?.originalContent, isNot('{"stale": true}'));
    });

    testWidgets('missing file hides raw editor and Skip clears state', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final missingPath = p.join(tempDir.path, 'missing.json');

      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(missingPath);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('Open raw editor'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await _awaitRecovery(tester, state);

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
    });

    testWidgets('view backups works when original file was deleted', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'deleted.json'));
      late BackupService backupService;
      await tester.runAsync(() async {
        await configFile.writeAsString('{"deleted": false}');
        backupService = BackupService(backupDirectory: backupDir);
        await backupService.createBackup(configFile.path);
        await configFile.delete();
      });

      final configService = ConfigService(backupService: backupService);
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('View backups'), findsOneWidget);
      expect(find.text('Open raw editor'), findsNothing);

      await _tapRecoveryAction(tester, state, 'View backups');

      expect(state.historyModalShown, isTrue);
      expect(state.rawRecoveryMode, isTrue);
      expect(state.activeConfig?.originalContent, '');
      expect(state.error, isNull);
    });

    testWidgets('listBackups failure hides View backups without crashing', (
      tester,
    ) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'config.json'));
      await tester.runAsync(() => configFile.writeAsString('{}'));

      final backupService = _ThrowingListBackupsBackupService(
        backupDirectory: backupDir,
      );
      final configService = ConfigService(backupService: backupService);
      final harnessKey = GlobalKey<_RecoveryHarnessState>();
      final config = _discoveredConfigForPath(configFile.path);

      await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: _FakePreferencesStore(),
        discoveredConfig: config,
      );

      expect(find.text('Open raw editor'), findsOneWidget);
      expect(find.text('View backups'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('removeManualPath failure is non-fatal', (tester) async {
      final tempDir = await _createTempDir(tester, 'recovery_handler_test_');
      addTearDown(() => _deleteTempDir(tester, tempDir));
      final backupDir = Directory(p.join(tempDir.path, 'backups'));
      final configFile = File(p.join(tempDir.path, 'manual.json'));
      await tester.runAsync(() => configFile.writeAsString('{}'));

      final config = _discoveredConfigForPath(
        configFile.path,
        scope: ConfigLocationScope.manual,
      );
      final prefsStore = _FakePreferencesStore(
        manualFilePaths: [config.filePath],
        removeManualPathError: Exception('remove failed'),
      );
      final configService = ConfigService(
        backupService: BackupService(backupDirectory: backupDir),
      );
      final harnessKey = GlobalKey<_RecoveryHarnessState>();

      final state = await _pumpHarness(
        tester: tester,
        harnessKey: harnessKey,
        configService: configService,
        prefsStore: prefsStore,
        discoveredConfig: config,
      );

      await _tapRecoveryAction(tester, state, 'Remove');

      expect(state.error, isNull);
      expect(state.activeConfigId, isNull);
      expect(state.activeConfig, isNull);
      expect(prefsStore.removedManualPaths, [config.filePath]);
    });
  });
}

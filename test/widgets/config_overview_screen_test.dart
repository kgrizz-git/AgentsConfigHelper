import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/report_save_service.dart';
import 'package:agents_config_helper/screens/config_overview_screen.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDiscoveryService extends DiscoveryService {
  _StubDiscoveryService(this._result);

  final DiscoveryResult _result;

  @override
  Future<DiscoveryResult> discoverConfigs(_) async => _result;
}

class _StubPrefsStore implements IDiscoveryPreferencesStore {
  const _StubPrefsStore();

  @override
  Future<DiscoveryPreferencesResult> load() async =>
      const DiscoveryPreferencesResult(preferences: DiscoveryPreferences());

  @override
  Future<void> addManualPath(String path) async {}
  @override
  Future<void> removeManualPath(String path) async {}
  @override
  Future<void> addProjectRoot(String path) async {}
  @override
  Future<void> removeProjectRoot(String path) async {}
  @override
  Future<void> enableTomlStructuredSave() async {}
  @override
  Future<void> disableTomlStructuredSave() async {}
}

/// Taps a save button and settles real dart:io writes.
///
/// Plain pumpAndSettle runs on fake async, which starves real file I/O
/// (the report file is created but stays at 0 bytes and no snackbar ever
/// appears). Both the tap and the settle loop must run inside runAsync so
/// the whole save chain uses real async.
Future<void> _tapSaveAndSettle(WidgetTester tester, Finder button) async {
  await tester.runAsync(() async {
    await tester.tap(button);
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(SnackBar).evaluate().isNotEmpty) return;
    }
  });
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiscoveryResult? discovery,
  SaveFileDialog? saveFileDialog,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('ach_overview_test');
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });
  final configService = ConfigService(
    backupService: BackupService(backupDirectory: Directory.systemTemp),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configServiceProvider.overrideWithValue(configService),
        discoveryServiceProvider.overrideWithValue(
          _StubDiscoveryService(
            discovery ??
                DiscoveryResult(
                  items: [
                    DiscoveredConfig(
                      id: 'structuredConfig:${tempDir.path}/.claude/settings.json',
                      filePath: '${tempDir.path}/.claude/settings.json',
                      descriptor: const ToolDescriptor(
                        id: ToolId.claudeCode,
                        displayName: 'Claude Code',
                        targets: [],
                      ),
                      scope: ConfigLocationScope.user,
                      kind: ConfigSourceKind.structuredConfig,
                      format: ConfigFormat.json,
                      sourceLabel: '.claude/settings.json',
                      fromCatalog: true,
                    ),
                  ],
                ),
          ),
        ),
        discoveryPreferencesStoreProvider.overrideWithValue(
          const _StubPrefsStore(),
        ),
        homeDirectoryResolverProvider.overrideWithValue(
          () => tempDir.path,
        ),
        if (saveFileDialog != null)
          saveFileDialogProvider.overrideWithValue(saveFileDialog),
      ],
      child: const MaterialApp(home: Scaffold(body: ConfigOverviewScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('screen renders preview content with entries', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Config Overview Report'), findsOneWidget);
    expect(find.text('Claude Code'), findsWidgets);
  });

  testWidgets('screen renders empty state when no entries', (tester) async {
    await _pumpScreen(
      tester,
      discovery: const DiscoveryResult(items: []),
    );

    expect(find.text('Config Overview Report'), findsOneWidget);
  });

  testWidgets('screen shows tool section for discovered entry', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Contents'), findsOneWidget);
    expect(find.text('Claude Code'), findsWidgets);
  });

  testWidgets('screen shows error when home directory is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDirectoryResolverProvider.overrideWithValue(() => null),
        ],
        child: const MaterialApp(home: Scaffold(body: ConfigOverviewScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Error: cannot resolve home directory'),
      findsOneWidget,
    );
  });

  testWidgets('screen shows Save buttons', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Save .md'), findsOneWidget);
    expect(find.text('Save .html'), findsOneWidget);
  });

  testWidgets('screen shows file list with entries', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Files'), findsOneWidget);
    expect(find.text('.claude/settings.json'), findsWidgets);
    expect(find.text('missing'), findsWidgets);
  });

  testWidgets('screen shows Copy path button', (tester) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.copy), findsWidgets);
  });

  testWidgets('screen shows Open in editor button', (tester) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.open_in_new), findsWidgets);
  });

  testWidgets('Copy button is tappable', (tester) async {
    await _pumpScreen(tester);

    final copyIcon = find.byIcon(Icons.copy).first;
    await tester.scrollUntilVisible(copyIcon, 100);
    await tester.tap(copyIcon);
    await tester.pump();
  });

  testWidgets('Save .md triggers save flow', (tester) async {
    final savedPath = '${Directory.systemTemp.path}/test_save_md.md';
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => savedPath,
    );

    await _tapSaveAndSettle(tester, find.text('Save .md'));

    expect(File(savedPath).existsSync(), isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Save .html triggers save flow', (tester) async {
    final savedPath = '${Directory.systemTemp.path}/test_save_html.html';
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => savedPath,
    );

    await _tapSaveAndSettle(tester, find.text('Save .html'));

    expect(File(savedPath).existsSync(), isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Save dialog cancel does not write file', (tester) async {
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => null,
    );

    await tester.tap(find.text('Save .md'));
    await tester.pumpAndSettle();

    expect(find.text('Report saved as md.'), findsNothing);
  });
}

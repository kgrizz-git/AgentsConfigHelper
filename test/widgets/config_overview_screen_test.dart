import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiscoveryResult? discovery,
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
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:agents_config_helper/main.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfigService extends ConfigService {
  _FakeConfigService(BackupService backupService)
    : super(backupService: backupService);

  @override
  Future<ToolConfig> loadConfig(String path) async {
    return ToolConfig(
      toolName: path.contains('cursor') ? 'Cursor' : 'Claude',
      filePath: path,
      format: ConfigFormat.json,
      rules: const ['original rule'],
    );
  }

  @override
  Future<ToolConfig> loadDiscoveredConfig(DiscoveredConfig config) async {
    return ToolConfig(
      toolName: config.filePath.contains('cursor') ? 'Cursor' : 'Claude',
      filePath: config.filePath,
      format: ConfigFormat.json,
      rules: const ['original rule'],
    );
  }
}



class _FakeDiscoveryService extends DiscoveryService {
  @override
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) async {
    return DiscoveryResult(
      items: [
        DiscoveredConfig.fromPath(
          filePath: '~/.claude/settings.json',
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'Claude Code',
        ),
        DiscoveredConfig.fromPath(
          filePath: '~/.cursor/permissions.json',
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'Cursor',
        ),
      ],

    );
  }
}

class _FakePreferencesStore implements IDiscoveryPreferencesStore {
  @override
  Future<DiscoveryPreferencesResult> load() async {
    return const DiscoveryPreferencesResult(preferences: DiscoveryPreferences());
  }

  @override
  Future<void> addManualPath(String path) async {}
  @override
  Future<void> removeManualPath(String path) async {}
  @override
  Future<void> addProjectRoot(String path) async {}
  @override
  Future<void> removeProjectRoot(String path) async {}
}

void main() {
  testWidgets('MainShell renders sidebar and content area', (tester) async {
    final configService = ConfigService(
      backupService: BackupService(backupDirectory: Directory.systemTemp),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configServiceProvider.overrideWithValue(configService),
          discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
          discoveryPreferencesStoreProvider.overrideWithValue(_FakePreferencesStore()),
        ],
        child: const AgentsConfigHelperApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agents Config'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
  });

  testWidgets('confirms before discarding edits to load another config', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final configService = _FakeConfigService(
      BackupService(backupDirectory: Directory.systemTemp),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configServiceProvider.overrideWithValue(configService),
          discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
          discoveryPreferencesStoreProvider.overrideWithValue(_FakePreferencesStore()),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Claude Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Item').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'unsaved rule');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cursor'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('unsaved rule'), findsOneWidget);

    await tester.tap(find.text('Cursor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard & Load'));
    await tester.pumpAndSettle();
    expect(find.text('Cursor'), findsNWidgets(2));
  });
}

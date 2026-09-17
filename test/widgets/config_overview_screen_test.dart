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

/// Taps an action and waits for real dart:io feedback.
///
/// Plain pumpAndSettle runs on fake async, which starves real file I/O. Both
/// the tap and the settle loop must run inside runAsync so the whole action
/// chain uses real async.
Future<void> _tapAndWaitForSnackBar(WidgetTester tester, Finder button) async {
  await tester.runAsync(() async {
    await tester.tap(button);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(SnackBar).evaluate().isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiscoveryResult? discovery,
  SaveFileDialog? saveFileDialog,
  String? Function()? homeDirectoryResolver,
  String? copilotHome,
  ConfigPlatform hostPlatform = ConfigPlatform.macOS,
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
          homeDirectoryResolver ?? () => tempDir.path,
        ),
        copilotHomePathProvider.overrideWithValue(copilotHome),
        hostConfigPlatformProvider.overrideWithValue(hostPlatform),
        if (saveFileDialog != null)
          saveFileDialogProvider.overrideWithValue(saveFileDialog),
      ],
      child: const MaterialApp(home: Scaffold(body: ConfigOverviewScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('screen renders interactive content with entries', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Configuration files'), findsOneWidget);
    expect(find.text('Claude Code'), findsWidgets);
  });

  testWidgets('screen renders empty state when no entries', (tester) async {
    await _pumpScreen(
      tester,
      discovery: const DiscoveryResult(items: []),
    );

    expect(find.text('Configuration files'), findsOneWidget);
  });

  testWidgets('screen shows error when home directory is null', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      homeDirectoryResolver: () => null,
      discovery: const DiscoveryResult(items: []),
    );

    expect(
      find.text('Error: cannot resolve home directory'),
      findsOneWidget,
    );
  });

  testWidgets('screen renders Copilot results when home directory is null', (
    tester,
  ) async {
    final copilotDir = Directory.systemTemp.createTempSync('ach_copilot_test');
    addTearDown(() {
      if (copilotDir.existsSync()) copilotDir.deleteSync(recursive: true);
    });
    final settingsPath = '${copilotDir.path}/settings.json';
    await _pumpScreen(
      tester,
      homeDirectoryResolver: () => null,
      copilotHome: copilotDir.path,
      discovery: DiscoveryResult(
        items: [
          DiscoveredConfig(
            id: 'structuredConfig:$settingsPath',
            filePath: settingsPath,
            descriptor: const ToolDescriptor(
              id: ToolId.copilot,
              displayName: 'GitHub Copilot',
              targets: [],
            ),
            scope: ConfigLocationScope.user,
            kind: ConfigSourceKind.structuredConfig,
            format: ConfigFormat.jsonc,
            sourceLabel: 'GitHub Copilot',
            fromCatalog: true,
          ),
        ],
      ),
    );

    expect(find.text('Error: cannot resolve home directory'), findsNothing);
    expect(find.text('GitHub Copilot'), findsWidgets);
  });

  testWidgets('screen shows clearly labeled export buttons', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Export Markdown'), findsOneWidget);
    expect(find.text('Export HTML'), findsOneWidget);
    expect(find.byTooltip('Save report as a Markdown file'), findsOneWidget);
    expect(find.byTooltip('Save report as an HTML file'), findsOneWidget);
  });

  testWidgets('screen groups the single interactive file overview', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(
      find.text(
        'Use the available actions to open, reveal, or copy each '
        'configuration path.',
      ),
      findsOneWidget,
    );
    expect(find.text('.claude/settings.json'), findsWidgets);
    expect(find.text('missing'), findsWidgets);
    expect(find.text('Config Overview Report'), findsNothing);
    expect(find.text('Contents', findRichText: true), findsNothing);
  });

  testWidgets('screen shows clarified path actions', (tester) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.copy), findsWidgets);
    expect(find.byTooltip('Copy absolute path'), findsWidgets);
    expect(find.byTooltip('Open in editor'), findsOneWidget);
    expect(find.byTooltip('Reveal in file manager'), findsOneWidget);
    expect(
      find.byTooltip('Expected configuration file not found on disk.'),
      findsWidgets,
    );
  });

  testWidgets('screen explains secret-bearing configurations', (tester) async {
    await _pumpScreen(
      tester,
      discovery: const DiscoveryResult(
        items: [
          DiscoveredConfig(
            id: 'manual:/tmp/secrets.json',
            filePath: '/tmp/secrets.json',
            descriptor: null,
            scope: ConfigLocationScope.manual,
            kind: ConfigSourceKind.structuredConfig,
            format: ConfigFormat.json,
            sourceLabel: 'Secrets',
            fromManual: true,
          ),
        ],
      ),
    );

    expect(
      find.byTooltip('This configuration may contain secrets.'),
      findsWidgets,
    );
  });

  testWidgets('screen shows Open in editor button', (tester) async {
    await _pumpScreen(tester);

    expect(find.byIcon(Icons.open_in_new), findsWidgets);
  });

  testWidgets('screen hides reveal action for missing entries', (tester) async {
    await _pumpScreen(tester, discovery: const DiscoveryResult(items: []));

    expect(find.byTooltip('Reveal in file manager'), findsNothing);
  });

  testWidgets('Reveal action reports when the resolved file no longer exists', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await _tapAndWaitForSnackBar(
      tester,
      find.byTooltip('Reveal in file manager'),
    );

    expect(
      find.text('Could not reveal the configuration file.'),
      findsOneWidget,
    );
  });

  testWidgets('Copy button is tappable', (tester) async {
    await _pumpScreen(tester);

    final copyIcon = find.byIcon(Icons.copy).first;
    await tester.scrollUntilVisible(copyIcon, 100);
    await tester.tap(copyIcon);
    await tester.pump();
  });

  testWidgets('Markdown export triggers save flow', (tester) async {
    final saveDir = Directory.systemTemp.createTempSync('ach_overview_save_md');
    addTearDown(() {
      if (saveDir.existsSync()) saveDir.deleteSync(recursive: true);
    });
    final savedPath = '${saveDir.path}/report.md';
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => savedPath,
    );

    await _tapAndWaitForSnackBar(tester, find.text('Export Markdown'));

    expect(File(savedPath).existsSync(), isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('HTML export triggers save flow', (tester) async {
    final saveDir = Directory.systemTemp.createTempSync(
      'ach_overview_save_html',
    );
    addTearDown(() {
      if (saveDir.existsSync()) saveDir.deleteSync(recursive: true);
    });
    final savedPath = '${saveDir.path}/report.html';
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => savedPath,
    );

    await _tapAndWaitForSnackBar(tester, find.text('Export HTML'));

    expect(File(savedPath).existsSync(), isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Save dialog cancel does not write file', (tester) async {
    await _pumpScreen(
      tester,
      saveFileDialog: (_, _) async => null,
    );

    await tester.tap(find.text('Export Markdown'));
    await tester.pumpAndSettle();

    expect(find.text('Report saved as md.'), findsNothing);
  });

  testWidgets('default view hides other-OS and not-configured targets', (
    tester,
  ) async {
    await _pumpScreen(tester);

    // With the injected macOS host, the Linux Cursor settings target applies
    // to another OS and is hidden by default.
    expect(find.text('.config/Cursor/User/settings.json'), findsNothing);
    // Codex has no discovered configuration in the stub discovery.
    expect(find.text('.codex/config.toml'), findsNothing);
    expect(find.textContaining('hidden'), findsOneWidget);
    expect(find.text('other OS'), findsNothing);
    expect(find.text('not configured'), findsNothing);
  });

  testWidgets('injected host platform drives relevance classification', (
    tester,
  ) async {
    await _pumpScreen(tester, hostPlatform: ConfigPlatform.linux);

    // The macOS Cursor settings target is other-platform on a Linux host.
    const macCursorPath =
        'Library/Application Support/Cursor/User/settings.json';
    expect(find.text(macCursorPath), findsNothing);

    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();

    expect(find.text(macCursorPath), findsWidgets);
  });

  testWidgets('audit control reveals hidden targets with labels', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();

    expect(
      find.text('.config/Cursor/User/settings.json'),
      findsWidgets,
    );
    expect(find.text('other OS'), findsWidgets);
    expect(find.text('not configured'), findsWidgets);
    expect(find.text('Showing all catalog targets'), findsOneWidget);
  });

  testWidgets('default export states the relevant view and hidden count', (
    tester,
  ) async {
    final saveDir = Directory.systemTemp.createTempSync('ach_overview_prov');
    addTearDown(() {
      if (saveDir.existsSync()) saveDir.deleteSync(recursive: true);
    });
    final savedPath = '${saveDir.path}/relevant.md';
    await _pumpScreen(tester, saveFileDialog: (_, _) async => savedPath);

    await _tapAndWaitForSnackBar(tester, find.text('Export Markdown'));

    final content = File(savedPath).readAsStringSync();
    expect(content, contains('Relevant view'));
    expect(content, contains('catalog target(s)'));
  });

  testWidgets('audit export states the audit view', (tester) async {
    final saveDir = Directory.systemTemp.createTempSync('ach_overview_audit');
    addTearDown(() {
      if (saveDir.existsSync()) saveDir.deleteSync(recursive: true);
    });
    final savedPath = '${saveDir.path}/audit.md';
    await _pumpScreen(tester, saveFileDialog: (_, _) async => savedPath);

    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    await _tapAndWaitForSnackBar(tester, find.text('Export Markdown'));

    final content = File(savedPath).readAsStringSync();
    expect(content, contains('Audit view'));
    expect(content, contains('.config/Cursor/User/settings.json'));
    expect(content, contains('other OS'));
  });
}

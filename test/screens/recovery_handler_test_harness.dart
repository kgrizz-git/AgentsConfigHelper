part of 'recovery_handler_test.dart';

class _FakePreferencesStore implements IDiscoveryPreferencesStore {
  _FakePreferencesStore({
    this.manualFilePaths = const [],
    this.loadError,
    this.removeManualPathError,
  });

  final List<String> manualFilePaths;
  final Exception? loadError;
  final Exception? removeManualPathError;
  final removedManualPaths = <String>[];

  @override
  Future<DiscoveryPreferencesResult> load() async {
    if (loadError != null) {
      throw loadError!;
    }
    return DiscoveryPreferencesResult(
      preferences: DiscoveryPreferences(manualFilePaths: manualFilePaths),
    );
  }

  @override
  Future<void> addManualPath(String path) async {}

  @override
  Future<void> removeManualPath(String path) async {
    removedManualPaths.add(path);
    if (removeManualPathError != null) {
      throw removeManualPathError!;
    }
  }

  @override
  Future<void> addProjectRoot(String path) async {}

  @override
  Future<void> removeProjectRoot(String path) async {}
}

class _EmptyDiscoveryService extends DiscoveryService {
  @override
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) async {
    return const DiscoveryResult(items: []);
  }
}

class _ThrowingListBackupsBackupService extends BackupService {
  _ThrowingListBackupsBackupService({required super.backupDirectory});

  @override
  Future<List<File>> listBackups(String originalPath) async {
    throw Exception('listBackups failed');
  }
}

class _RecoveryHarness extends ConsumerStatefulWidget {
  const _RecoveryHarness({
    required this.discoveredConfig,
    required this.errorValue,
    super.key,
  });

  final DiscoveredConfig discoveredConfig;
  final Object errorValue;

  @override
  ConsumerState<_RecoveryHarness> createState() => _RecoveryHarnessState();
}

class _RecoveryHarnessState extends ConsumerState<_RecoveryHarness>
    with RecoveryHandler<_RecoveryHarness> {
  int _loadGeneration = 0;

  @override
  int get loadGeneration => _loadGeneration;

  @override
  ToolConfig? activeConfig;

  @override
  String? activeConfigId;

  @override
  String? error;

  @override
  bool hasUnsavedChanges = false;

  @override
  bool rawRecoveryMode = false;

  bool historyModalShown = false;

  @override
  void showHistoryModal() {
    historyModalShown = true;
  }

  void bumpLoadGeneration() {
    setState(() => _loadGeneration++);
  }

  Future<void> startRecovery() async {
    error = 'pending error';
    activeConfigId = widget.discoveredConfig.id;
    activeConfig = ToolConfig(
      toolName: widget.discoveredConfig.sourceLabel,
      filePath: widget.discoveredConfig.filePath,
      format: widget.discoveredConfig.format,
    );
    await showRecoveryDialog(
      widget.discoveredConfig,
      widget.errorValue,
      _loadGeneration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startRecovery,
            child: const Text('Recover'),
          ),
          ElevatedButton(
            onPressed: bumpLoadGeneration,
            child: const Text('Bump generation'),
          ),
        ],
      ),
    );
  }
}

Future<void> _flushAsyncIo(WidgetTester tester, {int milliseconds = 50}) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
  });
  await tester.pump();
}

Future<void> _tapRecoveryAction(WidgetTester tester, String label) async {
  final action = find.widgetWithText(TextButton, label);
  expect(action, findsOneWidget);
  await tester.tap(action);
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await _flushAsyncIo(tester);
  }
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 3}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitForRecoveryDialog(
  WidgetTester tester, {
  int maxRetries = 20,
}) async {
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    if (find.text('Skip').evaluate().isNotEmpty) {
      await _pumpFrames(tester);
      return;
    }
    await _flushAsyncIo(tester);
  }
  fail('Recovery dialog did not appear within $maxRetries retries');
}

Future<_RecoveryHarnessState> _pumpHarness({
  required WidgetTester tester,
  required GlobalKey<_RecoveryHarnessState> harnessKey,
  required ConfigService configService,
  required _FakePreferencesStore prefsStore,
  required DiscoveredConfig discoveredConfig,
  Object errorValue = 'Parse error',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configServiceProvider.overrideWithValue(configService),
        discoveryServiceProvider.overrideWithValue(_EmptyDiscoveryService()),
        discoveryPreferencesStoreProvider.overrideWithValue(prefsStore),
      ],
      child: MaterialApp(
        home: _RecoveryHarness(
          key: harnessKey,
          discoveredConfig: discoveredConfig,
          errorValue: errorValue,
        ),
      ),
    ),
  );
  await _pumpFrames(tester);

  await tester.tap(find.text('Recover'));
  await tester.pump();
  await _waitForRecoveryDialog(tester);

  final state = harnessKey.currentState;
  if (state == null) {
    fail('Recovery harness state was not mounted');
  }
  return state;
}

DiscoveredConfig _discoveredConfigForPath(
  String filePath, {
  ConfigLocationScope scope = ConfigLocationScope.user,
}) {
  return DiscoveredConfig.fromPath(
    filePath: filePath,
    scope: scope,
    kind: ConfigSourceKind.structuredConfig,
    format: ConfigFormat.json,
    sourceLabel: 'Test Tool',
  );
}

Future<Directory> _createTempDir(WidgetTester tester, String prefix) async {
  late Directory dir;
  await tester.runAsync(() async {
    dir = await Directory.systemTemp.createTemp(prefix);
  });
  return dir;
}

Future<void> _deleteTempDir(WidgetTester tester, Directory dir) async {
  await tester.runAsync(() async {
    // Temp tree cleanup uses real dart:io inside runAsync (widget-test zone).
    // ignore: avoid_slow_async_io
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
}

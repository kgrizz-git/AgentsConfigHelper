import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/desktop_window_adapter.dart';
import 'package:agents_config_helper/services/desktop_window_bounds_store.dart';
import 'package:agents_config_helper/services/desktop_window_startup.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/services/macos_test_root_file_operations.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _getBackupDir(TestRootConfiguration? testRoot) async {
  if (testRoot != null) {
    return Directory(
      p.join(testRoot.rootPath, 'application-support', 'backups'),
    );
  }
  final appSupportDirectory = await getApplicationSupportDirectory();
  return Directory(p.join(appSupportDirectory.path, 'backups'));
}

/// Dependencies assembled during startup before any platform window work.
///
/// Keeping this composition separate lets tests prove that optional test-root
/// plumbing does not alter the ordinary application's service selection.
class StartupServiceGraph {
  const new({
    required this.testRoot,
    required this.fileOperations,
    required this.windowBoundsStore,
    required this.configService,
    required this.preferencesStore,
    required this.discoveryService,
  });

  final TestRootConfiguration? testRoot;
  final FileOperations fileOperations;
  final DesktopWindowBoundsStore windowBoundsStore;
  final ConfigService configService;
  final DiscoveryPreferencesStore? preferencesStore;
  final DiscoveryService? discoveryService;
}

/// Builds the app's services for either ordinary or marked test-root startup.
Future<StartupServiceGraph> buildStartupServiceGraph(
  List<String> arguments, {
  Future<Directory> Function(TestRootConfiguration? testRoot)?
  backupDirectoryResolver,
  Future<void> Function(DesktopWindowBoundsStore windowBoundsStore)?
  onWindowBoundsStoreReady,
}) async {
  final testRoot = await TestRootConfiguration.fromArguments(arguments);
  final FileOperations fileOperations;
  if (testRoot != null) {
    final testRootOperations = MacOSTestRootFileOperations(
      rootPath: testRoot.rootPath,
    );
    await testRootOperations.pinRoot();
    fileOperations = testRootOperations;
  } else {
    fileOperations = const LocalFileOperations();
  }

  final windowBoundsStore = DesktopWindowBoundsStore(
    getDirectory: testRoot == null
        ? null
        : () async => Directory(
            p.join(testRoot.rootPath, 'application-support'),
          ),
    fileOperations: fileOperations,
  );
  if (onWindowBoundsStoreReady != null) {
    await onWindowBoundsStoreReady(windowBoundsStore);
  }
  final backupDirectory = await (backupDirectoryResolver ?? _getBackupDir)(
    testRoot,
  );
  final preferencesStore = testRoot != null
      ? DiscoveryPreferencesStore(
          getDirectory: () async => Directory(
            p.join(testRoot.rootPath, 'application-support'),
          ),
          fileOperations: fileOperations,
          allowedRootPath: testRoot.rootPath,
        )
      : null;

  return StartupServiceGraph(
    testRoot: testRoot,
    fileOperations: fileOperations,
    windowBoundsStore: windowBoundsStore,
    configService: ConfigService(
      backupService: BackupService(
        backupDirectory: backupDirectory,
        fileOperations: fileOperations,
      ),
      homeDirectoryResolver: testRoot != null ? () => testRoot.rootPath : null,
      fileOperations: fileOperations,
    ),
    preferencesStore: preferencesStore,
    discoveryService: testRoot == null
        ? null
        : DiscoveryService(
            fileOperations: fileOperations,
            enableGlobTargets: false,
          ),
  );
}

Future<void> _configureDesktopWindow(
  DesktopWindowBoundsStore boundsStore,
) async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    return;
  }
  try {
    await DesktopWindowStartup(
      displays: const NativeDesktopDisplaySource(),
      windows: const NativeDesktopWindowSource(),
      loadBounds: boundsStore.load,
      saveBounds: boundsStore.save,
    ).configure();
  } on Object catch (error, stackTrace) {
    debugPrint('Desktop window setup failed: $error\n$stackTrace');
  }
}

/// Initializes app services and launches the Flutter application.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final services = await buildStartupServiceGraph(
      arguments,
      onWindowBoundsStoreReady: (windowBoundsStore) async {
        try {
          await _configureDesktopWindow(windowBoundsStore);
        } on Object catch (error, stackTrace) {
          debugPrint(
            'Desktop window initialization failed: $error\n$stackTrace',
          );
        }
      },
    );
    runApp(
      ProviderScope(
        overrides: [
          configServiceProvider.overrideWithValue(services.configService),
          if (services.preferencesStore != null)
            discoveryPreferencesStoreProvider.overrideWithValue(
              services.preferencesStore!,
            ),
          if (services.testRoot != null)
            homeDirectoryResolverProvider.overrideWithValue(
              () => services.testRoot!.rootPath,
            ),
          if (services.discoveryService != null)
            discoveryServiceProvider.overrideWithValue(
              services.discoveryService!,
            ),
          if (services.testRoot != null)
            testRootPathProvider.overrideWithValue(services.testRoot!.rootPath),
        ],
        child: const AgentsConfigHelperApp(),
      ),
    );
  } on Object catch (error) {
    runApp(StartupErrorApp(error: error));
  }
}

/// The root application widget.
class AgentsConfigHelperApp extends ConsumerWidget {
  /// Creates the application.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Agents Config Helper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

/// Displays startup failures instead of leaving a blank native window.
class StartupErrorApp extends StatelessWidget {
  const new({required this.error, super.key});

  /// The error that prevented normal app initialization.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agents Config Helper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SelectableText(
              'Agents Config Helper could not start.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

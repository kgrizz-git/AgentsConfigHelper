import 'dart:io';

import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/desktop_window_configuration.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/services/macos_test_root_file_operations.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

Future<Directory> _getBackupDir(TestRootConfiguration? testRoot) async {
  if (testRoot != null) {
    return Directory(
      p.join(testRoot.rootPath, 'application-support', 'backups'),
    );
  }
  final appSupportDirectory = await getApplicationSupportDirectory();
  return Directory(p.join(appSupportDirectory.path, 'backups'));
}

Future<void> _configureDesktopWindow() async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    return;
  }

  await windowManager.ensureInitialized();
  final display = await screenRetriever.getPrimaryDisplay();
  final configuration = DesktopWindowConfiguration.forVisibleSize(
    display.visibleSize ?? display.size,
  );
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: configuration.size,
      minimumSize: configuration.minimumSize,
      center: true,
      title: 'Agents Config Helper',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// Initializes app services and launches the Flutter application.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _configureDesktopWindow();
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
    final configService = ConfigService(
      backupService: BackupService(
        backupDirectory: await _getBackupDir(testRoot),
        fileOperations: fileOperations,
      ),
      homeDirectoryResolver: testRoot != null ? () => testRoot.rootPath : null,
      fileOperations: fileOperations,
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
    runApp(
      ProviderScope(
        overrides: [
          configServiceProvider.overrideWithValue(configService),
          if (preferencesStore != null)
            discoveryPreferencesStoreProvider.overrideWithValue(
              preferencesStore,
            ),
          if (testRoot != null)
            homeDirectoryResolverProvider.overrideWithValue(
              () => testRoot.rootPath,
            ),
          if (testRoot != null)
            discoveryServiceProvider.overrideWithValue(
              DiscoveryService(
                fileOperations: fileOperations,
                enableGlobTargets: false,
              ),
            ),
          if (testRoot != null)
            testRootPathProvider.overrideWithValue(testRoot.rootPath),
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
  const AgentsConfigHelperApp({super.key});

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
  const StartupErrorApp({required this.error, super.key});

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

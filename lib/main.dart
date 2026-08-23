import 'dart:io';

import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
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

Future<Directory> _getBackupDir(TestRootConfiguration? testRoot) async {
  if (testRoot != null) {
    return Directory(
      p.join(testRoot.rootPath, 'application-support', 'backups'),
    );
  }
  final appSupportDirectory = await getApplicationSupportDirectory();
  return Directory(p.join(appSupportDirectory.path, 'backups'));
}

/// Initializes app services and launches the Flutter application.
Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final testRoot = await TestRootConfiguration.fromArguments(arguments);
    final fileOperations = testRoot != null
        ? MacOSTestRootFileOperations(rootPath: testRoot.rootPath)
        : const LocalFileOperations();
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
  /// Creates an app shell for a startup error.
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

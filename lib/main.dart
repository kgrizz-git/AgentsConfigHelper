import 'dart:io';

import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _getBackupDir() async {
  final appSupportDirectory = await getApplicationSupportDirectory();
  return Directory(p.join(appSupportDirectory.path, 'backups'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configService = ConfigService(
    backupService: BackupService(backupDirectory: await _getBackupDir()),
  );
  runApp(
    ProviderScope(
      overrides: [
        configServiceProvider.overrideWithValue(configService),
      ],
      child: const AgentsConfigHelperApp(),
    ),
  );
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

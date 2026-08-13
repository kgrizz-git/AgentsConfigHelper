import 'dart:io';

import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
  runApp(AgentsConfigHelperApp(configService: configService));
}

/// The root application widget.
class AgentsConfigHelperApp extends StatelessWidget {
  /// Creates the application with the shared configuration service.
  const AgentsConfigHelperApp({required this.configService, super.key});

  /// Reads and writes user configuration files for the UI.
  final ConfigService configService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agents Config Helper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainShell(configService: configService),
    );
  }
}

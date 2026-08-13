import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

Directory _getBackupDir() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.current.path;
  return Directory(p.join(home, '.agents_config_helper', 'backups'));
}

void main() {
  final configService = ConfigService(
    backupService: BackupService(backupDirectory: _getBackupDir()),
  );
  runApp(AgentsConfigHelperApp(configService: configService));
}

class AgentsConfigHelperApp extends StatelessWidget {
  final ConfigService configService;
  const AgentsConfigHelperApp({super.key, required this.configService});

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

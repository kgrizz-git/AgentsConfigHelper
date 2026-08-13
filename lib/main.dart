import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:agents_config_helper/screens/main_shell.dart';

void main() {
  runApp(const AgentsConfigHelperApp());
}

class AgentsConfigHelperApp extends StatelessWidget {
  const AgentsConfigHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agents Config Helper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark, but supports matching system if changed
      home: const MainShell(),
    );
  }
}

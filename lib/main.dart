import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_theme.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/theme/app_colors.dart';

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
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 250,
            child: Material(
              color: AppColors.sidebarDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Agents Config',
                      style: AppTextStyles.uiHeader,
                    ),
                  ),
                  ListTile(
                    title: Text('Claude Code', style: AppTextStyles.uiBase),
                    selected: true,
                    leading: const Icon(Icons.code),
                  ),
                  ListTile(
                    title: Text('Cursor', style: AppTextStyles.uiBase),
                    leading: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
          ),
          // Vertical Divider
          const VerticalDivider(width: 1),
          // Main Content Area
          Expanded(
            child: Container(
              color: AppColors.backgroundDark,
              child: Center(
                child: Text(
                  'Configuration Area (WIP)',
                  style: AppTextStyles.uiSubheader,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

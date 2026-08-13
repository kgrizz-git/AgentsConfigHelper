import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.configService, super.key});
  final ConfigService configService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ToolConfig? _activeConfig;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // For now, we simulate loading a real config.
    // In Phase 4, we will wire up DiscoveryService.
    // Using a safe tmp path to prevent demo saves from polluting the real home directory.
    _loadConfig('/tmp/agents_config_demo/config.json');
  }

  Future<void> _loadConfig(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Create a dummy config if file doesn't exist, just for UI demonstration
      // since the path is fake right now.
      _activeConfig = ToolConfig(
        toolName: 'Claude Code',
        filePath: path,
        format: ConfigFormat.json,
        rules: const ['Always use type hints', 'Follow clean architecture'],
        permissions: const ['~/Projects'],
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  late final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        size: 250,
        min: 200,
        builder: (context, area) {
          return Material(
            color: AppColors.sidebarDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Agents Config',
                    style: AppTextStyles.uiHeader,
                  ),
                ),
                SidebarItem(
                  title: 'Claude Code',
                  icon: Icons.code,
                  isActive: true,
                  onTap: () {},
                ),
                SidebarItem(
                  title: 'Cursor',
                  icon: Icons.edit,
                  onTap: () {},
                ),
              ],
            ),
          );
        },
      ),
      Area(
        flex: 1,
        builder: (context, area) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return const Center(
              child: Text(
                r'Error: $_error',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          if (_activeConfig == null) {
            return const Center(
              child: Text('Select a configuration from the sidebar.'),
            );
          }

          return ConfigEditor(
            config: _activeConfig!,
            configService: widget.configService,
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.grooved1(
            color: AppColors.borderDark,
            highlightedColor: AppColors.primaryAccent,
            size: 10,
          ),
        ),
        child: MultiSplitView(
          controller: _controller,
        ),
      ),
    );
  }
}

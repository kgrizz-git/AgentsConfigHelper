import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The split-pane shell for selecting and editing configurations.
class MainShell extends StatefulWidget {
  /// Creates the shell with the service used to load configurations.
  const MainShell({required this.configService, super.key});

  /// Reads configurations selected in the sidebar.
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
  }

  Future<void> _loadConfig(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeConfig = null;
    });
    try {
      _activeConfig = await widget.configService.loadConfig(path);
    } on Object catch (error) {
      _error = error.toString();
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
                  isActive: _activeConfig?.toolName == 'Claude',
                  onTap: () async {
                    await _loadConfig('~/.claude/settings.json');
                  },
                ),
                SidebarItem(
                  title: 'Cursor',
                  icon: Icons.edit,
                  isActive: _activeConfig?.toolName == 'Cursor',
                  onTap: () async {
                    await _loadConfig('~/.cursor/permissions.json');
                  },
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
            return Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
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
            onSave: widget.configService.saveConfig,
            resolvePath: widget.configService.resolvePath,
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

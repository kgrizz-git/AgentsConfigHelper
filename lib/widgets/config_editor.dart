import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';

class ConfigEditor extends StatefulWidget {
  const ConfigEditor({super.key, required this.config});

  final ToolConfig config;

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  late List<String> _rules;
  late List<String> _permissions;

  @override
  void initState() {
    super.initState();
    _initLocalState();
  }

  @override
  void didUpdateWidget(covariant ConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _initLocalState();
    }
  }

  void _initLocalState() {
    _rules = List.from(widget.config.rules);
    _permissions = List.from(widget.config.permissions);
  }

  bool get _hasUnsavedChanges {
    return !listEquals(_rules, widget.config.rules) ||
           !listEquals(_permissions, widget.config.permissions);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: AppTextStyles.uiSubheader.copyWith(
          color: AppColors.primaryAccent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.config.toolName,
                        style: AppTextStyles.uiHeader,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {}, // TODO: Open History/Backups Modal
                      icon: const Icon(Icons.history),
                      label: const Text('History & Backups'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimaryDark,
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.folder_open, color: AppColors.textSecondaryDark, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${p.dirname(widget.config.filePath)}/',
                              style: AppTextStyles.uiSecondary,
                            ),
                            TextSpan(
                              text: p.basename(widget.config.filePath),
                              style: AppTextStyles.uiSecondary.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      color: AppColors.primaryAccent,
                      tooltip: 'Open Directory',
                      onPressed: () async {
                        final dir = p.dirname(widget.config.filePath);
                        final uri = Uri.directory(dir);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          // Fallback for mocked tilde paths or unsupported systems
                          if (!context.mounted) return;
                          debugPrint('Could not launch $uri');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),

                // Form Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 80.0), // padding for floating bar
                    children: [
                      _buildSectionHeader('Rules'),
                      const Text(
                        'Define custom rules for this agent.',
                        style: AppTextStyles.uiSecondary,
                      ),
                      const SizedBox(height: 12),
                      StringListEditor(
                        values: _rules,
                        hintText: 'e.g., Always use type hints...',
                        onChanged: (newValues) {
                          setState(() {
                            _rules = newValues;
                          });
                        },
                      ),

                      _buildSectionHeader('Permissions'),
                      const Text(
                        'Allowed directories or commands for this agent.',
                        style: AppTextStyles.uiSecondary,
                      ),
                      const SizedBox(height: 12),
                      StringListEditor(
                        values: _permissions,
                        hintText: 'e.g., ~/Projects',
                        onChanged: (newValues) {
                          setState(() {
                            _permissions = newValues;
                          });
                        },
                      ),

                      _buildSectionHeader('Advanced'),
                      const Text(
                        'Raw configuration overrides.',
                        style: AppTextStyles.uiSecondary,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.sidebarDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Text(
                          'Raw JSON/YAML Editor Coming Soon...',
                          style: AppTextStyles.codeBase,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Save Flow Floating Bar
          if (_hasUnsavedChanges)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                decoration: const BoxDecoration(
                  color: AppColors.sidebarDark,
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _initLocalState();
                        });
                      },
                      style: TextButton.styleFrom(foregroundColor: AppColors.textPrimaryDark),
                      child: const Text('Discard Changes'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {}, // TODO: Trigger Diff Viewer
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Review Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

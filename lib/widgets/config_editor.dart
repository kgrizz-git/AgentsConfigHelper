import 'dart:async';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Edits the supported flat configuration fields and confirms saves.
class ConfigEditor extends StatefulWidget {
  /// Creates an editor with callbacks supplied by its owner.
  const ConfigEditor({
    required this.config,
    required this.onSave,
    required this.resolvePath,
    this.onDirtyChanged,
    super.key,
  });

  /// The configuration shown by the editor.
  final ToolConfig config;

  /// Persists a confirmed edited configuration.
  final Future<void> Function(ToolConfig config) onSave;

  /// Resolves the configuration path before opening its directory.
  final String Function(String path) resolvePath;

  /// Notifies the owner when editor changes become dirty or clean.
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  late ToolConfig _currentConfig;
  late List<String> _rules;
  late List<String> _permissions;

  @override
  void initState() {
    super.initState();
    _initLocalState(widget.config);
  }

  @override
  void didUpdateWidget(covariant ConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _initLocalState(widget.config);
    }
  }

  void _initLocalState(ToolConfig config) {
    _currentConfig = config;
    _rules = List.from(_currentConfig.rules);
    _permissions = List.from(_currentConfig.permissions);
  }

  void _notifyDirtyChanged() {
    widget.onDirtyChanged?.call(_hasUnsavedChanges);
  }

  bool get _hasUnsavedChanges {
    return !listEquals(_rules, _currentConfig.rules) ||
        !listEquals(_permissions, _currentConfig.permissions);
  }

  bool get _hasUnsupportedPermissions =>
      _currentConfig.rawSettings['permissions'] != null &&
      _currentConfig.rawSettings['permissions'] is! List &&
      _currentConfig.rawSettings.containsKey('permissions');

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.uiSubheader.copyWith(
          color: AppColors.primaryAccent,
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final updatedConfig = _currentConfig.copyWith(
      rules: _rules,
      permissions: _permissions,
    );

    try {
      await widget.onSave(updatedConfig);
      if (mounted) {
        setState(() {
          _currentConfig = updatedConfig;
          _initLocalState(_currentConfig);
        });
        _notifyDirtyChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows the review modal for unsaved changes.
  void _showDiffModal() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.backgroundDark,
            title: const Text('Review Changes', style: AppTextStyles.uiHeader),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildDiffSection('Rules', _currentConfig.rules, _rules),
                  const SizedBox(height: 16),
                  _buildDiffSection(
                    'Permissions',
                    _currentConfig.permissions,
                    _permissions,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimaryDark,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_saveChanges());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm & Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds one list section in the visual diff.
  Widget _buildDiffSection(
    String title,
    List<String> original,
    List<String> updated,
  ) {
    final unmatchedOriginal = List<String>.from(original);
    final added = <String>[];
    for (final item in updated) {
      final matchingIndex = unmatchedOriginal.indexOf(item);
      if (matchingIndex == -1) {
        added.add(item);
      } else {
        unmatchedOriginal.removeAt(matchingIndex);
      }
    }
    final removed = unmatchedOriginal;
    if (added.isEmpty && removed.isEmpty) {
      if (!listEquals(original, updated)) {
        return Text('$title: Reordered', style: AppTextStyles.uiSecondary);
      }
      return Text('$title: No changes', style: AppTextStyles.uiSecondary);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.uiSubheader.copyWith(
            color: AppColors.primaryAccent,
          ),
        ),
        const SizedBox(height: 8),
        ...added.map(
          (item) =>
              Text('+ $item', style: const TextStyle(color: Colors.green)),
        ),
        ...removed.map(
          (item) => Text('- $item', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
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
                      icon: const Icon(Icons.history),
                      label: const Text('History & Backups'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('History & Backups coming soon!'),
                          ),
                        );
                      },
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
                    const Icon(
                      Icons.folder_open,
                      color: AppColors.textSecondaryDark,
                      size: 16,
                    ),
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
                        var launched = false;
                        try {
                          final dir = p.dirname(
                            widget.resolvePath(widget.config.filePath),
                          );
                          final uri = Uri.directory(dir);
                          launched = await launchUrl(uri);
                        } on Object {
                          launched = false;
                        }
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not open the config directory.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
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
                    padding: const EdgeInsets.only(
                      bottom: 80,
                    ), // padding for floating bar
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
                          _notifyDirtyChanged();
                        },
                      ),

                      _buildSectionHeader('Permissions'),
                      if (_hasUnsupportedPermissions)
                        const Text(
                          'Nested permissions are preserved but not editable '
                          'here yet.',
                          style: AppTextStyles.uiSecondary,
                        )
                      else ...[
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
                            _notifyDirtyChanged();
                          },
                        ),
                      ],

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.sidebarDark,
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _initLocalState(_currentConfig);
                        });
                        _notifyDirtyChanged();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimaryDark,
                      ),
                      child: const Text('Discard Changes'),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _showDiffModal,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryAccent,
                      ),
                      child: const Text('Review Changes'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _showDiffModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Save Changes'),
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

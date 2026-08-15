import 'dart:async';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/add_path_dialog.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/history_modal.dart';
import 'package:agents_config_helper/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The split-pane shell for selecting and editing configurations.
class MainShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  ToolConfig? _activeConfig;
  String? _activeConfigId;
  DiscoveredConfig? _activeDiscoveredConfig;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadConfig(DiscoveredConfig configItem) async {
    final generation = ++_loadGeneration;
    if (_hasUnsavedChanges) {
      final shouldDiscard = await _confirmDiscardChanges();
      if (!shouldDiscard || generation != _loadGeneration) {
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _activeConfig = null;
      _activeConfigId = configItem.id;
      _activeDiscoveredConfig = configItem;
      _hasUnsavedChanges = false;
    });
    try {
      final configService = ref.read(configServiceProvider);
      final config = await configService.loadDiscoveredConfig(configItem);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _activeConfig = config;
      });
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = error.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading config: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Loading another configuration will discard your unsaved changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard & Load'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  void _showHistoryModal() {
    if (_activeConfig == null) return;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          final configService = ref.read(configServiceProvider);
          return HistoryModal(
            config: _activeConfig!,
            onRestore: (backupPath) async {
              final targetPath = configService.resolvePath(
                _activeConfig!.filePath,
              );
              await configService.backupService.restoreBackup(
                backupPath,
                targetPath,
              );
              final configItem = _activeDiscoveredConfig;
              if (configItem != null && mounted) {
                await _loadConfig(configItem);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddManualPathDialog() async {
    final path = await showDialog<String>(
      context: context,
      builder: (context) => const AddPathDialog(
        title: 'Add Manual Config Path',
        hintText: '/absolute/path/to/config/file',
      ),
    );
    if (path == null || !mounted) return;
    try {
      await ref.read(discoveryControllerProvider.notifier).addManualPath(path);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add path: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddProjectRootDialog() async {
    final path = await showDialog<String>(
      context: context,
      builder: (context) => const AddPathDialog(
        title: 'Add Project Root',
        hintText: '/absolute/path/to/project',
      ),
    );
    if (path == null || !mounted) return;
    try {
      await ref.read(discoveryControllerProvider.notifier).addProjectRoot(path);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add project root: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showManageProjectRootsDialog() {
    final discoveryState = ref.read(discoveryControllerProvider);
    final projectRoots = discoveryState.value?.projectRoots ?? [];
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ManageProjectRootsDialog(
          projectRoots: projectRoots,
          onRemove: (path) {
            unawaited(
              ref
                  .read(discoveryControllerProvider.notifier)
                  .removeProjectRoot(path),
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForTool(String toolId) {
    switch (toolId) {
      case 'claudeCode':
        return Icons.code;
      case 'cursor':
        return Icons.edit;
      case 'opencode':
        return Icons.open_in_browser;
      case 'paseo':
        return Icons.directions_walk;
      case 'kiro':
        return Icons.keyboard;
      case 'devin':
        return Icons.developer_mode;
      case 'antigravity':
        return Icons.rocket_launch;
      case 'codex':
        return Icons.book;
      case 'agyAcp':
        return Icons.api;
      default:
        return Icons.insert_drive_file;
    }
  }

  late final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        size: 250,
        min: 200,
        builder: (context, area) {
          final discoveryState = ref.watch(discoveryControllerProvider);

          return Material(
            color: AppColors.sidebarDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Agents Config',
                          style: AppTextStyles.uiHeader,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<VoidCallback>(
                        icon: const Icon(Icons.add, size: 16),
                        tooltip: 'Add configuration',
                        onSelected: (callback) => callback(),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: () => unawaited(_showAddManualPathDialog()),
                            child: const Text('Add Manual Config Path'),
                          ),
                          PopupMenuItem(
                            value: () => unawaited(_showAddProjectRootDialog()),
                            child: const Text('Add Project Root'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: _showManageProjectRootsDialog,
                            child: const Text('Manage Project Roots'),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: () {
                          unawaited(
                            ref
                                .read(discoveryControllerProvider.notifier)
                                .refresh(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: discoveryState.when(
                    data: (result) {
                      if (result.items.isEmpty) {
                        if (result.warnings.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              result.warnings
                                  .map((w) => w.message)
                                  .join(
                                    '\n',
                                  ),
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No configurations found.'),
                        );
                      }
                      return ListView.builder(
                        itemCount: result.items.length,
                        itemBuilder: (context, index) {
                          final configItem = result.items[index];
                          return SidebarItem(
                            title: configItem.sourceLabel,
                            subtitle: configItem.filePath,
                            icon: configItem.descriptor != null
                                ? _getIconForTool(
                                    configItem.descriptor!.id.name,
                                  )
                                : Icons.insert_drive_file,
                            isActive: _activeConfigId == configItem.id,
                            onTap: () async {
                              await _loadConfig(configItem);
                            },
                            onRemove: configItem.isManual
                                ? () {
                                    unawaited(
                                      ref
                                          .read(
                                            discoveryControllerProvider
                                                .notifier,
                                          )
                                          .removeManualPath(
                                            configItem.filePath,
                                          ),
                                    );
                                  }
                                : null,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.tune,
                    size: 64,
                    color: AppColors.textSecondaryDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No configuration selected',
                    style: AppTextStyles.uiHeader.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a configuration from the sidebar to start editing.',
                    style: AppTextStyles.uiBase.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            );
          }

          final configService = ref.read(configServiceProvider);
          return ConfigEditor(
            config: _activeConfig!,
            // Save feedback (success/error SnackBars) is shown by
            // ConfigEditor itself; this callback only persists the change
            // and updates the active config. Errors propagate to
            // ConfigEditor's own try/catch.
            onSave: (config, [rawContent]) async {
              if (rawContent != null) {
                final updated = await configService.saveRawConfig(
                  config,
                  rawContent,
                );
                if (mounted) {
                  setState(() {
                    _activeConfig = updated;
                  });
                }
                return updated;
              } else {
                final updated = await configService.saveConfig(config);
                if (mounted) {
                  setState(() {
                    _activeConfig = updated;
                  });
                }
                return updated;
              }
            },
            resolvePath: configService.resolvePath,
            onShowHistory: _showHistoryModal,
            onDirtyChanged: (hasUnsavedChanges) {
              if (mounted) {
                setState(() {
                  _hasUnsavedChanges = hasUnsavedChanges;
                });
              }
            },
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

class _ManageProjectRootsDialog extends StatelessWidget {
  const _ManageProjectRootsDialog({
    required this.projectRoots,
    required this.onRemove,
  });

  final List<String> projectRoots;
  final void Function(String path) onRemove;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text(
        'Manage Project Roots',
        style: AppTextStyles.uiHeader,
      ),
      content: SizedBox(
        width: 500,
        child: projectRoots.isEmpty
            ? const Center(
                child: Text(
                  'No project roots configured.',
                  style: AppTextStyles.uiSecondary,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: projectRoots.length,
                itemBuilder: (context, index) {
                  final root = projectRoots[index];
                  return ListTile(
                    title: Text(
                      root,
                      style: AppTextStyles.codeBase,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.textSecondaryDark,
                      onPressed: () => onRemove(root),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimaryDark,
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

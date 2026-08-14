import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
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

    showDialog<void>(
      context: context,
      builder: (context) {
        final configService = ref.read(configServiceProvider);
        return HistoryModal(
          config: _activeConfig!,
          backupService: configService.backupService,
          onRestore: (backupPath) async {
            final targetPath = configService.resolvePath(_activeConfig!.filePath);
            await configService.backupService.restoreBackup(backupPath, targetPath);
            // Reload the config after restoring
            final configItem = ref.read(discoveryControllerProvider).value?.items.firstWhere(
              (item) => item.id == _activeConfigId,
            );
            if (configItem != null && mounted) {
              await _loadConfig(configItem);
            }
          },
        );
      },
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
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: () {
                          ref.read(discoveryControllerProvider.notifier).refresh();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: discoveryState.when(
                    data: (result) {
                      if (result.items.isEmpty) {
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
                            icon: configItem.descriptor != null ? _getIconForTool(configItem.descriptor!.id.name) : Icons.insert_drive_file,
                            isActive: _activeConfigId == configItem.id,
                            onTap: () async {
                              await _loadConfig(configItem);
                            },
                            onRemove: configItem.isManual ? () {
                              ref.read(discoveryControllerProvider.notifier).removeManualPath(configItem.filePath);
                            } : null,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
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
            return const Center(
              child: Text('Select a configuration from the sidebar.'),
            );
          }

          final configService = ref.read(configServiceProvider);
          return ConfigEditor(
            config: _activeConfig!,
            onSave: (config, [rawContent]) async {
              if (rawContent != null) {
                final updated = await configService.saveRawConfig(config, rawContent);
                if (mounted) {
                  setState(() {
                    _activeConfig = updated;
                  });
                }
                return updated;
              } else {
                await configService.saveConfig(config);
                if (mounted) {
                  setState(() {
                    _activeConfig = config;
                  });
                }
                return config;
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

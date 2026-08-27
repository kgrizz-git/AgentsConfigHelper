import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/screens/recovery_handler.dart';
import 'package:agents_config_helper/screens/tool_id_icons.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/utils/open_directory.dart';
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

class _MainShellState extends ConsumerState<MainShell>
    with RecoveryHandler<MainShell> {
  ToolConfig? _activeConfig;
  String? _activeConfigId;
  DiscoveredConfig? _activeDiscoveredConfig;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _rawRecoveryMode = false;
  String? _error;
  var _loadGeneration = 0;

  @override
  int get loadGeneration => _loadGeneration;

  @override
  ToolConfig? get activeConfig => _activeConfig;
  @override
  set activeConfig(ToolConfig? v) => _activeConfig = v;

  @override
  String? get activeConfigId => _activeConfigId;
  @override
  set activeConfigId(String? v) => _activeConfigId = v;

  @override
  String? get error => _error;
  @override
  set error(String? v) => _error = v;

  @override
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  @override
  set hasUnsavedChanges(bool v) => _hasUnsavedChanges = v;

  @override
  bool get rawRecoveryMode => _rawRecoveryMode;
  @override
  set rawRecoveryMode(bool v) => _rawRecoveryMode = v;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      _rawRecoveryMode = false;
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
          // Don't keep the failed file highlighted as active in the sidebar.
          _activeConfigId = null;
        });
        if (error is ConfigParseException || error is FileSystemException) {
          await showRecoveryDialog(configItem, error, generation);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading config: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Asks the user to confirm discarding unsaved changes before a destructive
  /// action. [actionLabel] names that action on the confirm button (e.g.
  /// "Discard & Load" when switching configs, "Discard & Remove" when removing
  /// the manual path), keeping the dialog copy honest about what will happen.
  Future<bool> _confirmDiscardChanges([
    String actionLabel = 'Discard & Load',
  ]) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'This will discard your unsaved changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  Future<void> _removeManualConfig(DiscoveredConfig configItem) async {
    final wasCatalogBacked = configItem.fromCatalog;
    final messenger = ScaffoldMessenger.of(context);
    ToolConfig? savedConfig;
    var savedDirty = false;
    try {
      if (!wasCatalogBacked &&
          _activeConfigId == configItem.id &&
          _hasUnsavedChanges) {
        final shouldDiscard = await _confirmDiscardChanges(
          'Discard & Remove',
        );
        if (!shouldDiscard || !mounted) return;
        savedConfig = _activeConfig;
        savedDirty = _hasUnsavedChanges;
        setState(() {
          _activeConfig = null;
          _activeConfigId = null;
          _hasUnsavedChanges = false;
        });
      }
      await ref
          .read(discoveryControllerProvider.notifier)
          .removeManualPath(configItem.filePath);
      if (!mounted) return;
      if (wasCatalogBacked) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from manual paths; '
              'still auto-detected and listed.',
            ),
          ),
        );
        return;
      }
      if (_activeConfigId == configItem.id) {
        setState(() {
          _activeConfig = null;
          _activeConfigId = null;
          _hasUnsavedChanges = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        if (savedConfig != null && _activeConfigId == null) {
          setState(() {
            _activeConfig = savedConfig;
            _hasUnsavedChanges = savedDirty;
          });
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not remove path: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void showHistoryModal() {
    if (_activeConfig == null) return;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          final configService = ref.read(configServiceProvider);
          return HistoryModal(
            config: _activeConfig!,
            onRestore: (backupPath) async {
              // Capture before any await: _loadConfig can null out
              // _activeConfig while the discard dialog is open.
              final activeConfig = _activeConfig;
              if (activeConfig == null) return;
              if (_hasUnsavedChanges) {
                final shouldDiscard = await _confirmDiscardChanges();
                if (!shouldDiscard || !mounted) {
                  return;
                }
                setState(() {
                  _hasUnsavedChanges = false;
                });
              }
              final targetPath = configService.resolvePath(
                activeConfig.filePath,
              );
              // Read the backup content first — createBackup prunes entries
              // beyond the 10-backup cap, which could delete the very backup
              // being restored if it's the oldest. Reading first avoids the
              // race.
              final backupContent = await configService.backupService
                  .readBackupBytes(backupPath);
              // Preserve the current on-disk file before overwriting it with
              // the restored snapshot, matching saveConfig/saveRawConfig. The
              // exists-check keeps a deleted target (restore-as-recreate) from
              // failing the backup step.
              if (await configService.fileExists(targetPath)) {
                await configService.backupService.createBackup(targetPath);
              }
              await configService.backupService.writeRestoredFile(
                targetPath,
                backupContent,
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
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => _ManageProjectRootsDialog(
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

  Future<void> _openBackupsFolder() async {
    if (ref.read(testRootPathProvider) != null) return;
    final configService = ref.read(configServiceProvider);
    final opened = await openDirectory(
      configService.backupService.backupDirectory,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the backups folder.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  late final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        size: 250,
        min: 200,
        builder: (context, area) {
          final discoveryState = ref.watch(discoveryControllerProvider);
          final testRoot = ref.watch(testRootPathProvider);

          return Material(
            color: AppColors.sidebarDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (testRoot case final activeTestRoot?)
                  Container(
                    width: double.infinity,
                    color: AppColors.warning,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'TEST ROOT MODE — $activeTestRoot',
                      style: AppTextStyles.uiSecondary.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            enabled: testRoot == null,
                            value: () => unawaited(_openBackupsFolder()),
                            child: const Text('Open Backups Folder'),
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
                      final warningBanner = result.warnings.isEmpty
                          ? null
                          : ConstrainedBox(
                              // Cap height and scroll internally so a burst
                              // of warnings can't overflow or crowd out the
                              // config list.
                              constraints: const BoxConstraints(maxHeight: 160),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    result.warnings
                                        .map((w) => w.message)
                                        .join('\n'),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            );

                      if (result.items.isEmpty) {
                        return warningBanner ??
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No configurations found.'),
                            );
                      }
                      final list = ListView.builder(
                        itemCount: result.items.length,
                        itemBuilder: (context, index) {
                          final configItem = result.items[index];
                          return SidebarItem(
                            title: configItem.sourceLabel,
                            subtitle: configItem.filePath,
                            icon: configItem.descriptor != null
                                ? iconForToolId(configItem.descriptor!.id)
                                : Icons.insert_drive_file,
                            isActive: _activeConfigId == configItem.id,
                            onTap: () async {
                              await _loadConfig(configItem);
                            },
                            onRemove: configItem.isManual
                                ? () => _removeManualConfig(configItem)
                                : null,
                          );
                        },
                      );

                      if (warningBanner == null) return list;
                      // Surface warnings even when configs were found, so a bad
                      // manual path or unresolved home dir isn't silently
                      // hidden behind a non-empty list.
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          warningBanner,
                          Expanded(child: list),
                        ],
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
            discoveredConfig: _activeDiscoveredConfig,
            // Save feedback (success/error SnackBars) is shown by
            // ConfigEditor itself; this callback only persists the change
            // and updates the active config. Errors propagate to
            // ConfigEditor's own try/catch.
            onSave: (config, [rawContent]) async {
              final ToolConfig updated;
              if (rawContent != null) {
                updated = await configService.saveRawConfig(
                  config,
                  rawContent,
                );
              } else {
                updated = await configService.saveConfig(config);
              }
              ref.invalidate(backupListProvider(config.filePath));
              if (mounted) {
                setState(() {
                  _activeConfig = updated;
                  // A successful save re-parses the content, so the full
                  // editor can take over again.
                  _rawRecoveryMode = false;
                });
              }
              return updated;
            },
            resolvePath: configService.resolvePath,
            hasUsableBaseline: configService.hasUsableBaseline,
            onShowHistory: showHistoryModal,
            allowOpenDirectory: ref.watch(testRootPathProvider) == null,
            rawOnly: _rawRecoveryMode,
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

class _ManageProjectRootsDialog extends ConsumerWidget {
  const _ManageProjectRootsDialog({required this.onRemove});

  final void Function(String path) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectRoots =
        ref.watch(discoveryControllerProvider).value?.projectRoots ?? [];
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

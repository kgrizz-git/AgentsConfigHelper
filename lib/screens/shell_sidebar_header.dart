import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reusable header row for the main shell sidebar, keeping the shell file
/// under the 700-line file cap.
class ShellSidebarHeader extends ConsumerWidget {
  /// Creates the header.
  const ShellSidebarHeader({
    required this.onShowOverview,
    required this.onAddManualPath,
    required this.onAddProjectRoot,
    required this.onManageProjectRoots,
    required this.onOpenBackups,
    required this.onRefresh,
    super.key,
  });

  /// Called when the Overview button is tapped.
  final VoidCallback onShowOverview;

  /// Called when "Add Manual Config Path" is selected.
  final VoidCallback? onAddManualPath;

  /// Called when "Add Project Root" is selected.
  final VoidCallback? onAddProjectRoot;

  /// Called when "Manage Project Roots" is selected.
  final VoidCallback? onManageProjectRoots;

  /// Called when "Open Backups Folder" is selected.
  final VoidCallback? onOpenBackups;

  /// Called when the refresh button is tapped.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testRoot = ref.watch(testRootPathProvider);

    return Padding(
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
            icon: const Icon(Icons.article, size: 16),
            tooltip: 'Overview',
            onPressed: onShowOverview,
          ),
          PopupMenuButton<VoidCallback>(
            icon: const Icon(Icons.add, size: 16),
            tooltip: 'Add configuration',
            onSelected: (callback) => callback(),
            itemBuilder: (context) => [
              if (onAddManualPath != null)
                PopupMenuItem(
                  value: onAddManualPath,
                  child: const Text('Add Manual Config Path'),
                ),
              if (onAddProjectRoot != null)
                PopupMenuItem(
                  value: onAddProjectRoot,
                  child: const Text('Add Project Root'),
                ),
              const PopupMenuDivider(),
              if (onManageProjectRoots != null)
                PopupMenuItem(
                  value: onManageProjectRoots,
                  child: const Text('Manage Project Roots'),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: testRoot == null,
                value: onOpenBackups,
                child: const Text('Open Backups Folder'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

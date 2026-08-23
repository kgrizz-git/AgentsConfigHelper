import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// A dialog listing backup snapshots for a configuration file, with the
/// ability to restore a selected backup over the live file.
class HistoryModal extends ConsumerStatefulWidget {
  /// Creates the modal for the given configuration.
  const HistoryModal({
    required this.config,
    required this.onRestore,
    super.key,
  });

  /// The configuration whose backup history is shown.
  final ToolConfig config;

  /// Invoked with the chosen backup's path after the user confirms restore.
  final Future<void> Function(String backupPath) onRestore;

  @override
  ConsumerState<HistoryModal> createState() => _HistoryModalState();
}

class _HistoryModalState extends ConsumerState<HistoryModal> {
  bool _isRestoring = false;

  Future<void> _confirmAndRestore(File backupFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Confirm Restore', style: AppTextStyles.uiHeader),
        content: const Text(
          'Are you sure you want to restore this backup? This will '
          'overwrite the current live configuration file.',
          style: AppTextStyles.uiSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimaryDark,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Confirm & Restore',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _restoreBackup(backupFile);
    }
  }

  Future<void> _restoreBackup(File backupFile) async {
    // Resolve messenger/navigator before the await + pop, so the lookups don't
    // depend on the dialog route still being present after it is dismissed.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isRestoring = true;
    });
    try {
      await widget.onRestore(backupFile.path);
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(
      backupListProvider(widget.config.filePath),
    );

    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text('History & Backups', style: AppTextStyles.uiHeader),
      content: SizedBox(
        width: 500,
        height: 400,
        child: backupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (backups) {
            if (backups.isEmpty) {
              return const Center(
                child: Text('No backups found for this file.'),
              );
            }
            return ListView.builder(
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                // Extract timestamp from filename
                final match = RegExp(
                  r'_(\d+)_\d+\.bak$',
                ).firstMatch(backup.path);
                DateTime? date;
                if (match != null) {
                  final timestamp = int.tryParse(match.group(1)!);
                  if (timestamp != null) {
                    date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
                  }
                }
                final dateStr = date != null
                    ? date.toString().split('.')[0]
                    : 'Unknown Date';
                return ListTile(
                  title: Text(
                    dateStr,
                    style: AppTextStyles.uiSecondary.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  subtitle: Text(
                    p.basename(backup.path),
                    style: AppTextStyles.uiSecondary,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: _isRestoring
                        ? null
                        : () => _confirmAndRestore(backup),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.restore),
                    label: const Text(
                      'Restore',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
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

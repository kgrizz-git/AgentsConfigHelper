import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class HistoryModal extends StatefulWidget {
  const HistoryModal({
    required this.config,
    required this.backupService,
    required this.onRestore,
    super.key,
  });

  final ToolConfig config;
  final BackupService backupService;
  final Future<void> Function(String backupPath) onRestore;

  @override
  State<HistoryModal> createState() => _HistoryModalState();
}

class _HistoryModalState extends State<HistoryModal> {
  late Future<List<File>> _backupsFuture;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _backupsFuture = widget.backupService.listBackups(widget.config.filePath);
  }

  Future<void> _confirmAndRestore(File backupFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Confirm Restore', style: AppTextStyles.uiHeader),
        content: const Text(
          'Are you sure you want to restore this backup? This will overwrite the current live configuration file.',
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
            ),
            child: const Text('Confirm & Restore'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _restoreBackup(backupFile);
    }
  }

  Future<void> _restoreBackup(File backupFile) async {
    setState(() {
      _isRestoring = true;
    });
    try {
      await widget.onRestore(backupFile.path);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text('History & Backups', style: AppTextStyles.uiHeader),
      content: SizedBox(
        width: 500,
        height: 400,
        child: FutureBuilder<List<File>>(
          future: _backupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final backups = snapshot.data ?? [];
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
                    backup.path.split('/').last,
                    style: AppTextStyles.uiSecondary,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ElevatedButton(
                    onPressed: _isRestoring
                        ? null
                        : () => _confirmAndRestore(backup),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                    ),
                    child: const Text('Restore'),
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

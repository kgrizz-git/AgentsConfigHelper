import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

enum RecoveryAction { openRawEditor, viewBackups, remove }

mixin RecoveryHandler<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  int get loadGeneration;

  ToolConfig? get activeConfig;
  set activeConfig(ToolConfig? value);

  String? get activeConfigId;
  set activeConfigId(String? value);

  String? get error;
  set error(String? value);

  bool get hasUnsavedChanges;
  set hasUnsavedChanges(bool value);

  bool get rawRecoveryMode;
  set rawRecoveryMode(bool value);

  void showHistoryModal();

  Future<void> showRecoveryDialog(
    DiscoveredConfig configItem,
    Object errorValue,
    int generation,
  ) async {
    final configService = ref.read(configServiceProvider);
    final resolvedPath = configService.resolvePath(configItem.filePath);

    var manualPaths = const <String>[];
    try {
      final prefsResult = await ref
          .read(discoveryPreferencesStoreProvider)
          .load();
      manualPaths = prefsResult.preferences.manualFilePaths;
    } on Object {
      // A failed preferences load degrades to "no remove action".
    }

    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io — desktop tool, not a hot loop
    final fileExists = await File(resolvedPath).exists();
    final backups = await configService.backupService.listBackups(resolvedPath);

    if (!mounted || generation != loadGeneration) return;

    final isManualPath = manualPaths.any(
      (path) => p.normalize(path) == p.normalize(configItem.filePath),
    );

    final action = await showDialog<RecoveryAction>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        title: const Text(
          'Configuration could not be loaded',
          style: AppTextStyles.uiHeader,
        ),
        content: Text(errorValue.toString(), style: AppTextStyles.uiSecondary),
        actions: [
          if (fileExists)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(RecoveryAction.openRawEditor),
              child: const Text('Open raw editor'),
            ),
          if (backups.isNotEmpty)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(RecoveryAction.viewBackups),
              child: const Text('View backups'),
            ),
          if (isManualPath)
            TextButton(
              onPressed: () => Navigator.of(context).pop(RecoveryAction.remove),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (!mounted || generation != loadGeneration) return;

    switch (action) {
      case RecoveryAction.openRawEditor:
        await openRawRecoveryEditor(configItem, generation);
      case RecoveryAction.viewBackups:
        await openRecoveryHistory(configItem, generation);
      case RecoveryAction.remove:
        setState(() {
          error = null;
          activeConfigId = null;
          activeConfig = null;
        });
        unawaited(
          ref
              .read(discoveryControllerProvider.notifier)
              .removeManualPath(configItem.filePath),
        );
      case null:
        setState(() {
          error = null;
          activeConfigId = null;
          activeConfig = null;
        });
    }
  }

  Future<void> openRawRecoveryEditor(
    DiscoveredConfig configItem,
    int generation,
  ) async {
    final configService = ref.read(configServiceProvider);
    final resolvedPath = configService.resolvePath(configItem.filePath);
    final String rawContent;
    try {
      rawContent = await File(resolvedPath).readAsString();
    } on Object catch (e) {
      if (mounted && generation == loadGeneration) {
        setState(() {
          error = null;
          activeConfigId = null;
          activeConfig = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open the raw editor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted || generation != loadGeneration) return;

    setState(() {
      error = null;
      activeConfig = ToolConfig(
        toolName: configItem.sourceLabel,
        filePath: configItem.filePath,
        format: configItem.format,
        originalContent: rawContent,
      );
      hasUnsavedChanges = false;
      rawRecoveryMode = true;
    });
  }

  Future<void> openRecoveryHistory(
    DiscoveredConfig configItem,
    int generation,
  ) async {
    final configService = ref.read(configServiceProvider);
    final resolvedPath = configService.resolvePath(configItem.filePath);
    var rawContent = '';
    try {
      rawContent = await File(resolvedPath).readAsString();
    } on Object {
      // A deleted file still allows browsing backups.
    }
    if (!mounted || generation != loadGeneration) return;

    setState(() {
      error = null;
      activeConfig = ToolConfig(
        toolName: configItem.sourceLabel,
        filePath: configItem.filePath,
        format: configItem.format,
        originalContent: rawContent,
      );
      hasUnsavedChanges = false;
      rawRecoveryMode = true;
    });
    showHistoryModal();
  }
}

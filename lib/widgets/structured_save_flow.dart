import 'dart:async';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/formatting_fidelity_notice.dart';
import 'package:agents_config_helper/widgets/raw_diff_view.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Encapsulates the fallback-rewrite save flow so the editor only needs a
/// thin entrypoint.
class StructuredSaveFlow {
  /// Shows the fallback-rewrite confirmation dialog.
  /// Asks whether to overwrite a file that changed after the preview.
  static Future<bool?> showConflictDialog(
    BuildContext context,
    SaveConflictException conflict,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File changed on disk'),
        content: const Text(
          'This file changed after you opened it. Overwrite those changes? '
          'Cancel and reopen the file to reload instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showFallbackRewriteDialog(
    BuildContext context,
    SerializationFallbackException e,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        title: const Text(
          'Save would change formatting',
          style: AppTextStyles.uiHeader,
        ),
        content: Text(
          'A structured save of this ${e.format} file must rebuild the '
          'document and would lose ${e.wouldBeLost}. '
          'Edit the raw content instead, or allow the rewrite.',
          style: AppTextStyles.uiSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimaryDark,
            ),
            child: const Text('Edit raw instead'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rewrite document'),
          ),
        ],
      ),
    );
  }

  /// Runs the save attempt, falling back to a confirmation dialog on
  /// [SerializationFallbackException] and retrying with the rewrite allowed
  /// if the user approves.
  static Future<void> run({
    required BuildContext context,
    required bool Function() isMounted,
    required String? Function() rawContent,
    required ToolConfig Function() buildUpdatedConfig,
    required Future<ToolConfig> Function(
      ToolConfig config, {
      String? rawContent,
      bool? allowRewrite,
      bool? overwriteConfirmed,
    })
    onSave,
    required void Function(ToolConfig savedConfig) onSuccess,
    required void Function(Object error) onError,
    required void Function() setSavingFalse,
  }) async {
    try {
      final savedConfig = await onSave(
        buildUpdatedConfig(),
        rawContent: rawContent(),
        allowRewrite: false,
      );
      if (!isMounted()) return;
      onSuccess(savedConfig);
    } on SaveConflictException catch (conflict) {
      if (!context.mounted) return;
      final overwrite = await showConflictDialog(context, conflict);
      if (overwrite != true || !context.mounted) return;
      try {
        // A conflict is not a serialization fallback. Retry with the fallback
        // gate closed and require its own consent if the changed source needs
        // a whole-document rewrite.
        late final ToolConfig savedConfig;
        try {
          savedConfig = await onSave(
            buildUpdatedConfig(),
            rawContent: rawContent(),
            allowRewrite: false,
            overwriteConfirmed: true,
          );
        } on SerializationFallbackException catch (fallback) {
          if (!context.mounted) return;
          final proceed = await showFallbackRewriteDialog(context, fallback);
          if (proceed != true || !context.mounted) return;
          savedConfig = await onSave(
            buildUpdatedConfig(),
            rawContent: rawContent(),
            allowRewrite: true,
            overwriteConfirmed: true,
          );
        }
        if (!isMounted()) return;
        onSuccess(savedConfig);
      } on Object catch (error) {
        if (!isMounted()) return;
        onError(error);
      }
    } on SerializationFallbackException catch (e) {
      if (!context.mounted) return;
      final proceed = await showFallbackRewriteDialog(context, e);
      if (proceed != true || !context.mounted) return;
      try {
        final savedConfig = await onSave(
          buildUpdatedConfig(),
          rawContent: rawContent(),
          allowRewrite: true,
        );
        if (!isMounted()) return;
        onSuccess(savedConfig);
      } on Object catch (error) {
        if (!isMounted()) return;
        onError(error);
      }
    } on Object catch (error) {
      if (!isMounted()) return;
      onError(error);
    } finally {
      if (isMounted()) setSavingFalse();
    }
  }

  /// Builds one list section in the visual diff, moved here from
  /// `ConfigEditor` to hold that file's line cap; logic unchanged.
  static Widget buildDiffSection(
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
              Text('+ $item', style: const TextStyle(color: AppColors.success)),
        ),
        ...removed.map(
          (item) =>
              Text('- $item', style: const TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  /// Builds the raw-content section in the visual diff.
  static Widget buildRawDiffSection(String original, String updated) {
    return RawDiffView(original: original, updated: updated);
  }

  /// Shows the review modal for unsaved changes.
  static Future<void> showDiffModal({
    required BuildContext context,
    required bool Function() isMounted,
    required bool Function() isCurrentRevision,
    required Future<FidelityAssessment?> Function() pendingFidelityAssessment,
    required Future<String?> Function() pendingSavePreview,
    required bool supportsStructuredFields,
    required bool rawOnly,
    required List<String> currentRules,
    required List<String> currentPermissions,
    required List<String> rules,
    required List<String> permissions,
    required String originalContent,
    required String rawContent,
    required Widget Function(String, List<String>, List<String>)
    buildDiffSection,
    required Widget Function(String, String) buildRawDiffSection,
    required bool saving,
    required Future<void> Function() onSaveChanges,
  }) async {
    final assessment = await pendingFidelityAssessment();
    final preview = await pendingSavePreview();
    if (!context.mounted || !isCurrentRevision()) return;

    await showDialog<void>(
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
                if (supportsStructuredFields && !rawOnly) ...[
                  buildDiffSection('Rules', currentRules, rules),
                  const SizedBox(height: 16),
                  buildDiffSection(
                    'Permissions',
                    currentPermissions,
                    permissions,
                  ),
                  if (assessment != null) ...[
                    const SizedBox(height: 16),
                    FormattingFidelityNotice(
                      assessment: assessment,
                      showOpeningStatement: false,
                    ),
                  ],
                ],
                if (preview != null &&
                    supportsStructuredFields &&
                    !rawOnly) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Serialized result',
                    style: AppTextStyles.uiSubheader,
                  ),
                  const SizedBox(height: 8),
                  buildRawDiffSection(originalContent, preview),
                ],
                if (rawContent != originalContent) ...[
                  const SizedBox(height: 16),
                  buildRawDiffSection(
                    originalContent,
                    rawContent,
                  ),
                ],
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
              onPressed: saving
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      unawaited(onSaveChanges());
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
    );
  }
}

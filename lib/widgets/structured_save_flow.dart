import 'dart:async';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/formatting_fidelity_notice.dart';
import 'package:flutter/material.dart';

/// Encapsulates the fallback-rewrite save flow so the editor only needs a
/// thin entrypoint.
class StructuredSaveFlow {
  /// Shows the fallback-rewrite confirmation dialog.
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

  /// Shows the review modal for unsaved changes.
  static Future<void> showDiffModal({
    required BuildContext context,
    required bool Function() isMounted,
    required bool Function() isCurrentRevision,
    required Future<FidelityAssessment?> Function() pendingFidelityAssessment,
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

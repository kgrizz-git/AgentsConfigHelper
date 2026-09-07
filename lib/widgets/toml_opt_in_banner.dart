import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Banner shown when a TOML file is opened but structured saves are disabled.
class TomlOptInBanner extends StatelessWidget {
  /// Creates the banner.
  const TomlOptInBanner({
    required this.onEnable,
    super.key,
  });

  /// Called when the user accepts the warning and enables structured saves.
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Structured TOML editing is disabled',
                  style: AppTextStyles.uiSubheader.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enabling structured save will discard existing comments '
                  'and reformat this file. Enable only if you accept that '
                  'loss.',
                  style: AppTextStyles.uiSecondary.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onEnable,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                  ),
                  child: const Text('Enable structured TOML editing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact opt-out row shown while structured TOML editing is enabled.
///
/// It restates the ongoing risk in one line and offers the off-ramp, so the
/// opt-in can always be reversed from the same surface that granted it.
class TomlOptOutRow extends StatelessWidget {
  /// Creates the row.
  const TomlOptOutRow({
    required this.onDisable,
    super.key,
  });

  /// Called when the user opts back out of structured TOML saves.
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Structured TOML editing is on.',
            style: AppTextStyles.uiSecondary.copyWith(
              color: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onDisable,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.warning,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Disable'),
        ),
      ],
    );
  }
}

import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Banner shown when a TOML file is opened but structured saves are disabled.
class TomlOptInBanner extends StatelessWidget {
  const TomlOptInBanner({
    required this.onEnable,
    super.key,
  });

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

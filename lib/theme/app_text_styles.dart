import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shared text styles for application UI and configuration content.
class AppTextStyles {
  /// Default sans-serif text for UI controls.
  static const TextStyle uiBase = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 14,
  );

  /// Heading style for screen titles.
  static const TextStyle uiHeader = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  /// Heading style for editor sections.
  static const TextStyle uiSubheader = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// Secondary explanatory text style.
  static const TextStyle uiSecondary = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textSecondaryDark,
    fontSize: 13,
  );

  /// Monospaced style for configuration values.
  static const TextStyle codeBase = TextStyle(
    fontFamily: 'JetBrains Mono',
    color: AppColors.textPrimaryDark,
    fontSize: 13,
  );
}

import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_colors.dart';

class AppTextStyles {
  // Clean sans-serif for UI
  static const TextStyle uiBase = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 14,
  );

  static const TextStyle uiHeader = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle uiSubheader = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textPrimaryDark,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle uiSecondary = TextStyle(
    fontFamily: 'Inter',
    color: AppColors.textSecondaryDark,
    fontSize: 13,
  );

  // Modern monospaced for code and config snippets
  static const TextStyle codeBase = TextStyle(
    fontFamily: 'JetBrains Mono',
    color: AppColors.textPrimaryDark,
    fontSize: 13,
  );
}

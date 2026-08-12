import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agents_config_helper/theme/app_colors.dart';

class AppTextStyles {
  // Clean sans-serif for UI
  static final TextStyle uiBase = GoogleFonts.inter(
    color: AppColors.textPrimaryDark,
    fontSize: 14,
  );

  static final TextStyle uiHeader = GoogleFonts.inter(
    color: AppColors.textPrimaryDark,
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle uiSubheader = GoogleFonts.inter(
    color: AppColors.textPrimaryDark,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle uiSecondary = GoogleFonts.inter(
    color: AppColors.textSecondaryDark,
    fontSize: 13,
  );

  // Modern monospaced for code and config snippets
  static final TextStyle codeBase = GoogleFonts.jetBrainsMono(
    color: AppColors.textPrimaryDark,
    fontSize: 13,
  );
}

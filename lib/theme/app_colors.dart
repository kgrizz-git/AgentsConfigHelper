import 'package:flutter/material.dart';

/// Defines the exact color hexes used across the application.
class AppColors {
  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF1E1E1E); // Main editor area
  static const Color sidebarDark = Color(0xFF181818); // Sidebar area
  static const Color surfaceDark = Color(0xFF252526); // Cards, modals, popups
  static const Color surfaceHighlightDark = Color(0xFF2D2D2D); // Hover states
  static const Color borderDark = Color(0xFF333333); // Subtle dividers

  // Accent Colors
  static const Color primaryAccent = Color(0xFF007ACC); // VS Code/Cursor blue
  static const Color primaryAccentHover = Color(0xFF005999);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFF44336);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);

  // Diff Colors
  static const Color diffAddBg = Color(0xFF274028); // Dark green
  static const Color diffRemoveBg = Color(0xFF4C2727); // Dark red
}

import 'package:flutter/material.dart';

/// Defines the exact color hexes used across the application.
class AppColors {
  /// Editor background color.
  static const Color backgroundDark = Color(0xFF1E1E1E); // Main editor area

  /// Sidebar background color.
  static const Color sidebarDark = Color(0xFF181818); // Sidebar area

  /// Surface color for cards and dialogs.
  static const Color surfaceDark = Color(0xFF252526); // Cards, modals, popups

  /// Hovered dark surface color.
  static const Color surfaceHighlightDark = Color(0xFF2D2D2D); // Hover states

  /// Subtle dark divider color.
  static const Color borderDark = Color(0xFF333333); // Subtle dividers

  /// Primary interactive accent color.
  static const Color primaryAccent = Color(0xFF007ACC); // VS Code/Cursor blue

  /// Hovered primary accent color.
  static const Color primaryAccentHover = Color(0xFF005999);

  /// Success status color.
  static const Color success = Color(0xFF4CAF50);

  /// Warning status color.
  static const Color warning = Color(0xFFFFA000);

  /// Error status color.
  static const Color error = Color(0xFFF44336);

  /// Primary text color on dark surfaces.
  static const Color textPrimaryDark = Color(0xFFE0E0E0);

  /// Secondary text color on dark surfaces.
  static const Color textSecondaryDark = Color(0xFFA0A0A0);

  /// Background used for added diff rows.
  static const Color diffAddBg = Color(0xFF274028); // Dark green

  /// Background used for removed diff rows.
  static const Color diffRemoveBg = Color(0xFF4C2727); // Dark red
}

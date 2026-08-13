import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A selectable tool entry in the application sidebar.
class SidebarItem extends StatelessWidget {
  /// Creates a sidebar entry with its label, icon, and optional tap handler.
  const SidebarItem({
    required this.title,
    required this.icon,
    super.key,
    this.isActive = false,
    this.onTap,
  });

  /// The entry label.
  final String title;

  /// The entry icon.
  final IconData icon;

  /// Whether the entry represents the active configuration.
  final bool isActive;

  /// Called when the entry is selected.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHighlightDark : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.primaryAccent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : AppColors.textSecondaryDark,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: AppTextStyles.uiBase.copyWith(
                color: isActive ? Colors.white : AppColors.textPrimaryDark,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

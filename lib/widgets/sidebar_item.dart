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
    this.subtitle,
    this.isActive = false,
    this.onTap,
    this.onRemove,
  });

  /// The entry label.
  final String title;

  /// An optional subtitle (e.g. file path).
  final String? subtitle;

  /// The entry icon.
  final IconData icon;

  /// Whether the entry represents the active configuration.
  final bool isActive;

  /// Called when the entry is selected.
  final VoidCallback? onTap;

  /// Called when the remove icon is selected.
  final VoidCallback? onRemove;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.uiBase.copyWith(
                      color: isActive
                          ? Colors.white
                          : AppColors.textPrimaryDark,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.uiSecondary.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onRemove != null) ...[
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.textSecondaryDark,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

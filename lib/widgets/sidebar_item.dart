import 'package:flutter/material.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.title,
    required this.icon,
    this.isActive = false,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isActive;
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
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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

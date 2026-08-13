import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/widgets/sidebar_item.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(
        size: 250,
        min: 200,
        builder: (context, area) {
          return Material(
            color: AppColors.sidebarDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Agents Config',
                    style: AppTextStyles.uiHeader,
                  ),
                ),
                SidebarItem(
                  title: 'Claude Code',
                  icon: Icons.code,
                  isActive: true,
                  onTap: () {},
                ),
                SidebarItem(
                  title: 'Cursor',
                  icon: Icons.edit,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          );
        },
      ),
      Area(
        flex: 1,
        builder: (context, area) {
          return ColoredBox(
            color: AppColors.backgroundDark,
            child: const Center(
              child: Text(
                'Configuration Area (WIP)',
                style: AppTextStyles.uiSubheader,
              ),
            ),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.grooved1(
            color: AppColors.borderDark,
            highlightedColor: AppColors.primaryAccent,
            size: 10,
          ),
        ),
        child: MultiSplitView(
          controller: _controller,
        ),
      ),
    );
  }
}

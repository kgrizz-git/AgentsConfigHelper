import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders the Markdown config overview report inline.
class ConfigOverviewScreen extends ConsumerWidget {
  /// Creates the screen.
  const ConfigOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryAsync = ref.watch(discoveryControllerProvider);
    final homeDir = ref.read(homeDirectoryResolverProvider)();
    if (homeDir == null) {
      return Center(
        child: Text(
          'Error: cannot resolve home directory',
          style: AppTextStyles.uiBase.copyWith(color: AppColors.error),
        ),
      );
    }

    return discoveryAsync.when(
      data: (discovery) {
        final entries = buildOverviewModel(
          discovery,
          ToolDescriptorRegistry.catalog,
          homePath: homeDir,
          projectRoots: discovery.projectRoots,
        );
        final markdown = buildMarkdownReport(entries);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: MarkdownBody(
            data: markdown,
            styleSheet: MarkdownStyleSheet(
              p: AppTextStyles.uiBase,
              h1: AppTextStyles.uiHeader,
              h2: AppTextStyles.uiSubheader,
              a: const TextStyle(color: AppColors.primaryAccent),
              blockquote: AppTextStyles.uiSecondary,
              code: AppTextStyles.codeBase,
            ),
            onTapLink: (text, href, title) async {
              if (href == null) return;
              final target = Uri.parse(href);
              if (await canLaunchUrl(target)) {
                await launchUrl(target);
              }
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: AppTextStyles.uiBase.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a validated Claude Code permission policy without editing it.
class ClaudeCodePermissionsCard extends StatelessWidget {
  /// Creates a card for a recognized Claude Code permission policy.
  const ClaudeCodePermissionsCard({
    required this.presentation,
    this.onOpenDocumentation,
    super.key,
  });

  /// The validated permission values to display.
  final ClaudeCodePermissionsPresentation presentation;

  /// Opens the primary Claude Code permission documentation.
  final Future<bool> Function(Uri uri)? onOpenDocumentation;

  Future<void> _openDocumentation(BuildContext context) async {
    final launcher = onOpenDocumentation ?? _launchDocumentation;
    try {
      final opened = await launcher(
        ClaudeCodePermissionsAdapter.documentationUri,
      );
      if (!opened && context.mounted) {
        _showDocumentationLaunchError(context);
      }
    } on Object {
      if (context.mounted) {
        _showDocumentationLaunchError(context);
      }
    }
  }

  void _showDocumentationLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open Claude Code permissions documentation.'),
      ),
    );
  }

  static Future<bool> _launchDocumentation(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildGroup(String title, List<String> rules) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${rules.length})', style: AppTextStyles.uiSubheader),
          const SizedBox(height: 6),
          if (rules.isEmpty)
            const Text(
              'No explicit rules.',
              style: AppTextStyles.uiSecondary,
            )
          else
            ...rules.map(
              (rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText('• $rule', style: AppTextStyles.codeBase),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.policy_outlined, color: AppColors.primaryAccent),
              SizedBox(width: 8),
              Text('Claude Code permissions', style: AppTextStyles.uiSubheader),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Claude Code evaluates matching rules in deny, ask, then allow '
            'order. '
            'This card reflects the file and does not change it.',
            style: AppTextStyles.uiSecondary,
          ),
          if (!presentation.hasConfiguredPolicy) ...[
            const SizedBox(height: 16),
            const Text(
              'No Claude Code permissions policy is configured. Use raw '
              'content to add permissions.allow, permissions.ask, or '
              'permissions.deny.',
              style: AppTextStyles.uiSecondary,
            ),
          ],
          if (presentation.defaultMode != null) ...[
            const SizedBox(height: 16),
            Text(
              'Default mode: ${presentation.defaultMode}',
              style: AppTextStyles.uiBase,
            ),
          ],
          _buildGroup('Allow', presentation.allow),
          _buildGroup('Ask', presentation.ask),
          _buildGroup('Deny', presentation.deny),
          if (presentation.hasUnclassifiedSettings) ...[
            const SizedBox(height: 16),
            const Text(
              'Additional permission settings are available only in raw '
              'content.',
              style: AppTextStyles.uiSecondary,
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await _openDocumentation(context);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Claude Code permissions documentation'),
          ),
        ],
      ),
    );
  }
}

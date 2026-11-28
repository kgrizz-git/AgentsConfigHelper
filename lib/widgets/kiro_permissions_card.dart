import 'package:agents_config_helper/schemas/kiro_permissions.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays validated Kiro permission rules without editing them.
class KiroPermissionsCard extends StatelessWidget {
  /// Creates a card for a recognized Kiro permissions file.
  const new({
    required this.presentation,
    this.onOpenDocumentation,
    super.key,
  });

  /// The validated stored rules to display.
  final KiroPermissionsPresentation presentation;

  /// Opens the primary Kiro permissions documentation.
  final Future<bool> Function(Uri uri)? onOpenDocumentation;

  Future<void> _openDocumentation(BuildContext context) async {
    final launcher = onOpenDocumentation ?? _launchDocumentation;
    try {
      final opened = await launcher(KiroPermissionsAdapter.documentationUri);
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
    if (Scaffold.maybeOf(context) == null) {
      debugPrint('Unable to open Kiro permissions documentation.');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('Unable to open Kiro permissions documentation.');
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to open Kiro permissions documentation.'),
      ),
    );
  }

  static Future<bool> _launchDocumentation(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showFieldHelp(
    BuildContext context,
    KiroPermissionFieldHelp help,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(help.label),
        content: Text(help.description),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpButton(
    BuildContext context,
    KiroPermissionFieldHelp help,
  ) {
    return IconButton(
      onPressed: () async {
        await _showFieldHelp(context, help);
      },
      icon: const Icon(Icons.help_outline, size: 18),
      tooltip: help.description,
    );
  }

  Color _effectColor(String effect) {
    return switch (effect) {
      'deny' => AppColors.error,
      'ask' => AppColors.warning,
      'allow' => AppColors.success,
      'evaluate' => AppColors.primaryAccent,
      _ => AppColors.textSecondaryDark,
    };
  }

  Widget _buildEffect(BuildContext context, KiroPermissionRule rule) {
    final help = KiroPermissionsHelp.effect(rule.effect);
    final color = _effectColor(rule.effect);
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Effect', style: AppTextStyles.uiSecondary),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            rule.effect,
            style: AppTextStyles.codeBase.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _buildHelpButton(context, help),
      ],
    );
  }

  Widget _buildPatterns(
    BuildContext context,
    KiroPermissionFieldHelp help,
    List<String>? patterns,
  ) {
    final count = patterns == null ? '' : ' (${patterns.length})';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${help.label}$count',
                  style: AppTextStyles.uiSubheader,
                ),
              ),
              const SizedBox(width: 4),
              _buildHelpButton(context, help),
            ],
          ),
          const SizedBox(height: 4),
          if (patterns == null)
            const Text('Not set.', style: AppTextStyles.uiSecondary)
          else if (patterns.isEmpty)
            const Text('No patterns.', style: AppTextStyles.uiSecondary)
          else
            ...patterns.map(
              (pattern) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '• $pattern',
                  style: AppTextStyles.codeBase,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRule(BuildContext context, KiroPermissionRule rule) {
    final capability = KiroPermissionsHelp.capability(rule.capability);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capability.label,
                      style: AppTextStyles.uiSubheader,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule.capability,
                      style: AppTextStyles.codeBase.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _buildHelpButton(context, capability),
            ],
          ),
          const SizedBox(height: 8),
          _buildEffect(context, rule),
          const SizedBox(height: 6),
          Text(
            KiroPermissionsHelp.rule.description,
            style: AppTextStyles.uiSecondary,
          ),
          _buildPatterns(context, KiroPermissionsHelp.match, rule.match),
          _buildPatterns(context, KiroPermissionsHelp.exclude, rule.exclude),
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
              Expanded(
                child: Text(
                  'Kiro permissions',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.uiSubheader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            KiroPermissionsHelp.policy.description,
            style: AppTextStyles.uiSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            KiroPermissionsHelp.readOnly.description,
            style: AppTextStyles.uiSecondary,
          ),
          if (presentation.rules.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'No Kiro permission rules are stored in this file.',
              style: AppTextStyles.uiSecondary,
            ),
          ] else
            ...presentation.rules.map(
              (rule) => _buildRule(context, rule),
            ),
          if (presentation.hasUnclassifiedSettings) ...[
            const SizedBox(height: 16),
            const Text(
              'Additional Kiro permission settings are available only in raw '
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
            label: const Text('Kiro permissions documentation'),
          ),
        ],
      ),
    );
  }
}

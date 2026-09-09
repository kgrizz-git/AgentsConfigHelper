import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a validated Opencode permission block without mutating it.
class OpencodePermissionsCard extends StatelessWidget {
  /// Creates a card for a recognized Opencode permission block.
  const OpencodePermissionsCard({
    required this.presentation,
    this.onOpenDocumentation,
    super.key,
  });

  /// The validated permission values to display.
  final OpencodePermissionsPresentation presentation;

  /// Opens the primary Opencode permissions documentation.
  final Future<bool> Function(Uri uri)? onOpenDocumentation;

  Future<void> _openDocumentation(BuildContext context) async {
    final launcher = onOpenDocumentation ?? _launchDocumentation;
    try {
      final opened = await launcher(
        OpencodePermissionsAdapter.documentationUri,
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
    if (Scaffold.maybeOf(context) == null) {
      debugPrint('Unable to open Opencode permissions documentation.');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('Unable to open Opencode permissions documentation.');
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to open Opencode permissions documentation.'),
      ),
    );
  }

  static Future<bool> _launchDocumentation(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showFieldHelp(
    BuildContext context,
    OpencodePermissionFieldHelp help,
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
    OpencodePermissionFieldHelp help,
  ) {
    return IconButton(
      onPressed: () async {
        await _showFieldHelp(context, help);
      },
      icon: const Icon(Icons.help_outline, size: 18),
      tooltip: help.description,
    );
  }

  /// Builds one permission group: a Global scalar action or a per-tool entry
  /// that shows either a scalar action or bulleted `pattern → action` rules.
  Widget _buildGroup({
    required BuildContext context,
    required OpencodePermissionFieldHelp help,
    required String? scalar,
    Map<String, String>? patterns,
  }) {
    final count = patterns == null ? '' : ' (${patterns.length})';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${help.label}$count',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.uiSubheader,
                ),
              ),
              const SizedBox(width: 4),
              _buildHelpButton(context, help),
            ],
          ),
          const SizedBox(height: 6),
          if (scalar != null)
            SelectableText(scalar, style: AppTextStyles.codeBase)
          else if (patterns != null && patterns.isEmpty)
            const Text('No rules.', style: AppTextStyles.uiSecondary)
          else if (patterns != null)
            ...patterns.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '• ${entry.key} → ${entry.value}',
                  style: AppTextStyles.codeBase,
                ),
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
              Expanded(
                child: Text(
                  'Opencode permissions',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.uiSubheader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            OpencodePermissionsHelp.policy.description,
            style: AppTextStyles.uiSecondary,
          ),
          if (!presentation.hasConfiguredPermission) ...[
            const SizedBox(height: 16),
            const Text(
              'No Opencode permissions policy is configured. Legacy tools '
              'settings are not shown. Use raw content to add a permission '
              'block.',
              style: AppTextStyles.uiSecondary,
            ),
          ],
          if (presentation.globalAction != null)
            _buildGroup(
              context: context,
              help: OpencodePermissionsHelp.global,
              scalar: presentation.globalAction,
            ),
          ...presentation.tools.entries.map(
            (entry) => _buildGroup(
              context: context,
              help: OpencodePermissionsHelp.toolPermission(entry.key),
              scalar: entry.value.action,
              patterns: entry.value.patterns,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await _openDocumentation(context);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Opencode permissions documentation'),
          ),
        ],
      ),
    );
  }
}

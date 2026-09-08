import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a validated Cursor Agent permissions policy without editing it.
class CursorPermissionsCard extends StatelessWidget {
  /// Creates a card for a recognized Cursor Agent permissions policy.
  const CursorPermissionsCard({
    required this.presentation,
    this.onOpenDocumentation,
    super.key,
  });

  /// The validated permission values to display.
  final CursorPermissionsPresentation presentation;

  /// Opens the primary Cursor Agent permissions documentation.
  final Future<bool> Function(Uri uri)? onOpenDocumentation;

  Future<void> _openDocumentation(BuildContext context) async {
    final launcher = onOpenDocumentation ?? _launchDocumentation;
    try {
      final opened = await launcher(CursorPermissionsAdapter.documentationUri);
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
      debugPrint('Unable to open Cursor Agent permissions documentation.');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('Unable to open Cursor Agent permissions documentation.');
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to open Cursor Agent permissions documentation.'),
      ),
    );
  }

  static Future<bool> _launchDocumentation(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showFieldHelp(
    BuildContext context,
    CursorPermissionFieldHelp help,
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
    CursorPermissionFieldHelp help,
  ) {
    return IconButton(
      onPressed: () async {
        await _showFieldHelp(context, help);
      },
      icon: const Icon(Icons.help_outline, size: 18),
      tooltip: help.description,
    );
  }

  Widget _buildGroup(
    BuildContext context,
    CursorPermissionFieldHelp help,
    List<String>? entries,
  ) {
    final count = entries == null ? '' : ' (${entries.length})';
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
          if (entries == null)
            const Text('Not set.', style: AppTextStyles.uiSecondary)
          else if (entries.isEmpty)
            const Text('No entries.', style: AppTextStyles.uiSecondary)
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '• $entry',
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
                  'Cursor Agent permissions',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.uiSubheader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CursorPermissionsHelp.policy.description,
            style: AppTextStyles.uiSecondary,
          ),
          _buildGroup(
            context,
            CursorPermissionsHelp.mcpAllowlist,
            presentation.mcpAllowlist,
          ),
          _buildGroup(
            context,
            CursorPermissionsHelp.terminalAllowlist,
            presentation.terminalAllowlist,
          ),
          _buildGroup(
            context,
            CursorPermissionsHelp.allowInstructions,
            presentation.allowInstructions,
          ),
          _buildGroup(
            context,
            CursorPermissionsHelp.blockInstructions,
            presentation.blockInstructions,
          ),
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
            label: const Text('Cursor Agent permissions documentation'),
          ),
        ],
      ),
    );
  }
}

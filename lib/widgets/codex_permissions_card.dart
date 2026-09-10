import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a validated Codex permission configuration without mutating it.
class CodexPermissionsCard extends StatelessWidget {
  /// Creates a card for a recognized Codex `config.toml` permission block.
  const CodexPermissionsCard({
    required this.presentation,
    this.onOpenDocumentation,
    super.key,
  });

  /// The validated permission values to display.
  final CodexPermissionsPresentation presentation;

  /// Opens the primary Codex permissions documentation.
  final Future<bool> Function(Uri uri)? onOpenDocumentation;

  Future<void> _openDocumentation(BuildContext context) async {
    final launcher = onOpenDocumentation ?? _launchDocumentation;
    try {
      final opened = await launcher(
        CodexPermissionsAdapter.documentationUri,
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
      debugPrint('Unable to open Codex permissions documentation.');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('Unable to open Codex permissions documentation.');
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to open Codex permissions documentation.'),
      ),
    );
  }

  static Future<bool> _launchDocumentation(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showFieldHelp(
    BuildContext context,
    CodexPermissionFieldHelp help,
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
    CodexPermissionFieldHelp help,
  ) {
    return IconButton(
      onPressed: () async {
        await _showFieldHelp(context, help);
      },
      icon: const Icon(Icons.help_outline, size: 18),
      tooltip: help.description,
    );
  }

  /// Builds one labeled group with a help button and read-only rows.
  Widget _buildGroup({
    required BuildContext context,
    required CodexPermissionFieldHelp help,
    required List<String> rows,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  help.label,
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
          if (rows.isEmpty)
            const Text('No entries.', style: AppTextStyles.uiSecondary)
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(row, style: AppTextStyles.codeBase),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the legacy sandbox/approval rows for stored values.
  Widget _buildLegacy(BuildContext context) {
    final rows = <String>[];
    final sandboxMode = presentation.sandboxMode;
    if (sandboxMode != null) rows.add('sandbox_mode → $sandboxMode');
    final approvalPolicy = presentation.approvalPolicy;
    if (approvalPolicy != null) {
      rows.add('approval_policy → $approvalPolicy');
    }
    return _buildGroup(
      context: context,
      help: CodexPermissionsHelp.legacy,
      rows: rows,
    );
  }

  /// Builds the default-profile selection row.
  Widget _buildSelection(BuildContext context) {
    final selection = presentation.defaultPermissions;
    final rows = <String>[selection ?? 'Not set.'];
    if (selection != null &&
        !CodexPermissionsAdapter.builtinProfileNames.contains(selection) &&
        !presentation.profiles.any((profile) => profile.name == selection)) {
      rows.add('Not defined in this file.');
    }
    return _buildGroup(
      context: context,
      help: CodexPermissionsHelp.selection,
      rows: rows,
    );
  }

  /// Builds the filesystem rows for one profile. Entries that carry no
  /// values still render as a bare path so no stored key silently vanishes.
  List<String> _filesystemRows(CodexPermissionProfile profile) {
    final rows = <String>[];
    final filesystem = profile.filesystem;
    if (filesystem == null) return rows;
    for (final entry in filesystem) {
      final access = entry.access;
      final subpaths = entry.subpaths;
      if (access != null) rows.add('• ${entry.path} → $access');
      if (subpaths != null && subpaths.isNotEmpty) {
        rows.add('${entry.path}:');
        for (final sub in subpaths.entries) {
          rows.add('• ${sub.key} → ${sub.value}');
        }
      }
      if (access == null && (subpaths == null || subpaths.isEmpty)) {
        rows.add('• ${entry.path}');
      }
    }
    final depth = profile.globScanMaxDepth;
    if (depth != null) rows.add('glob_scan_max_depth → $depth');
    return rows;
  }

  /// Builds the network rows for one profile. An explicitly stored but
  /// empty table renders no rows, and the group falls back to "No entries."
  List<String> _networkRows(CodexNetworkPolicy? network) {
    if (network == null) return <String>[];
    final rows = <String>[];
    final enabled = network.enabled;
    if (enabled != null) rows.add('enabled → $enabled');
    final domains = network.domains;
    if (domains != null) {
      for (final domain in domains.entries) {
        rows.add('• ${domain.key} → ${domain.value}');
      }
    }
    final sockets = network.unixSockets;
    if (sockets != null) {
      for (final socket in sockets.entries) {
        rows.add('• ${socket.key} → ${socket.value}');
      }
    }
    final localBinding = network.allowLocalBinding;
    if (localBinding != null) {
      rows.add('allow_local_binding → $localBinding');
    }
    return rows;
  }

  /// Builds one stored profile section.
  Widget _buildProfile(BuildContext context, CodexPermissionProfile profile) {
    final children = <Widget>[
      _buildGroup(
        context: context,
        help: CodexPermissionsHelp.profile(profile.name),
        rows: [
          if (profile.description != null) profile.description!,
          if (profile.extendsProfile != null)
            'Extends: ${profile.extendsProfile}',
        ],
      ),
    ];
    final workspaceRoots = profile.workspaceRoots;
    if (workspaceRoots != null) {
      children.add(
        _buildGroup(
          context: context,
          help: const CodexPermissionFieldHelp(
            label: 'Workspace roots',
            description:
                'Profile-defined directories that count as workspace roots '
                'for this profile. Stored here; Codex applies them at runtime.',
          ),
          rows: [
            for (final root in workspaceRoots.entries)
              '• ${root.key} → ${root.value}',
          ],
        ),
      );
    }
    if (profile.filesystem != null) {
      children.add(
        _buildGroup(
          context: context,
          help: CodexPermissionsHelp.filesystem,
          rows: _filesystemRows(profile),
        ),
      );
    }
    if (profile.network != null) {
      children.add(
        _buildGroup(
          context: context,
          help: CodexPermissionsHelp.network,
          rows: _networkRows(profile.network),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
                  'Codex permissions',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.uiSubheader,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CodexPermissionsHelp.policy.description,
            style: AppTextStyles.uiSecondary,
          ),
          if (!presentation.hasConfiguredPermissions)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No permission settings stored in this file.',
                style: AppTextStyles.uiSecondary,
              ),
            ),
          if (presentation.sandboxMode != null ||
              presentation.approvalPolicy != null)
            _buildLegacy(context),
          if (presentation.defaultPermissions != null) _buildSelection(context),
          if (presentation.hasSandboxWorkspaceWriteTable)
            _buildGroup(
              context: context,
              help: CodexPermissionsHelp.legacyTable,
              rows: const [
                'A [sandbox_workspace_write] table is present but not shown.',
              ],
            ),
          ...presentation.profiles.map(
            (profile) => _buildProfile(context, profile),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await _openDocumentation(context);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Codex permissions documentation'),
          ),
        ],
      ),
    );
  }
}

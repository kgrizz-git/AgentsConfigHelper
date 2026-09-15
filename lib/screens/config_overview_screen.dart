import 'dart:io';

import 'package:agents_config_helper/catalog/platform_applicability.dart';
import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:agents_config_helper/reports/report_save_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/utils/open_directory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders an interactive overview of discovered and expected configuration
/// files.
class ConfigOverviewScreen extends ConsumerWidget {
  /// Creates the screen.
  const ConfigOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryAsync = ref.watch(discoveryControllerProvider);
    final homeDir = ref.read(homeDirectoryResolverProvider)();

    return discoveryAsync.when(
      data: (discovery) {
        final copilotHome = ref.read(copilotHomePathProvider);
        final entries = buildOverviewModel(
          discovery,
          ToolDescriptorRegistry.catalog,
          homePath: homeDir,
          projectRoots: discovery.projectRoots,
          copilotHome: copilotHome,
          platform: resolveHostConfigPlatform(),
        );
        if (homeDir == null && entries.isEmpty) {
          return Center(
            child: Text(
              'Error: cannot resolve home directory',
              style: AppTextStyles.uiBase.copyWith(color: AppColors.error),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionBar(context, ref, entries),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInteractiveOverview(entries),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildActionBar(
    BuildContext context,
    WidgetRef ref,
    List<ConfigOverviewEntry> entries,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDark)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Tooltip(
            message: 'Save report as a Markdown file',
            child: TextButton.icon(
              onPressed: () => _saveAndNotify(context, ref, entries, 'md'),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Export Markdown'),
            ),
          ),
          Tooltip(
            message: 'Save report as an HTML file',
            child: TextButton.icon(
              onPressed: () => _saveAndNotify(context, ref, entries, 'html'),
              icon: const Icon(Icons.code_outlined, size: 16),
              label: const Text('Export HTML'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveOverview(List<ConfigOverviewEntry> entries) {
    final groups = <Object?, List<ConfigOverviewEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.toolId, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configuration files', style: AppTextStyles.uiHeader),
        const SizedBox(height: 4),
        const Text(
          'Use the available actions to open, reveal, or copy each '
          'configuration path.',
          style: AppTextStyles.uiSecondary,
        ),
        const SizedBox(height: 16),
        ...groups.values.map(
          (groupEntries) => _ToolFileGroup(entries: groupEntries),
        ),
      ],
    );
  }

  Future<void> _saveAndNotify(
    BuildContext context,
    WidgetRef ref,
    List<ConfigOverviewEntry> entries,
    String format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saveService = ReportSaveService(
      saveFileDialog: ref.read(saveFileDialogProvider),
    );
    try {
      final ok = format == 'md'
          ? await saveService.saveMarkdown(entries)
          : await saveService.saveHtml(entries);
      if (!context.mounted) return;
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Report saved as $format.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on Exception catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ToolFileGroup extends StatelessWidget {
  const _ToolFileGroup({required this.entries});

  final List<ConfigOverviewEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entries.first.displayName, style: AppTextStyles.uiSubheader),
          const SizedBox(height: 8),
          ...entries.map((entry) => _FileRow(entry: entry)),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.entry});

  final ConfigOverviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final kindText = kindLabel(entry.kind);
    final formatText = formatLabel(entry.format);
    final scopeText = scopeLabel(entry.scope);
    final canOpen = entry.isPresent && entry.filePath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.borderDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _Badge(text: kindText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.displayPath,
              style: AppTextStyles.codeBase,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$formatText · $scopeText',
              style: AppTextStyles.uiSecondary,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.secretBearing) ...[
            const SizedBox(width: 8),
            const _Badge(
              text: 'secrets',
              tooltip: 'This configuration may contain secrets.',
              warning: true,
            ),
          ],
          if (entry.relevance != OverviewRelevance.present) ...[
            const SizedBox(width: 8),
            _relevanceBadge(entry),
          ],
          if (canOpen) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              tooltip: 'Open in editor',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final uri = Uri.file(entry.filePath!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
          if (canOpen) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.folder_open, size: 16),
              tooltip: 'Reveal in file manager',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final revealed = await revealFile(File(entry.filePath!));
                if (!revealed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not reveal the configuration file.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: entry.filePath == null
                ? 'Copy display path'
                : 'Copy absolute path',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final copiedPath = entry.filePath ?? entry.displayPath;
              await Clipboard.setData(
                ClipboardData(text: copiedPath),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: $copiedPath'),
                    backgroundColor: AppColors.surfaceDark,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

Widget _relevanceBadge(ConfigOverviewEntry entry) {
  switch (entry.relevance) {
    case OverviewRelevance.present:
      return const SizedBox.shrink();
    case OverviewRelevance.expectedMissing:
      return const _Badge(
        text: 'missing',
        tooltip: 'Expected configuration file not found on disk.',
      );
    case OverviewRelevance.optionalMissing:
      return const _Badge(
        text: 'optional',
        tooltip: 'Optional or alternate configuration file, not present.',
      );
    case OverviewRelevance.otherPlatform:
      return _Badge(
        text: 'other OS',
        tooltip: 'Applies to ${platformLabel(entry.platform)} only.',
      );
    case OverviewRelevance.notConfigured:
      return const _Badge(
        text: 'not configured',
        tooltip: 'No discovered configuration for this tool.',
      );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.tooltip, this.warning = false});

  final String text;
  final String? tooltip;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final bg = warning
        ? AppColors.warningBackgroundDark
        : AppColors.surfaceHighlightDark;
    final fg = warning ? AppColors.warning : AppColors.textSecondaryDark;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip, child: badge);
  }
}

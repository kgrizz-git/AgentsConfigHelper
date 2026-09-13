import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/reports/config_overview_builders.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:agents_config_helper/reports/report_save_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Renders the Markdown config overview report inline.
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
        );
        if (homeDir == null && entries.isEmpty) {
          return Center(
            child: Text(
              'Error: cannot resolve home directory',
              style: AppTextStyles.uiBase.copyWith(color: AppColors.error),
            ),
          );
        }
        final markdown = buildMarkdownReport(entries);
        final headingKeys = <String, GlobalKey>{
          for (final entry in entries)
            _headingFragment(
              entry.displayName,
            ): GlobalKey(
              debugLabel: _headingFragment(entry.displayName),
            ),
        };

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
                    MarkdownBody(
                      data: markdown,
                      styleSheet: MarkdownStyleSheet(
                        p: AppTextStyles.uiBase,
                        h1: AppTextStyles.uiHeader,
                        h2: AppTextStyles.uiSubheader,
                        a: const TextStyle(color: AppColors.primaryAccent),
                        blockquote: AppTextStyles.uiSecondary,
                        code: AppTextStyles.codeBase,
                      ),
                      builders: <String, MarkdownElementBuilder>{
                        'h2': _OverviewHeadingBuilder(headingKeys),
                      },
                      onTapLink: (text, href, title) async {
                        if (href == null) return;
                        if (href.startsWith('#')) {
                          final targetContext =
                              headingKeys[href.substring(1)]?.currentContext;
                          if (targetContext != null) {
                            await Scrollable.ensureVisible(
                              targetContext,
                              duration: const Duration(milliseconds: 200),
                            );
                          }
                          return;
                        }
                        final target = Uri.tryParse(href);
                        if (target == null) return;
                        if (await canLaunchUrl(target)) {
                          await launchUrl(target);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    if (entries.isNotEmpty) _buildFileList(context, entries),
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
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _saveAndNotify(context, ref, entries, 'md'),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Save .md'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _saveAndNotify(context, ref, entries, 'html'),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Save .html'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(
    BuildContext context,
    List<ConfigOverviewEntry> entries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Files', style: AppTextStyles.uiSubheader),
        const SizedBox(height: 8),
        ...entries.map((entry) => _FileRow(entry: entry)),
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

String _headingFragment(String text) {
  return text
      .toLowerCase()
      .replaceAll(' ', '-')
      .replaceAll(RegExp('[^a-z0-9-]'), '');
}

class _OverviewHeadingBuilder extends MarkdownElementBuilder {
  _OverviewHeadingBuilder(this._headingKeys);

  final Map<String, GlobalKey> _headingKeys;

  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) {
    final headingText = text.text;
    final fragment = _headingFragment(headingText);
    final key = _headingKeys[fragment];
    if (key == null) return Text(headingText, style: preferredStyle);
    return KeyedSubtree(
      key: key,
      child: KeyedSubtree(
        key: ValueKey(fragment),
        child: Text(headingText, style: preferredStyle),
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
    final canOpen = entry.filePath != null && !entry.missing;

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
            const _Badge(text: 'secrets', warning: true),
          ],
          if (entry.missing) ...[
            const SizedBox(width: 8),
            const _Badge(text: 'missing'),
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
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy path',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: entry.filePath ?? entry.displayPath),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${entry.displayPath}'),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final bg = warning
        ? AppColors.warningBackgroundDark
        : AppColors.surfaceHighlightDark;
    final fg = warning ? AppColors.warning : AppColors.textSecondaryDark;
    return Container(
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
  }
}

import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/schemas/policy_card_registry.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:agents_config_helper/utils/open_directory.dart';
import 'package:agents_config_helper/widgets/formatting_fidelity_notice.dart';
import 'package:agents_config_helper/widgets/policy_card_widget_registry.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:agents_config_helper/widgets/structured_save_flow.dart';
import 'package:agents_config_helper/widgets/toml_opt_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Edits the supported flat configuration fields and confirms saves.
class ConfigEditor extends StatefulWidget {
  /// Creates an editor with callbacks supplied by its owner.
  const ConfigEditor({
    required this.config,
    required this.onSave,
    required this.resolvePath,
    required this.onShowHistory,
    this.discoveredConfig,
    this.onDirtyChanged,
    this.hasUsableBaseline,
    this.rawContentParsedAsJsonc,
    this.currentSourceParsedAsJsonc,
    this.allowOpenDirectory = true,
    this.rawOnly = false,
    this.tomlStructuredSaveEnabled = false,
    this.onEnableTomlStructuredSave,
    this.onDisableTomlStructuredSave,
    this.registry,
    this.widgetRegistry,
    super.key,
  });

  /// The configuration shown by the editor.
  final ToolConfig config;

  /// The known discovery record, used to select a schema-aware presentation.
  final DiscoveredConfig? discoveredConfig;

  /// Persists a confirmed edited configuration.
  final Future<ToolConfig> Function(
    ToolConfig config, {
    String? rawContent,
    bool? allowRewrite,
  })
  onSave;

  /// Resolves the configuration path before opening its directory.
  final String Function(String path) resolvePath;

  /// Notifies the owner when editor changes become dirty or clean.
  final ValueChanged<bool>? onDirtyChanged;

  /// Reports whether `config.originalContent` is a parser-usable baseline for
  /// raw-plus-structured merge saves. Without this callback, the editor does
  /// not claim the review save will use parser serialization.
  final bool Function(ToolConfig config)? hasUsableBaseline;

  /// Reports whether the current raw JSON buffer needs JSONC parsing, so a
  /// pending merge disclosure reflects the content that will be serialized.
  final bool Function(ToolConfig config, String rawContent)?
  rawContentParsedAsJsonc;

  /// Reports whether the current on-disk JSON source needs JSONC parsing, so
  /// a structured-save disclosure reflects the source `saveConfig` will use.
  final Future<bool> Function(ToolConfig config)? currentSourceParsedAsJsonc;

  /// Triggered when the user requests to view the history and backups.
  final VoidCallback onShowHistory;

  /// Whether the editor may invoke the platform file manager for its parent
  /// directory.
  final bool allowOpenDirectory;

  /// When true, renders the file as a raw-text-only editor: structured
  /// sections and the history button are hidden. Used for corrupt files that
  /// cannot be parsed into structured fields.
  final bool rawOnly;

  /// Whether the user has opted in to structured TOML saves. When false,
  /// TOML structured controls are disabled and the editor surfaces an
  /// explanation with an explicit opt-in affordance.
  final bool tomlStructuredSaveEnabled;

  /// Called when the user accepts the TOML opt-in warning and enables
  /// structured saves for TOML files.
  final Future<void> Function()? onEnableTomlStructuredSave;

  /// Called when the user opts back out of structured saves for TOML files.
  final Future<void> Function()? onDisableTomlStructuredSave;

  /// Policy-card selection registry. Defaults to [PolicyCardRegistry.shared].
  final PolicyCardRegistry? registry;

  /// Widget mapping registry. Defaults to [PolicyCardWidgetRegistry.shared].
  final PolicyCardWidgetRegistry? widgetRegistry;

  @override
  State<ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<ConfigEditor> {
  static const _fidelityAssessor = FidelityAssessor();

  late ToolConfig _currentConfig;
  late List<String> _rules;
  late List<String> _permissions;
  late TextEditingController _rawContentController;
  late String _rawContent;
  bool _saving = false;
  int _editRevision = 0;
  late final PolicyCardRegistry _registry;
  late final PolicyCardWidgetRegistry _widgetRegistry;

  @override
  void initState() {
    super.initState();
    _registry = widget.registry ?? PolicyCardRegistry.shared;
    _widgetRegistry = widget.widgetRegistry ?? PolicyCardWidgetRegistry.shared;
    _rawContentController = TextEditingController();
    _initLocalState(widget.config);
  }

  @override
  void dispose() {
    _rawContentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _initLocalState(widget.config);
    }
  }

  void _initLocalState(ToolConfig config) {
    _editRevision++;
    _currentConfig = config;
    _rules = List.from(_currentConfig.rules);
    _permissions = List.from(_currentConfig.permissions);
    _rawContent = _currentConfig.originalContent;
    if (_rawContentController.text != _rawContent) {
      _rawContentController.text = _rawContent;
    }
  }

  void _notifyDirtyChanged() {
    widget.onDirtyChanged?.call(_hasUnsavedChanges);
  }

  bool get _hasUnsavedChanges {
    return !listEquals(_rules, _currentConfig.rules) ||
        !listEquals(_permissions, _currentConfig.permissions) ||
        _rawContent != _currentConfig.originalContent;
  }

  bool get _supportsStructuredFields {
    final format = _currentConfig.format;
    if (format == ConfigFormat.toml) {
      return widget.tomlStructuredSaveEnabled;
    }
    return format == ConfigFormat.json ||
        format == ConfigFormat.jsonc ||
        format == ConfigFormat.yaml;
  }

  VoidCallback _toSetState(Future<void> Function()? action) => () async {
    await action?.call();
    if (mounted) setState(() {});
  };

  FidelityAssessment? get _openingFidelityAssessment =>
      _fidelityAssessor.assessOpening(
        format: _currentConfig.format,
        filePath: _currentConfig.filePath,
        rawOnly: widget.rawOnly,
        parsedAsJsonc: _currentConfig.parsedAsJsonc,
        tomlStructuredSaveEnabled: widget.tomlStructuredSaveEnabled,
      );

  Future<FidelityAssessment?> _pendingFidelityAssessment() async {
    final rawChanged = _rawContent != _currentConfig.originalContent;
    final structuredDiverged =
        !listEquals(_rules, _currentConfig.rules) ||
        !listEquals(_permissions, _currentConfig.permissions);
    final saveKind = rawChanged
        ? (structuredDiverged
              ? SaveKind.saveRawStructuredMerge
              : SaveKind.saveRawDirect)
        : SaveKind.saveConfig;
    final parsedAsJsonc = rawChanged
        ? (widget.rawContentParsedAsJsonc?.call(
                _currentConfig,
                _rawContent,
              ) ??
              _currentConfig.parsedAsJsonc)
        : (await widget.currentSourceParsedAsJsonc?.call(_currentConfig) ??
              _currentConfig.parsedAsJsonc);

    return _fidelityAssessor.assessPendingSave(
      format: _currentConfig.format,
      filePath: _currentConfig.filePath,
      rawOnly: widget.rawOnly,
      saveKind: saveKind,
      hasUsableBaseline:
          widget.hasUsableBaseline?.call(_currentConfig) ?? false,
      structuredDiverged: structuredDiverged,
      parsedAsJsonc: parsedAsJsonc,
      tomlStructuredSaveEnabled: widget.tomlStructuredSaveEnabled,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.uiSubheader.copyWith(
          color: AppColors.primaryAccent,
        ),
      ),
    );
  }

  /// Builds the Rules section: the string-list editor for list/absent raw
  /// `rules`, or a nested notice for map/scalar shapes that preservation
  /// round-trips instead of editing.
  List<Widget> _buildRulesSection() {
    final header = _buildSectionHeader('Rules');
    final rawRules = _currentConfig.rawSettings['rules'];
    if (rawRules != null && rawRules is! List) {
      return [
        header,
        const Text(
          'Nested rules are preserved but not editable here yet.',
          style: AppTextStyles.uiSecondary,
        ),
      ];
    }
    return [
      header,
      const Text(
        'Define custom rules for this agent.',
        style: AppTextStyles.uiSecondary,
      ),
      const SizedBox(height: 12),
      StringListEditor(
        values: _rules,
        hintText: 'e.g., Always use type hints...',
        onChanged: (newValues) {
          setState(() {
            _rules = newValues;
            _editRevision++;
          });
          _notifyDirtyChanged();
        },
      ),
    ];
  }

  Widget _buildPermissionsSection(
    PolicyCardSelection selection,
    bool hasNestedUnsupportedPermissions,
    Widget? card,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Permissions'),
        if (card != null)
          card
        else if (!selection.isAvailable &&
            (selection.isUnsupported || hasNestedUnsupportedPermissions))
          Text(
            selection.unsupportedReason ??
                'Nested permissions are preserved but not editable here yet.',
            style: AppTextStyles.uiSecondary,
          )
        else ...[
          const Text(
            'Allowed directories or commands for this agent.',
            style: AppTextStyles.uiSecondary,
          ),
          const SizedBox(height: 12),
          StringListEditor(
            values: _permissions,
            hintText: 'e.g., ~/Projects',
            onChanged: (newValues) {
              setState(() {
                _permissions = newValues;
                _editRevision++;
              });
              _notifyDirtyChanged();
            },
          ),
        ],
      ],
    );
  }

  Future<void> _saveChanges() {
    setState(() => _saving = true);
    return StructuredSaveFlow.run(
      context: context,
      isMounted: () => mounted,
      rawContent: () =>
          _rawContent != _currentConfig.originalContent ? _rawContent : null,
      buildUpdatedConfig: () => _currentConfig.copyWith(
        rules: _rules,
        permissions: _permissions,
      ),
      onSave: widget.onSave,
      onSuccess: (savedConfig) {
        setState(() {
          _currentConfig = savedConfig;
          _initLocalState(_currentConfig);
        });
        _notifyDirtyChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      },
      setSavingFalse: () {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
      },
    );
  }

  Future<void> _showDiffModal() {
    final editRevision = _editRevision;
    return StructuredSaveFlow.showDiffModal(
      context: context,
      isMounted: () => mounted,
      isCurrentRevision: () => _editRevision == editRevision,
      pendingFidelityAssessment: _pendingFidelityAssessment,
      supportsStructuredFields: _supportsStructuredFields,
      rawOnly: widget.rawOnly,
      currentRules: _currentConfig.rules,
      currentPermissions: _currentConfig.permissions,
      rules: _rules,
      permissions: _permissions,
      originalContent: _currentConfig.originalContent,
      rawContent: _rawContent,
      buildDiffSection: StructuredSaveFlow.buildDiffSection,
      buildRawDiffSection: StructuredSaveFlow.buildRawDiffSection,
      saving: _saving,
      onSaveChanges: _saveChanges,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = _registry.select(
      config: _currentConfig,
      discoveredConfig: widget.discoveredConfig,
    );
    final openingFidelityAssessment = _openingFidelityAssessment;
    final hasNestedUnsupportedPermissions =
        _currentConfig.rawSettings['permissions'] != null &&
        _currentConfig.rawSettings['permissions'] is! List &&
        _currentConfig.rawSettings.containsKey('permissions');
    final card = _widgetRegistry.buildCard(selection);
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.config.toolName,
                        style: AppTextStyles.uiHeader,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (!widget.rawOnly)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('History & Backups'),
                        onPressed: widget.onShowHistory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimaryDark,
                          side: const BorderSide(
                            color: AppColors.borderDark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.folder_open,
                      color: AppColors.textSecondaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${p.dirname(widget.config.filePath)}/',
                              style: AppTextStyles.uiSecondary,
                            ),
                            TextSpan(
                              text: p.basename(widget.config.filePath),
                              style: AppTextStyles.uiSecondary.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      color: AppColors.primaryAccent,
                      tooltip: 'Open Directory',
                      onPressed: widget.allowOpenDirectory
                          ? () async {
                              final dir = Directory(
                                p.dirname(
                                  widget.resolvePath(widget.config.filePath),
                                ),
                              );
                              final opened = await openDirectory(dir);
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open the config directory.',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),

                if (openingFidelityAssessment != null) ...[
                  const SizedBox(height: 16),
                  FormattingFidelityNotice(
                    assessment: openingFidelityAssessment,
                  ),
                ],

                if (_currentConfig.parseWarnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final warning in _currentConfig.parseWarnings) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.warning),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: AppTextStyles.uiSecondary.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                TomlOptWidgets(
                  isTomlStructured:
                      _currentConfig.format == ConfigFormat.toml &&
                      !widget.rawOnly,
                  enabled: widget.tomlStructuredSaveEnabled,
                  onEnable: _toSetState(widget.onEnableTomlStructuredSave),
                  onDisable: _toSetState(widget.onDisableTomlStructuredSave),
                ),

                // Form Body
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: Opacity(
                      opacity: _saving ? 0.6 : 1,
                      child: ListView(
                        padding: const EdgeInsets.only(
                          bottom: 80,
                        ), // padding for floating bar
                        children: [
                          if (_supportsStructuredFields && !widget.rawOnly) ...[
                            ..._buildRulesSection(),
                          ],
                          if (!widget.rawOnly &&
                              (_supportsStructuredFields || card != null)) ...[
                            _buildPermissionsSection(
                              selection,
                              hasNestedUnsupportedPermissions,
                              card,
                            ),
                          ],

                          _buildSectionHeader('Advanced'),
                          const Text(
                            'Raw configuration overrides.',
                            style: AppTextStyles.uiSecondary,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.sidebarDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderDark),
                            ),
                            child: TextField(
                              controller: _rawContentController,
                              maxLines: null,
                              style: AppTextStyles.codeBase,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Raw configuration content',
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rawContent = val;
                                  _editRevision++;
                                });
                                _notifyDirtyChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Save Flow Floating Bar
          if (_hasUnsavedChanges)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.sidebarDark,
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _initLocalState(_currentConfig);
                              });
                              _notifyDirtyChanged();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimaryDark,
                      ),
                      child: const Text('Discard Changes'),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _saving ? null : _showDiffModal,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryAccent,
                      ),
                      child: const Text('Review Changes'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _showDiffModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

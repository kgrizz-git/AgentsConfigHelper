import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:equatable/equatable.dart';

/// The outcome of interpreting a Claude Code permissions object for display.
enum ClaudeCodePermissionsStatus {
  /// The selected configuration is not a catalog-discovered Claude settings
  /// file.
  notApplicable,

  /// The complete supported subtree can be displayed safely.
  available,

  /// A Claude permissions field exists but is not a supported display shape.
  unsupported,
}

/// A read-only, validated view of Claude Code permission settings.
class ClaudeCodePermissionsPresentation extends Equatable {
  /// Creates a presentation from the recognized Claude permissions subtree.
  ClaudeCodePermissionsPresentation({
    required this.defaultMode,
    required List<String> allow,
    required List<String> ask,
    required List<String> deny,
    required this.hasConfiguredPolicy,
    required this.hasUnclassifiedSettings,
  }) : allow = List.unmodifiable(allow),
       ask = List.unmodifiable(ask),
       deny = List.unmodifiable(deny);

  /// The declared default mode, when present.
  final String? defaultMode;

  /// Rules that Claude Code may allow without prompting.
  final List<String> allow;

  /// Rules for which Claude Code asks before proceeding.
  final List<String> ask;

  /// Rules that Claude Code denies.
  final List<String> deny;

  /// Whether the settings file contains a `permissions` policy object.
  final bool hasConfiguredPolicy;

  /// Whether unrecognized sibling settings remain available only as raw
  /// content.
  final bool hasUnclassifiedSettings;

  @override
  List<Object?> get props => [
    defaultMode,
    allow,
    ask,
    deny,
    hasConfiguredPolicy,
    hasUnclassifiedSettings,
  ];
}

/// Result of interpreting a configuration as Claude Code permissions.
class ClaudeCodePermissionsInterpretation extends Equatable {
  /// Creates an interpretation with an optional display [presentation].
  const ClaudeCodePermissionsInterpretation({
    required this.status,
    this.presentation,
    this.unsupportedReason,
  });

  /// Whether the source can be displayed, cannot be displayed, or is
  /// unrelated.
  final ClaudeCodePermissionsStatus status;

  /// The presentation to render when [status] is available.
  final ClaudeCodePermissionsPresentation? presentation;

  /// A concise reason to show when the Claude subtree is unsupported.
  final String? unsupportedReason;

  /// Whether a card is safe to show.
  bool get isAvailable => status == ClaudeCodePermissionsStatus.available;

  /// Whether the source is Claude but cannot be represented by this card.
  bool get isUnsupported => status == ClaudeCodePermissionsStatus.unsupported;

  @override
  List<Object?> get props => [status, presentation, unsupportedReason];
}

/// Interprets the known Claude Code permissions subtree without mutating it.
class ClaudeCodePermissionsAdapter {
  /// The primary documentation for the displayed Claude Code permission policy.
  static final Uri documentationUri = Uri.parse(
    'https://code.claude.com/docs/en/permissions',
  );

  static const _recognizedKeys = {
    'defaultMode',
    'allow',
    'ask',
    'deny',
  };

  /// Returns a read-only presentation only for known Claude settings targets.
  ClaudeCodePermissionsInterpretation interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isClaudeSettingsTarget(config, discoveredConfig)) {
      return const ClaudeCodePermissionsInterpretation(
        status: ClaudeCodePermissionsStatus.notApplicable,
      );
    }

    if (!config.rawSettings.containsKey('permissions')) {
      return ClaudeCodePermissionsInterpretation(
        status: ClaudeCodePermissionsStatus.available,
        presentation: ClaudeCodePermissionsPresentation(
          defaultMode: null,
          allow: const [],
          ask: const [],
          deny: const [],
          hasConfiguredPolicy: false,
          hasUnclassifiedSettings: false,
        ),
      );
    }

    final rawPermissions = config.rawSettings['permissions'];
    if (rawPermissions is! Map) {
      return const ClaudeCodePermissionsInterpretation(
        status: ClaudeCodePermissionsStatus.unsupported,
        unsupportedReason:
            'This Claude Code permissions shape is not supported for '
            'structured display. '
            'Use the raw editor to review it.',
      );
    }

    final permissions = <String, Object?>{};
    for (final entry in rawPermissions.entries) {
      if (entry.key is! String) {
        return const ClaudeCodePermissionsInterpretation(
          status: ClaudeCodePermissionsStatus.unsupported,
          unsupportedReason:
              'This Claude Code permissions shape is not supported for '
              'structured display. '
              'Use the raw editor to review it.',
        );
      }
      permissions[entry.key as String] = entry.value;
    }

    final defaultMode = permissions['defaultMode'];
    if (defaultMode != null && defaultMode is! String) {
      return _unsupportedField('defaultMode');
    }

    final allow = _stringArray(permissions, 'allow');
    if (allow == null) return _unsupportedField('allow');
    final ask = _stringArray(permissions, 'ask');
    if (ask == null) return _unsupportedField('ask');
    final deny = _stringArray(permissions, 'deny');
    if (deny == null) return _unsupportedField('deny');

    final hasUnclassifiedSettings = permissions.keys.any(
      (key) => !_recognizedKeys.contains(key),
    );
    return ClaudeCodePermissionsInterpretation(
      status: ClaudeCodePermissionsStatus.available,
      presentation: ClaudeCodePermissionsPresentation(
        defaultMode: defaultMode as String?,
        allow: allow,
        ask: ask,
        deny: deny,
        hasConfiguredPolicy: true,
        hasUnclassifiedSettings: hasUnclassifiedSettings,
      ),
    );
  }

  bool _isClaudeSettingsTarget(
    ToolConfig config,
    DiscoveredConfig? discoveredConfig,
  ) {
    if (discoveredConfig == null ||
        !discoveredConfig.fromCatalog ||
        discoveredConfig.descriptor?.id != ToolId.claudeCode ||
        discoveredConfig.kind != ConfigSourceKind.structuredConfig ||
        discoveredConfig.format != ConfigFormat.json ||
        config.format != ConfigFormat.json) {
      return false;
    }

    return discoveredConfig.scope == ConfigLocationScope.user ||
        discoveredConfig.scope == ConfigLocationScope.project;
  }

  List<String>? _stringArray(Map<String, Object?> permissions, String key) {
    if (!permissions.containsKey(key)) return const [];
    final value = permissions[key];
    if (value is! List || value.any((entry) => entry is! String)) return null;
    return List.unmodifiable(value.cast<String>());
  }

  ClaudeCodePermissionsInterpretation _unsupportedField(String field) {
    return ClaudeCodePermissionsInterpretation(
      status: ClaudeCodePermissionsStatus.unsupported,
      unsupportedReason:
          'Claude Code permission "$field" is not a supported value. '
          'Use the raw editor to review it.',
    );
  }
}

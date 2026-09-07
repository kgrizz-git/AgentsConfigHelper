import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:equatable/equatable.dart';

/// Reviewed, plain-language help for the fields shown on the Claude card.
class ClaudeCodePermissionFieldHelp extends Equatable {
  /// Creates help for one displayed Claude Code permissions field.
  const ClaudeCodePermissionFieldHelp({
    required this.label,
    required this.description,
  });

  final String label;

  /// A description of the stored setting, not a prediction of rule matching.
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Reviewed help metadata for the currently supported Claude permission fields.
class ClaudeCodePermissionsHelp {
  /// Explains the card's intentionally read-only scope.
  static const policy = ClaudeCodePermissionFieldHelp(
    label: 'Claude Code permissions',
    description:
        'This card shows the permission settings stored in this file. '
        'Claude Code decides how individual actions match those settings '
        'at runtime.',
  );

  /// Explains the fallback behavior for actions without a matching rule.
  static const defaultMode = ClaudeCodePermissionFieldHelp(
    label: 'Default mode',
    description:
        'Sets how Claude Code handles an action when no allow, ask, or deny '
        'rule matches it.',
  );

  /// Explains rules that pre-approve matching actions.
  static const allow = ClaudeCodePermissionFieldHelp(
    label: 'Allow',
    description: 'Lists rules that pre-approve matching actions.',
  );

  /// Explains rules that require confirmation before matching actions proceed.
  static const ask = ClaudeCodePermissionFieldHelp(
    label: 'Ask',
    description: 'Lists rules that require confirmation for matching actions.',
  );

  /// Explains rules that block matching actions.
  static const deny = ClaudeCodePermissionFieldHelp(
    label: 'Deny',
    description: 'Lists rules that block matching actions.',
  );
}

/// A read-only, validated view of Claude Code permission settings.
class ClaudeCodePermissionsPresentation extends PolicyCardPresentation {
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

/// Interprets the known Claude Code permissions subtree without mutating it.
class ClaudeCodePermissionsAdapter implements PolicyCardAdapter {
  /// Stable key used by the widget registry. Named `adapterId` (not `id`)
  /// because Dart forbids a static member and an instance member sharing one
  /// name; the instance getter below forwards to it for the interface.
  static const adapterId = 'claudeCode.permissions';

  @override
  String get id => adapterId;

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

  static const _supportedDefaultModes = {
    'default',
    'manual',
    'acceptEdits',
    'plan',
    'auto',
    'dontAsk',
    'bypassPermissions',
  };

  /// Returns a read-only presentation only for known Claude settings targets.
  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isClaudeSettingsTarget(config, discoveredConfig)) {
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.notApplicable,
      );
    }

    if (!config.rawSettings.containsKey('permissions')) {
      return PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.available,
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
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.unsupported,
        unsupportedReason:
            'This Claude Code permissions shape is not supported for '
            'structured display. '
            'Use the raw editor to review it.',
      );
    }

    final permissions = <String, Object?>{};
    for (final entry in rawPermissions.entries) {
      if (entry.key is! String) {
        return const PolicyCardSelection(
          adapterId: adapterId,
          status: PolicyCardStatus.unsupported,
          unsupportedReason:
              'This Claude Code permissions shape is not supported for '
              'structured display. '
              'Use the raw editor to review it.',
        );
      }
      permissions[entry.key as String] = entry.value;
    }

    final defaultMode = permissions['defaultMode'];
    if (permissions.containsKey('defaultMode')) {
      if (defaultMode is! String ||
          !_supportedDefaultModes.contains(defaultMode)) {
        return _unsupportedField('defaultMode');
      }
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
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
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

  PolicyCardSelection _unsupportedField(String field) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason:
          'Claude Code permission "$field" is not a supported value. '
          'Use the raw editor to review it.',
    );
  }
}

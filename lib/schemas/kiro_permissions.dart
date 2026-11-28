import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// Reviewed, plain-language help for one displayed Kiro permission field.
class KiroPermissionFieldHelp extends Equatable {
  /// Creates help for one displayed Kiro permission field.
  const new({
    required this.label,
    required this.description,
  });

  /// The human-readable field label.
  final String label;

  /// A description of the stored setting, not a prediction of Kiro's decision.
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Reviewed help metadata for Kiro's stored permission rules.
class KiroPermissionsHelp {
  /// Explains the card's intentionally read-only scope.
  static const policy = KiroPermissionFieldHelp(
    label: 'Kiro permissions',
    description:
        'This card shows the capability rules stored in this Kiro '
        'permissions.yaml file. Kiro combines them with defaults, built-in '
        'trust rules, policy presets, and other scopes at runtime; this card '
        'does not compute the effective policy.',
  );

  /// Explains the read-only boundary of this card.
  static const readOnly = KiroPermissionFieldHelp(
    label: 'Read-only view',
    description:
        'This is a read-only view of the stored rules. Use the raw editor to '
        'change the file.',
  );

  /// Explains that a rule is stored configuration, not a runtime decision.
  static const rule = KiroPermissionFieldHelp(
    label: 'Stored rule',
    description:
        "This is a stored rule, not Kiro's effective decision. Kiro evaluates "
        'it with other rules at runtime.',
  );

  /// Explains the optional match patterns.
  static const match = KiroPermissionFieldHelp(
    label: 'Match',
    description:
        'Stored glob patterns that scope this rule. Kiro applies the pattern '
        'semantics at runtime.',
  );

  /// Explains the optional exclude patterns.
  static const exclude = KiroPermissionFieldHelp(
    label: 'Exclude',
    description:
        'Stored glob patterns that must not match. Kiro applies the exclude '
        'semantics at runtime.',
  );

  static const _capabilities = {
    'fs_read': KiroPermissionFieldHelp(
      label: 'Filesystem read',
      description: 'Stored rules for reading files and directories.',
    ),
    'fs_write': KiroPermissionFieldHelp(
      label: 'Filesystem write',
      description: 'Stored rules for writing files and directories.',
    ),
    'shell': KiroPermissionFieldHelp(
      label: 'Shell',
      description: 'Stored rules for shell command patterns.',
    ),
    'web_fetch': KiroPermissionFieldHelp(
      label: 'Web fetch',
      description: 'Stored rules for fetching web content.',
    ),
    'web_search': KiroPermissionFieldHelp(
      label: 'Web search',
      description: 'Stored rules for web searches.',
    ),
    'mcp': KiroPermissionFieldHelp(
      label: 'MCP',
      description: 'Stored rules for MCP server and tool patterns.',
    ),
    'subagent': KiroPermissionFieldHelp(
      label: 'Subagent',
      description: 'Stored rules for starting sub-agents.',
    ),
    'skill': KiroPermissionFieldHelp(
      label: 'Skill',
      description: 'Stored rules for Agent Skills.',
    ),
    'power': KiroPermissionFieldHelp(
      label: 'Power',
      description: 'Stored rules for Powers.',
    ),
    'context': KiroPermissionFieldHelp(
      label: 'Context',
      description: 'Stored rules for context access.',
    ),
    'diagnostics': KiroPermissionFieldHelp(
      label: 'Diagnostics',
      description: 'Stored rules for diagnostics tools.',
    ),
    'sandbox_network': KiroPermissionFieldHelp(
      label: 'Sandbox network',
      description:
          "Stored host rules for Kiro's local command sandbox. This "
          'capability is not part of the all meta-capability.',
    ),
    'all': KiroPermissionFieldHelp(
      label: 'All capabilities',
      description:
          'A Kiro meta-capability covering every capability except '
          'sandbox_network.',
    ),
    'builtin': KiroPermissionFieldHelp(
      label: 'Built-in tools',
      description: 'A Kiro meta-capability covering built-in tools.',
    ),
    'filesystem': KiroPermissionFieldHelp(
      label: 'Filesystem',
      description: 'A Kiro meta-capability covering filesystem read and write.',
    ),
  };

  static const _effects = {
    'deny': KiroPermissionFieldHelp(
      label: 'Deny',
      description: 'Blocks matching actions. Deny outranks every other effect.',
    ),
    'ask': KiroPermissionFieldHelp(
      label: 'Ask',
      description: 'Prompts before matching actions run.',
    ),
    'allow': KiroPermissionFieldHelp(
      label: 'Allow',
      description: 'Allows matching actions without prompting.',
    ),
    'evaluate': KiroPermissionFieldHelp(
      label: 'Evaluate',
      description:
          "Asks Kiro's trust classifier to judge matching actions. Evaluate "
          'is the weakest effect and requires the classifier.',
    ),
  };

  /// Returns reviewed help for [capability].
  static KiroPermissionFieldHelp capability(String capability) {
    return _capabilities[capability] ??
        KiroPermissionFieldHelp(
          label: capability,
          description:
              'A stored capability rule. Kiro applies its own semantics at '
              'runtime.',
        );
  }

  /// Returns reviewed help for [effect].
  static KiroPermissionFieldHelp effect(String effect) {
    return _effects[effect] ??
        KiroPermissionFieldHelp(
          label: effect,
          description:
              'A stored effect. Kiro applies its own semantics at runtime.',
        );
  }
}

/// One stored Kiro permission rule.
///
/// A null [match] or [exclude] means the key was omitted; a non-null empty
/// list means the user wrote an empty list. The card preserves that
/// distinction.
class KiroPermissionRule extends Equatable {
  /// Creates a stored rule from an already validated Kiro rule map.
  new({
    required this.capability,
    required this.effect,
    List<String>? match,
    List<String>? exclude,
  }) : match = _unmodifiable(match),
       exclude = _unmodifiable(exclude);

  /// The documented Kiro capability value.
  final String capability;

  /// The documented Kiro effect value.
  final String effect;

  /// Optional stored match patterns, or null when the key was omitted.
  final List<String>? match;

  /// Optional stored exclude patterns, or null when the key was omitted.
  final List<String>? exclude;

  @override
  List<Object?> get props => [capability, effect, match, exclude];

  static List<String>? _unmodifiable(List<String>? values) {
    return values == null ? null : List.unmodifiable(values);
  }
}

/// A read-only, validated view of a Kiro permissions file.
class KiroPermissionsPresentation extends PolicyCardPresentation {
  /// Creates a presentation from validated Kiro rules in file order.
  new({
    required List<KiroPermissionRule> rules,
    required this.hasUnclassifiedSettings,
  }) : rules = List.unmodifiable(rules);

  /// The stored rules, in file order.
  final List<KiroPermissionRule> rules;

  /// Whether top-level keys other than `rules` remain available only as raw
  /// content.
  final bool hasUnclassifiedSettings;

  @override
  List<Object?> get props => [rules, hasUnclassifiedSettings];
}

/// Interprets Kiro's stored capability rules without mutating the config.
class KiroPermissionsAdapter implements PolicyCardAdapter {
  /// Stable key used by the widget registry.
  static const adapterId = 'kiro.permissions';

  @override
  String get id => adapterId;

  /// The primary documentation for the displayed Kiro permission rules.
  static final Uri documentationUri = Uri.parse(
    'https://kiro.dev/docs/permissions/',
  );

  static const _capabilityValues = {
    'fs_read',
    'fs_write',
    'shell',
    'web_fetch',
    'web_search',
    'mcp',
    'subagent',
    'skill',
    'power',
    'context',
    'diagnostics',
    'sandbox_network',
    'all',
    'builtin',
    'filesystem',
  };

  static const _effectValues = {'deny', 'ask', 'allow', 'evaluate'};

  static const _ruleKeys = {'capability', 'effect', 'match', 'exclude'};

  /// Returns a read-only presentation only for the catalog-discovered Kiro
  /// user permissions file.
  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isKiroPermissionsTarget(config, discoveredConfig)) {
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.notApplicable,
      );
    }

    final raw = config.rawSettings;
    final rulesValue = raw['rules'];
    if (!raw.containsKey('rules') ||
        (rulesValue is List && rulesValue.isEmpty)) {
      return _available(const [], hasUnclassifiedSettings: _hasOtherKeys(raw));
    }

    if (rulesValue == null) {
      return _unsupported(
        'Kiro permission "rules" is null. Use the raw editor to review it.',
      );
    }
    if (rulesValue is! List) {
      return _unsupported(
        'Kiro permission "rules" is not a list. Use the raw editor to review '
        'it.',
      );
    }

    final rules = <KiroPermissionRule>[];
    for (var index = 0; index < rulesValue.length; index++) {
      final entry = rulesValue[index];
      if (entry is! Map) {
        return _unsupportedRule(index, 'the entry is not a map');
      }

      final rule = <String, Object?>{};
      for (final mapEntry in entry.entries) {
        if (mapEntry.key is! String) {
          return _unsupportedRule(index, 'a key is not a string');
        }
        rule[mapEntry.key as String] = mapEntry.value;
      }

      String? unknownKey;
      for (final key in rule.keys) {
        if (!_ruleKeys.contains(key)) {
          unknownKey = key;
          break;
        }
      }
      if (unknownKey != null) {
        return _unsupportedRule(index, 'unknown key "$unknownKey"');
      }

      final capability = rule['capability'];
      if (capability is! String || !_capabilityValues.contains(capability)) {
        return _unsupportedRule(index, 'capability is missing or unknown');
      }

      final effect = rule['effect'];
      if (effect is! String || !_effectValues.contains(effect)) {
        return _unsupportedRule(index, 'effect is missing or unknown');
      }

      final match = _patternList(rule, 'match');
      if (match.error != null) {
        return _unsupportedRule(index, match.error!);
      }
      final exclude = _patternList(rule, 'exclude');
      if (exclude.error != null) {
        return _unsupportedRule(index, exclude.error!);
      }

      rules.add(
        KiroPermissionRule(
          capability: capability,
          effect: effect,
          match: match.values,
          exclude: exclude.values,
        ),
      );
    }

    return _available(
      rules,
      hasUnclassifiedSettings: _hasOtherKeys(raw),
    );
  }

  bool _isKiroPermissionsTarget(
    ToolConfig config,
    DiscoveredConfig? discoveredConfig,
  ) {
    if (discoveredConfig == null ||
        !discoveredConfig.fromCatalog ||
        discoveredConfig.descriptor?.id != ToolId.kiro ||
        discoveredConfig.kind != ConfigSourceKind.structuredConfig ||
        discoveredConfig.format != ConfigFormat.yaml ||
        config.format != ConfigFormat.yaml ||
        discoveredConfig.scope != ConfigLocationScope.user) {
      return false;
    }

    final components = p.split(p.normalize(discoveredConfig.filePath));
    if (components.length < 3) return false;
    return components[components.length - 3] == '.kiro' &&
        components[components.length - 2] == 'settings' &&
        components[components.length - 1] == 'permissions.yaml';
  }

  bool _hasOtherKeys(Map<String, Object?> raw) {
    return raw.keys.any((key) => key != 'rules');
  }

  /// Returns the field's string list when present, `null` when omitted, and
  /// an error when a present field is not a list of strings.
  ({List<String>? values, String? error}) _patternList(
    Map<String, Object?> rule,
    String key,
  ) {
    if (!rule.containsKey(key)) return (values: null, error: null);
    final value = rule[key];
    if (value is! List || value.any((entry) => entry is! String)) {
      return (
        values: null,
        error: '"$key" must be a list of strings',
      );
    }
    return (
      values: List.unmodifiable(value.cast<String>()),
      error: null,
    );
  }

  PolicyCardSelection _available(
    List<KiroPermissionRule> rules, {
    required bool hasUnclassifiedSettings,
  }) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
      presentation: KiroPermissionsPresentation(
        rules: rules,
        hasUnclassifiedSettings: hasUnclassifiedSettings,
      ),
      suppressGenericRulesSection: true,
    );
  }

  PolicyCardSelection _unsupported(String reason) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason: reason,
      suppressGenericRulesSection: true,
    );
  }

  PolicyCardSelection _unsupportedRule(int index, String detail) {
    return _unsupported(
      'Kiro permission rule ${index + 1} is not supported: $detail. '
      'Use the raw editor to review it.',
    );
  }
}

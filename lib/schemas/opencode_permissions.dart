import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// Reviewed, plain-language help for one Opencode permission group.
class OpencodePermissionFieldHelp extends Equatable {
  /// Creates help for one displayed Opencode permission group.
  const OpencodePermissionFieldHelp({
    required this.label,
    required this.description,
  });

  final String label;

  /// A description of the stored setting, not a prediction of rule matching.
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Reviewed help metadata for the currently supported Opencode permission
/// groups.
class OpencodePermissionsHelp {
  /// Explains the card's intentionally read-only scope.
  static const policy = OpencodePermissionFieldHelp(
    label: 'Opencode permissions',
    description:
        'This card shows the allow, ask, and deny rules stored in the '
        'permission block of this opencode.json file. Opencode resolves those '
        'rules at runtime (last match wins, with per-agent overrides and auto '
        'mode); this card does not compute that effective policy.',
  );

  /// Explains the global action that applies to every tool.
  static const global = OpencodePermissionFieldHelp(
    label: 'Global',
    description:
        'An action applied to every tool when the permission block is a single '
        'value or a * rule. Stored here; Opencode applies it at runtime.',
  );

  /// Builds per-tool help whose label is the tool name.
  static OpencodePermissionFieldHelp toolPermission(String toolName) {
    return OpencodePermissionFieldHelp(
      label: toolName,
      description:
          'The action or rules stored for this tool in this file. Opencode '
          'applies them at runtime; for granular pattern rules, the last '
          'matching rule wins.',
    );
  }
}

/// The stored permission for one Opencode tool: either a scalar action or a
/// granular `pattern → action` rule map. Exactly one is set.
class OpencodeToolPermission extends Equatable {
  /// Creates a per-tool permission from a scalar action or a granular map.
  OpencodeToolPermission({
    this.action,
    Map<String, String>? patterns,
  }) : patterns = patterns == null ? null : Map.unmodifiable(patterns),
       assert(
         action == null || patterns == null,
         'action and patterns are exclusive',
       );

  /// The scalar action (`allow`/`ask`/`deny`) for this tool, when simple.
  final String? action;

  /// The granular `pattern → action` rules for this tool, when object-form.
  final Map<String, String>? patterns;

  @override
  List<Object?> get props => [action, patterns];
}

/// A read-only, validated view of an Opencode `permission` block.
class OpencodePermissionsPresentation extends PolicyCardPresentation {
  /// Creates a presentation from the recognized Opencode permission entries.
  OpencodePermissionsPresentation({
    required this.globalAction,
    required Map<String, OpencodeToolPermission> tools,
    required this.hasConfiguredPermission,
  }) : tools = Map.unmodifiable(tools);

  /// A global action (`allow`/`ask`/`deny`) from a scalar `permission` or `*`.
  final String? globalAction;

  /// The stored per-tool permissions, in file order.
  final Map<String, OpencodeToolPermission> tools;

  /// Whether a `permission` key is present in the file.
  final bool hasConfiguredPermission;

  @override
  List<Object?> get props => [globalAction, tools, hasConfiguredPermission];
}

/// Interprets the known Opencode `permission` block without mutating it.
class OpencodePermissionsAdapter implements PolicyCardAdapter {
  /// Stable key used by the widget registry. Named `adapterId` (not `id`)
  /// because Dart forbids a static member and an instance member sharing one
  /// name; the instance getter below forwards to it for the interface.
  static const adapterId = 'opencode.permissions';

  @override
  String get id => adapterId;

  /// The primary documentation for the displayed Opencode permission policy.
  static final Uri documentationUri = Uri.parse(
    'https://opencode.ai/docs/permissions/',
  );

  static const _actions = {'allow', 'ask', 'deny'};

  bool _isAction(String value) => _actions.contains(value);

  /// Returns a read-only presentation only for known Opencode targets.
  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isOpencodeTarget(config, discoveredConfig)) {
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.notApplicable,
      );
    }

    final raw = config.rawSettings;
    if (!raw.containsKey('permission')) {
      return PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.available,
        presentation: OpencodePermissionsPresentation(
          globalAction: null,
          tools: const {},
          hasConfiguredPermission: false,
        ),
      );
    }

    final permission = raw['permission'];
    if (permission is String) {
      if (!_isAction(permission)) return _unsupportedField('permission');
      return PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.available,
        presentation: OpencodePermissionsPresentation(
          globalAction: permission,
          tools: const {},
          hasConfiguredPermission: true,
        ),
      );
    }
    if (permission is! Map) return _unsupportedShape();

    final tools = <String, OpencodeToolPermission>{};
    String? globalAction;
    for (final entry in permission.entries) {
      if (entry.key is! String) return _unsupportedShape();
      final key = entry.key as String;
      final value = entry.value;
      if (key == '*') {
        if (value is! String || !_isAction(value)) {
          return _unsupportedField('*');
        }
        globalAction = value;
        continue;
      }
      if (value is String) {
        if (!_isAction(value)) return _unsupportedField(key);
        tools[key] = OpencodeToolPermission(action: value);
        continue;
      }
      if (value is Map) {
        final patterns = <String, String>{};
        for (final patternEntry in value.entries) {
          if (patternEntry.key is! String) return _unsupportedField(key);
          final pattern = patternEntry.key as String;
          final action = patternEntry.value;
          if (action is! String || !_isAction(action)) {
            return _unsupportedField(key);
          }
          patterns[pattern] = action;
        }
        tools[key] = OpencodeToolPermission(patterns: patterns);
        continue;
      }
      return _unsupportedField(key);
    }

    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
      presentation: OpencodePermissionsPresentation(
        globalAction: globalAction,
        tools: tools,
        hasConfiguredPermission: true,
      ),
    );
  }

  bool _isOpencodeTarget(
    ToolConfig config,
    DiscoveredConfig? discoveredConfig,
  ) {
    if (discoveredConfig == null ||
        !discoveredConfig.fromCatalog ||
        discoveredConfig.descriptor?.id != ToolId.opencode ||
        discoveredConfig.kind != ConfigSourceKind.structuredConfig ||
        discoveredConfig.format != ConfigFormat.jsonc ||
        config.format != ConfigFormat.jsonc ||
        (discoveredConfig.scope != ConfigLocationScope.user &&
            discoveredConfig.scope != ConfigLocationScope.project)) {
      return false;
    }

    return p.basename(discoveredConfig.filePath) == 'opencode.json';
  }

  PolicyCardSelection _unsupportedShape() {
    return const PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason:
          'This Opencode permission shape is not supported for structured '
          'display. Use the raw editor to review it.',
    );
  }

  PolicyCardSelection _unsupportedField(String field) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason:
          'Opencode permission "$field" is not a supported value. '
          'Use the raw editor to review it.',
    );
  }
}

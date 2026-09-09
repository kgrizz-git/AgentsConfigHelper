import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// Reviewed, plain-language help for the fields shown on the Cursor card.
class CursorPermissionFieldHelp extends Equatable {
  /// Creates help for one displayed Cursor permissions field.
  const CursorPermissionFieldHelp({
    required this.label,
    required this.description,
  });

  final String label;

  /// A description of the stored setting, not a prediction of rule matching.
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Reviewed help metadata for the currently supported Cursor permission fields.
class CursorPermissionsHelp {
  /// Explains the card's intentionally read-only scope.
  static const policy = CursorPermissionFieldHelp(
    label: 'Cursor Agent permissions',
    description:
        'This card shows the allowlists and auto-review instructions stored in '
        "this permissions.json file. Cursor combines this file's user and "
        'project entries and may apply team-admin or in-app settings at '
        'runtime; this card does not compute that effective policy.',
  );

  /// Explains the MCP server:tool allowlist.
  static const mcpAllowlist = CursorPermissionFieldHelp(
    label: 'MCP allowlist',
    description:
        'Lists MCP server:tool patterns declared in this file. Cursor decides '
        'how these match MCP calls at runtime.',
  );

  /// Explains the terminal command allowlist.
  static const terminalAllowlist = CursorPermissionFieldHelp(
    label: 'Terminal allowlist',
    description:
        'Lists terminal command or prefix patterns declared in this file. '
        'Cursor decides how these match terminal commands at runtime.',
  );

  /// Explains the allow_instructions guidance.
  static const allowInstructions = CursorPermissionFieldHelp(
    label: 'Allow instructions',
    description:
        "Natural-language guidance that leans Cursor's Auto-review toward "
        'allowing calls.',
  );

  /// Explains the block_instructions guidance.
  static const blockInstructions = CursorPermissionFieldHelp(
    label: 'Block instructions',
    description:
        "Natural-language guidance that leans Cursor's Auto-review toward "
        'prompting before calls.',
  );
}

/// A read-only, validated view of a Cursor Agent `permissions.json`.
///
/// Each field is a `List<String>?`; a `null` means the field is **omitted**
/// from the file, while a non-null (possibly empty) list means the field is
/// present. The card distinguishes these so it faithfully shows what is stored.
class CursorPermissionsPresentation extends PolicyCardPresentation {
  /// Creates a presentation from the recognized Cursor permissions object.
  CursorPermissionsPresentation({
    required List<String>? mcpAllowlist,
    required List<String>? terminalAllowlist,
    required List<String>? allowInstructions,
    required List<String>? blockInstructions,
    required this.hasUnclassifiedSettings,
  }) : mcpAllowlist = _unmodifiable(mcpAllowlist),
       terminalAllowlist = _unmodifiable(terminalAllowlist),
       allowInstructions = _unmodifiable(allowInstructions),
       blockInstructions = _unmodifiable(blockInstructions);

  /// MCP `server:tool` patterns, or `null` when omitted.
  final List<String>? mcpAllowlist;

  /// Terminal command/prefix patterns, or `null` when omitted.
  final List<String>? terminalAllowlist;

  /// Auto-review allow guidance, or `null` when omitted.
  final List<String>? allowInstructions;

  /// Auto-review block guidance, or `null` when omitted.
  final List<String>? blockInstructions;

  /// Whether unrecognized sibling keys remain available only as raw content.
  final bool hasUnclassifiedSettings;

  @override
  List<Object?> get props => [
    mcpAllowlist,
    terminalAllowlist,
    allowInstructions,
    blockInstructions,
    hasUnclassifiedSettings,
  ];

  static List<String>? _unmodifiable(List<String>? values) {
    return values == null ? null : List.unmodifiable(values);
  }
}

/// Interprets the known Cursor `permissions.json` policy without mutating it.
class CursorPermissionsAdapter implements PolicyCardAdapter {
  /// Stable key used by the widget registry. Named `adapterId` (not `id`)
  /// because Dart forbids a static member and an instance member sharing one
  /// name; the instance getter below forwards to it for the interface.
  static const adapterId = 'cursor.permissions';

  @override
  String get id => adapterId;

  /// The primary documentation for the displayed Cursor permission policy.
  static final Uri documentationUri = Uri.parse(
    'https://cursor.com/docs/reference/permissions',
  );

  static const _recognizedKeys = {
    'mcpAllowlist',
    'terminalAllowlist',
    'autoRun',
  };

  static const _autoRunRecognizedKeys = {
    'allow_instructions',
    'block_instructions',
  };

  /// Returns a read-only presentation only for known Cursor permissions
  /// targets.
  /// `rawSettings` is the decoded top-level object and is typed
  /// `Map<String, Object?>` (see `json_config_parser.dart`), so a non-`String`
  /// key is unrepresentable and no per-key guard is needed here.
  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    if (!_isCursorPermissionsTarget(config, discoveredConfig)) {
      return const PolicyCardSelection(
        adapterId: adapterId,
        status: PolicyCardStatus.notApplicable,
      );
    }

    final policy = config.rawSettings;

    final mcp = _stringArray(policy, 'mcpAllowlist');
    if (mcp.unsupported) return _unsupportedField('mcpAllowlist');
    final terminal = _stringArray(policy, 'terminalAllowlist');
    if (terminal.unsupported) return _unsupportedField('terminalAllowlist');

    List<String>? allowInstructions;
    List<String>? blockInstructions;
    var autoRunUnclassified = false;
    if (policy.containsKey('autoRun')) {
      final autoRun = policy['autoRun'];
      if (autoRun is! Map) return _unsupportedField('autoRun');
      final autoRunMap = <String, Object?>{};
      for (final entry in autoRun.entries) {
        if (entry.key is! String) return _unsupportedField('autoRun');
        autoRunMap[entry.key as String] = entry.value;
      }
      final allow = _stringArray(autoRunMap, 'allow_instructions');
      if (allow.unsupported) return _unsupportedField('allow_instructions');
      final block = _stringArray(autoRunMap, 'block_instructions');
      if (block.unsupported) return _unsupportedField('block_instructions');
      allowInstructions = allow.values;
      blockInstructions = block.values;
      autoRunUnclassified = autoRunMap.keys.any(
        (key) => !_autoRunRecognizedKeys.contains(key),
      );
    }

    final hasUnclassifiedSettings =
        policy.keys.any((key) => !_recognizedKeys.contains(key)) ||
        autoRunUnclassified;

    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
      presentation: CursorPermissionsPresentation(
        mcpAllowlist: mcp.values,
        terminalAllowlist: terminal.values,
        allowInstructions: allowInstructions,
        blockInstructions: blockInstructions,
        hasUnclassifiedSettings: hasUnclassifiedSettings,
      ),
    );
  }

  bool _isCursorPermissionsTarget(
    ToolConfig config,
    DiscoveredConfig? discoveredConfig,
  ) {
    if (discoveredConfig == null ||
        !discoveredConfig.fromCatalog ||
        discoveredConfig.descriptor?.id != ToolId.cursor ||
        discoveredConfig.kind != ConfigSourceKind.structuredConfig ||
        discoveredConfig.format != ConfigFormat.json ||
        config.format != ConfigFormat.json ||
        (discoveredConfig.scope != ConfigLocationScope.user &&
            discoveredConfig.scope != ConfigLocationScope.project)) {
      return false;
    }

    final filePath = discoveredConfig.filePath;
    return p.basename(filePath) == 'permissions.json' &&
        p.basename(p.dirname(filePath)) == '.cursor';
  }

  /// Returns the field's list when present, `null` when omitted, and flags
  /// `unsupported` when a present field is not a valid string list.
  ({List<String>? values, bool unsupported}) _stringArray(
    Map<String, Object?> map,
    String key,
  ) {
    if (!map.containsKey(key)) return (values: null, unsupported: false);
    final value = map[key];
    if (value is! List || value.any((entry) => entry is! String)) {
      return (values: null, unsupported: true);
    }
    return (
      values: List.unmodifiable(value.cast<String>()),
      unsupported: false,
    );
  }

  PolicyCardSelection _unsupportedField(String field) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.unsupported,
      unsupportedReason:
          'Cursor permission "$field" is not a supported value. '
          'Use the raw editor to review it.',
    );
  }
}

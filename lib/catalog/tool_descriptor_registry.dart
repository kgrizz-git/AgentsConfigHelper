import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:path/path.dart' as p;

/// Result of matching a path against the tool descriptor registry.
class RegistryMatchResult {
  /// Creates a registry match result.
  RegistryMatchResult({
    required this.scope,
    required this.format,
    required this.sourceLabel,
    this.descriptor,
  });

  /// The matched tool descriptor, or null if this is an unknown manual file.
  final ToolDescriptor? descriptor;

  /// The matched scope.
  final ConfigLocationScope scope;

  /// The determined configuration format.
  final ConfigFormat format;

  /// The label for the source (e.g. tool name or 'Unknown configuration').
  final String sourceLabel;
}

/// Exception thrown when a file extension is unsupported.
class ValidationException implements Exception {
  /// Creates a validation exception.
  ValidationException(this.message);

  /// The validation error message.
  final String message;

  @override
  String toString() => message;
}

/// Registry of all supported tool configurations for discovery.
class ToolDescriptorRegistry {
  /// The catalog of supported tool descriptors in order.
  static const List<ToolDescriptor> catalog = [
    ToolDescriptor(
      id: ToolId.claudeCode,
      displayName: 'Claude Code',
      targets: [
        ConfigTarget(
          relativePath: '.claude/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.claude/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.codex,
      displayName: 'Codex',
      targets: [
        ConfigTarget(
          relativePath: '.codex/config.toml',
          format: ConfigFormat.toml,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.codex/config.toml',
          format: ConfigFormat.toml,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.opencode,
      displayName: 'Opencode',
      targets: [
        ConfigTarget(
          relativePath: '.config/opencode/opencode.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.opencode/opencode.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.paseo,
      displayName: 'Paseo',
      targets: [
        ConfigTarget(
          relativePath: '.paseo/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: 'paseo.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.cursor,
      displayName: 'Cursor',
      targets: [
        ConfigTarget(
          relativePath: '.cursor/permissions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cursor/permissions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.kiro,
      displayName: 'Kiro',
      targets: [
        ConfigTarget(
          relativePath: '.kiro/settings/permissions.yaml',
          format: ConfigFormat.yaml,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.devin,
      displayName: 'Devin',
      targets: [
        ConfigTarget(
          relativePath: '.config/devin/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.devin/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.antigravity,
      displayName: 'Antigravity',
      targets: [
        ConfigTarget(
          relativePath: '.gemini/antigravity-cli/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.agyAcp,
      displayName: 'Agy-ACP',
      targets: [
        ConfigTarget(
          relativePath: '.openab/agy-acp/sessions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
  ];

  /// Returns the descriptor for the given [id], or null if not found.
  static ToolDescriptor? getById(ToolId id) {
    for (final descriptor in catalog) {
      if (descriptor.id == id) return descriptor;
    }
    return null;
  }

  /// Matches a normalized absolute path against the catalog.
  ///
  /// Checks for an exact match against known user targets
  /// (if [normalizedHomePath] is provided) and known project targets
  /// (if [normalizedProjectRoots] are provided).
  /// If no exact match is found, treats it as a manual file and attempts to derive the format.
  /// Throws a [ValidationException] if the extension is unsupported.
  static RegistryMatchResult matchPath(
    String normalizedAbsolutePath, {
    String? normalizedHomePath,
    List<String> normalizedProjectRoots = const [],
  }) {
    // 1. Try exact matches first
    for (final descriptor in catalog) {
      for (final target in descriptor.targets) {
        if (target.scope == ConfigLocationScope.user &&
            normalizedHomePath != null) {
          final expected = p.normalize(
            p.join(normalizedHomePath, target.relativePath),
          );
          if (expected == normalizedAbsolutePath) {
            return RegistryMatchResult(
              descriptor: descriptor,
              scope: ConfigLocationScope.user,
              format: target.format,
              sourceLabel: descriptor.displayName,
            );
          }
        } else if (target.scope == ConfigLocationScope.project) {
          for (final root in normalizedProjectRoots) {
            final expected = p.normalize(
              p.join(root, target.relativePath),
            );
            if (expected == normalizedAbsolutePath) {
              return RegistryMatchResult(
                descriptor: descriptor,
                scope: ConfigLocationScope.project,
                format: target.format,
                sourceLabel: descriptor.displayName,
              );
            }
          }
        }
      }
    }

    // 2. Fallback to manual unknown file. We must validate the extension.
    final ext = p.extension(normalizedAbsolutePath).toLowerCase();
    ConfigFormat format;
    switch (ext) {
      case '.json':
        format = ConfigFormat.json;
      case '.jsonc':
        format = ConfigFormat.jsonc;
      case '.yaml':
      case '.yml':
        format = ConfigFormat.yaml;
      case '.toml':
        format = ConfigFormat.toml;
      default:
        throw ValidationException(
          'Unsupported configuration file extension: $ext',
        );
    }

    return RegistryMatchResult(
      scope: ConfigLocationScope.manual,
      format: format,
      sourceLabel: 'Unknown configuration',
    );
  }
}

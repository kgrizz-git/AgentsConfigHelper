import 'package:agents_config_helper/models/tool_config.dart'; // To get ConfigFormat
import 'package:equatable/equatable.dart';

/// Identifiers for supported AI agent and IDE tools.
enum ToolId {
  /// Claude Code.
  claudeCode,

  /// Codex.
  codex,

  /// Opencode.
  opencode,

  /// Paseo.
  paseo,

  /// Cursor.
  cursor,

  /// Kiro.
  kiro,

  /// Devin.
  devin,

  /// Antigravity.
  antigravity,

  /// Agy-ACP.
  agyAcp,
}

/// The location scope of a discovered configuration.
enum ConfigLocationScope {
  /// A global configuration file found in the user's home directory.
  user,

  /// A repository-level configuration file found in an explicitly added
  /// project root.
  project,

  /// A configuration file manually added by the user at a specific path.
  manual,
}

/// The kind of configuration source.
enum ConfigSourceKind {
  /// A structured config file (JSON, YAML, TOML) that the app can fully
  /// parse and edit.
  structuredConfig,

  /// A markdown or raw text rule/instruction file (e.g., AGENTS.md, .cursorrules).
  instructionDocument,
}

/// A specific target path and format associated with a tool.
class ConfigTarget extends Equatable {
  /// Creates a config target.
  const ConfigTarget({
    required this.relativePath,
    required this.format,
    required this.scope,
    required this.kind,
  });

  /// The expected relative path, such as `.claude/settings.json`.
  /// For [ConfigLocationScope.user], this is relative to the user's home
  /// directory. For [ConfigLocationScope.project], this is relative to the
  /// project root.
  final String relativePath;

  /// The serialization format expected at this target.
  final ConfigFormat format;

  /// The scope where this target applies.
  final ConfigLocationScope scope;

  /// The kind of configuration source.
  final ConfigSourceKind kind;

  @override
  List<Object?> get props => [relativePath, format, scope, kind];
}

/// A pure domain descriptor for a supported tool and its known
/// configuration targets.
class ToolDescriptor extends Equatable {
  /// Creates a tool descriptor.
  const ToolDescriptor({
    required this.id,
    required this.displayName,
    required this.targets,
  });

  /// The stable identifier for this tool.
  final ToolId id;

  /// The human-readable name of the tool.
  final String displayName;

  /// The known configuration targets for this tool.
  final List<ConfigTarget> targets;

  @override
  List<Object?> get props => [id, displayName, targets];
}

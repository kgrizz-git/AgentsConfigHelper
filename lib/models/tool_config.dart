import 'dart:collection';

import 'package:equatable/equatable.dart';

/// The file format used for a tool configuration.
enum ConfigFormat {
  /// JSON or JSONC configuration.
  json,

  /// YAML configuration.
  yaml,

  /// TOML configuration.
  toml,

  /// A format that has no supported parser.
  unknown,
}

/// A normalized representation of one tool's configuration file.
class ToolConfig extends Equatable {
  /// Creates a normalized configuration with its original unedited settings.
  ToolConfig({
    required this.toolName,
    required this.filePath,
    required this.format,
    this.rules = const [],
    this.permissions = const [],
    Map<String, Object?> rawSettings = const {},
  }) : rawSettings = UnmodifiableMapView(rawSettings);

  /// The display name of the configured tool.
  final String toolName;

  /// The user-provided path to the configuration file.
  final String filePath;

  /// The serialization format for this configuration.
  final ConfigFormat format;

  /// User-editable rule entries.
  final List<String> rules;

  /// User-editable flat permission entries.
  final List<String> permissions;

  /// Original settings retained for fields not represented by the editor.
  final Map<String, Object?> rawSettings;

  /// Returns a copy with the supplied fields replaced.
  ToolConfig copyWith({
    String? toolName,
    String? filePath,
    ConfigFormat? format,
    List<String>? rules,
    List<String>? permissions,
    Map<String, Object?>? rawSettings,
  }) {
    return ToolConfig(
      toolName: toolName ?? this.toolName,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      rules: rules ?? this.rules,
      permissions: permissions ?? this.permissions,
      rawSettings: rawSettings ?? this.rawSettings,
    );
  }

  @override
  List<Object?> get props => [
    toolName,
    filePath,
    format,
    rules,
    permissions,
    rawSettings,
  ];
}

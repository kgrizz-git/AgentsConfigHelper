import 'dart:collection';

import 'package:equatable/equatable.dart';

enum ConfigFormat {
  json,
  yaml,
  toml,
  markdown, // Reserved for future use (Phase N)
  unknown, // Fallback for unsupported config types
}

class ToolConfig extends Equatable {
  ToolConfig({
    required this.toolName,
    required this.filePath,
    required this.format,
    this.rules = const [],
    this.permissions = const [],
    Map<String, Object?> rawSettings = const {},
  }) : rawSettings = UnmodifiableMapView(rawSettings);

  final String toolName;
  final String filePath;
  final ConfigFormat format;
  final List<String> rules;
  final List<String> permissions;
  final Map<String, Object?> rawSettings;

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

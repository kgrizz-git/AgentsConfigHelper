import 'package:agents_config_helper/models/tool_config.dart';

/// Base exception for configuration parsing errors.
class ConfigParseException implements Exception {
  const ConfigParseException(this.message);

  final String message;

  @override
  String toString() => 'ConfigParseException: $message';
}

/// A pure interface for parsing tool configurations from strings.
abstract class ConfigParser {
  /// Parses raw file content into a unified [ToolConfig].
  ///
  /// Throws [ConfigParseException] if the content is structurally invalid
  /// or cannot be parsed.
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
  });

  /// Serializes a [ToolConfig] back into raw file content.
  ///
  /// [originalContent] can be provided for formats that support preserving
  /// user comments and formatting (e.g., YAML, TOML).
  String serialize(ToolConfig config, {String? originalContent});
}

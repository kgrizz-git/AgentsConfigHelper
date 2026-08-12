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
  /// This method is responsible for taking a [ToolConfig] and turning it back
  /// into a string format. Implementations should strive to preserve formatting
  /// and comments from [originalContent] if the format allows it.
  String serialize(ToolConfig config, {String? originalContent});
}

/// A mixin with common helper methods for [ConfigParser] implementations.
mixin ConfigParserMixin {
  /// Extracts a list of strings from an untyped object, safely discarding
  /// non-string elements.
  List<String> extractStringList(Object? value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  /// Returns true if the [content] is null, empty, or entirely whitespace.
  bool isContentEmpty(String content) {
    return content.trim().isEmpty;
  }
}

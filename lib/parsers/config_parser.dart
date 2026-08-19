import 'package:agents_config_helper/models/tool_config.dart';

/// Base exception for configuration parsing errors.
class ConfigParseException implements Exception {
  /// Creates a parsing exception with a user-facing [message] and optional
  /// 1-based [line]/[column] position in the source content.
  const ConfigParseException(this.message, {this.line, this.column});

  /// The reason parsing or serialization failed.
  final String message;

  /// The 1-based line of the error in the source content, when known.
  final int? line;

  /// The 1-based column of the error in the source content, when known.
  final int? column;

  @override
  String toString() {
    final hasPosition = line != null && column != null;
    final position = hasPosition ? ' at line $line, column $column' : '';
    return 'ConfigParseException: $message$position';
  }
}

/// A pure interface for parsing tool configurations from strings.
abstract class ConfigParser {
  /// Parses raw file content into a unified [ToolConfig].
  ///
  /// When [format] is supplied (e.g. resolved from a catalog/registry
  /// descriptor), it is authoritative and is preserved on the returned
  /// [ToolConfig] as-is. Filename-based format detection is only used as a
  /// fallback when [format] is `null`.
  ///
  /// Throws [ConfigParseException] if the content is structurally invalid
  /// or cannot be parsed.
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
    ConfigFormat? format,
  });

  /// Serializes a [ToolConfig] back into raw file content.
  /// Implementations preserve formatting and comments from [originalContent]
  /// when their format supports safe in-place updates.
  String serialize(ToolConfig config, {String? originalContent});
}

/// A mixin with common helper methods for [ConfigParser] implementations.
mixin ConfigParserMixin {
  /// Extracts string values from an untyped list.
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

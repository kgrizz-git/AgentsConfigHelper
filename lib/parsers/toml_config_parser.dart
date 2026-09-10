import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:toml/toml.dart';

/// Parses and serializes TOML configuration files.
class TomlConfigParser with ConfigParserMixin implements ConfigParser {
  /// Parses raw TOML content into a [ToolConfig].
  ///
  /// Empty or entirely-whitespace content preserves `content` as
  /// `originalContent` and returns an otherwise-empty [ToolConfig].
  @override
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
    ConfigFormat? format,
  }) {
    final resolvedFormat = format ?? ConfigFormat.toml;
    if (isContentEmpty(content)) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: resolvedFormat,
        originalContent: content,
      );
    }

    final TomlDocument doc;
    try {
      doc = TomlDocument.parse(content);
    } catch (e) {
      // TomlParserException exposes 1-based line/column getters; surface
      // them on the wrapped exception when the underlying error is one.
      int? line;
      int? column;
      if (e is TomlParserException) {
        line = e.line;
        column = e.column;
      }
      throw ConfigParseException(
        'Invalid TOML syntax: $e',
        line: line,
        column: column,
      );
    }

    final rawMap = doc.toMap();
    final rules = extractStringList(rawMap['rules']);
    final permissions = extractStringList(rawMap['permissions']);

    return ToolConfig(
      toolName: toolName,
      filePath: filePath,
      format: resolvedFormat,
      rules: rules,
      permissions: permissions,
      originalContent: content,
      rawSettings: rawMap,
    );
  }

  /// Writes a flat-editor-owned list key without destroying other shapes.
  ///
  /// List-shaped raw values are managed exactly as before (set when the new
  /// list is non-empty, removed when emptied). User additions onto an absent
  /// key still write. Map, scalar, and other non-list shapes are left
  /// untouched so structured saves preserve tables the flat editor cannot
  /// represent. Adds no new write capability.
  void _writeFlatListKey(
    Map<String, Object?> outputMap,
    ToolConfig config,
    String key,
    List<String> values,
  ) {
    if (!config.rawSettings.containsKey(key)) {
      if (values.isNotEmpty) outputMap[key] = values;
      return;
    }
    if (config.rawSettings[key] is! List) return;
    if (values.isNotEmpty) {
      outputMap[key] = values;
    } else {
      outputMap.remove(key);
    }
  }

  /// Serializes a [ToolConfig] into a TOML string.
  ///
  /// **WARNING:** Unlike JSON and YAML, the current Dart TOML package does not
  /// support lossless AST editing. This method works by converting the raw
  /// settings into a Dart Map and re-serializing it from scratch.
  /// As a result, **all original comments, whitespace, and structural layout
  /// (like arrays of tables) will be discarded or reformatted.**
  ///
  /// This lossy behavior is a deliberate, deferred choice — see
  /// docs/adr/ADR-001-toml-comment-preservation.md for the options considered
  /// (notably a surgical text-splice mirroring the JSON path) and the trigger
  /// for revisiting it.
  @override
  String serialize(ToolConfig config, {String? originalContent}) {
    return serializeWithOutcome(
      config,
      originalContent: originalContent,
    ).content;
  }

  @override
  SerializeOutcome serializeWithOutcome(
    ToolConfig config, {
    String? originalContent,
  }) {
    final outputMap = Map<String, Object?>.from(config.rawSettings);

    _writeFlatListKey(outputMap, config, 'rules', config.rules);
    _writeFlatListKey(
      outputMap,
      config,
      'permissions',
      config.permissions,
    );

    try {
      final doc = TomlDocument.fromMap(outputMap);
      return SerializeOutcome(
        content: doc.toString(),
        usedFallback:
            originalContent != null && originalContent.trim().isNotEmpty,
      );
    } catch (e) {
      throw ConfigParseException('Failed to serialize TOML: $e');
    }
  }
}

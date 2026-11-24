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

  /// Writes a dirty flat-editor-owned list key without destroying other
  /// shapes. A dirty field whose current value is not a list of strings is
  /// refused rather than silently left unchanged.
  void _writeFlatListKey(
    Map<String, Object?> outputMap,
    ToolConfig config,
    String key,
    List<String> values,
    bool dirty,
    StructuredField field,
  ) {
    if (!dirty) return;
    if (!config.rawSettings.containsKey(key)) {
      if (values.isNotEmpty) outputMap[key] = values;
      return;
    }
    final current = config.rawSettings[key];
    if (current is! List || current.any((item) => item is! String)) {
      throw StructuredEditRefusedException(
        'Cannot safely update "$key": its current value is not a list of '
        'strings. Use the raw editor to change it.',
        field: field,
      );
    }
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
  String serialize(
    ToolConfig config, {
    String? originalContent,
    FieldEditMask? edits,
  }) {
    return serializeWithOutcome(
      config,
      originalContent: originalContent,
      edits: edits,
    ).content;
  }

  @override
  SerializeOutcome serializeWithOutcome(
    ToolConfig config, {
    String? originalContent,
    FieldEditMask? edits,
  }) {
    final effectiveEdits = resolveEdits(config, originalContent, edits);
    final outputMap = Map<String, Object?>.from(config.rawSettings);

    _writeFlatListKey(
      outputMap,
      config,
      'rules',
      config.rules,
      effectiveEdits.rules,
      StructuredField.rules,
    );
    _writeFlatListKey(
      outputMap,
      config,
      'permissions',
      config.permissions,
      effectiveEdits.permissions,
      StructuredField.permissions,
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

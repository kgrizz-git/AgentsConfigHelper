import 'dart:convert';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Parses and serializes YAML configuration files.
class YamlConfigParser with ConfigParserMixin implements ConfigParser {
  /// Parses raw YAML content into a [ToolConfig].
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
    final resolvedFormat = format ?? ConfigFormat.yaml;
    if (isContentEmpty(content)) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: resolvedFormat,
        originalContent: content,
      );
    }

    final Object? doc;
    try {
      doc = loadYaml(content);
    } catch (e) {
      // YamlException carries a nullable SourceSpan; extract the 0-based
      // start position and convert to 1-based for ConfigParseException.
      int? line;
      int? column;
      if (e is YamlException) {
        line = e.span?.start.line;
        if (line != null) line += 1;
        column = e.span?.start.column;
        if (column != null) column += 1;
      }
      throw ConfigParseException(
        'Invalid YAML syntax: $e',
        line: line,
        column: column,
      );
    }

    if (doc == null) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: resolvedFormat,
        originalContent: content,
      );
    }

    if (doc is! YamlMap) {
      throw const ConfigParseException('YAML root must be a map.');
    }

    final rawMap = _deepConvertMap(doc);
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

  /// Serializes a [ToolConfig] back into YAML content.
  ///
  /// Only the fields named by [edits] are rewritten; every other field keeps
  /// its exact source representation.
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
    if (originalContent != null && originalContent.trim().isNotEmpty) {
      try {
        final editor = YamlEditor(originalContent);
        final currentDoc = loadYaml(originalContent);

        if (currentDoc is YamlMap) {
          final normalizedDoc = _deepConvertMap(currentDoc);

          // Update raw settings
          for (final entry in config.rawSettings.entries) {
            if (entry.key == 'rules' || entry.key == 'permissions') continue;

            // Only update if changed or missing to avoid unnecessary diffs
            if (!normalizedDoc.containsKey(entry.key) ||
                jsonEncode(normalizedDoc[entry.key]) !=
                    jsonEncode(entry.value)) {
              editor.update([entry.key], entry.value);
            }
          }

          _assertYamlFieldSafe(
            currentDoc,
            'rules',
            effectiveEdits.rules,
            StructuredField.rules,
          );
          _assertYamlFieldSafe(
            currentDoc,
            'permissions',
            effectiveEdits.permissions,
            StructuredField.permissions,
          );

          if (effectiveEdits.rules) {
            if (config.rules.isNotEmpty) {
              editor.update(['rules'], config.rules);
            } else if (currentDoc.containsKey('rules')) {
              editor.remove(['rules']);
            }
          }

          if (effectiveEdits.permissions) {
            if (config.permissions.isNotEmpty) {
              editor.update(['permissions'], config.permissions);
            } else if (currentDoc.containsKey('permissions')) {
              editor.remove(['permissions']);
            }
          }

          return SerializeOutcome(
            content: editor.toString(),
            usedFallback: false,
          );
        }
      } on StructuredEditRefusedException {
        rethrow;
      } on Exception catch (_) {
        // Fallback to building from scratch if parsing original fails.
      }
      // yaml_edit throws AssertionError on anchor/alias shapes that it cannot
      // safely update in place. Catching it here is deliberate: it routes the
      // shape to the whole-document fallback (or a fail-closed block upstream)
      // instead of propagating an unhandled error to the caller.
      // ignore: avoid_catching_errors
      on AssertionError catch (_) {
        // Fall through to the whole-document fallback below.
      }
    }

    final sourceFields =
        originalContent != null && originalContent.trim().isNotEmpty
        ? _sourceOwnedFields(originalContent)
        : null;

    // Fallback to building from scratch
    final editor = YamlEditor('');
    final outputMap = Map<String, Object?>.from(config.rawSettings);

    if (effectiveEdits.rules) {
      if (config.rules.isNotEmpty) {
        outputMap['rules'] = config.rules;
      } else {
        outputMap.remove('rules');
      }
    } else if (sourceFields != null) {
      final rules = sourceFields['rules'];
      if (rules != null) {
        outputMap['rules'] = rules;
      } else {
        outputMap.remove('rules');
      }
    }

    if (effectiveEdits.permissions) {
      if (config.permissions.isNotEmpty) {
        outputMap['permissions'] = config.permissions;
      } else {
        outputMap.remove('permissions');
      }
    } else if (sourceFields != null) {
      final permissions = sourceFields['permissions'];
      if (permissions != null) {
        outputMap['permissions'] = permissions;
      } else {
        outputMap.remove('permissions');
      }
    }

    editor.update([], outputMap);
    return SerializeOutcome(
      content: editor.toString(),
      usedFallback:
          originalContent != null && originalContent.trim().isNotEmpty,
    );
  }

  /// Refuses a dirty field whose YAML source is not a list of strings.
  void _assertYamlFieldSafe(
    YamlMap doc,
    String key,
    bool dirty,
    StructuredField field,
  ) {
    if (!dirty || !doc.containsKey(key)) return;
    final value = doc[key];
    if (value is! YamlList || value.any((item) => item is! String)) {
      throw StructuredEditRefusedException(
        'Cannot safely update "$key": its current value is not a list of '
        'strings. Use the raw editor to change it.',
        field: field,
      );
    }
  }

  /// Returns the owned fields present in the source, with their string-list
  /// values. Refuses a rewrite when an owned field cannot be represented.
  Map<String, List<String>?> _sourceOwnedFields(String originalContent) {
    final Object? doc;
    try {
      doc = loadYaml(originalContent);
    } on Object {
      throw const StructuredEditRefusedException(
        'Cannot rewrite the file: its current content is not valid YAML.',
      );
    }
    if (doc is! YamlMap) {
      // A non-mapping root has no owned fields to preserve.
      return const <String, List<String>?>{};
    }
    final fields = <String, List<String>?>{};
    for (final key in const ['rules', 'permissions']) {
      if (!doc.containsKey(key)) continue;
      final value = doc[key];
      if (value is! YamlList || value.any((item) => item is! String)) {
        throw StructuredEditRefusedException(
          'Cannot rewrite the file: "$key" is not a list of strings and would '
          'be lost.',
          field: key == 'rules'
              ? StructuredField.rules
              : StructuredField.permissions,
        );
      }
      fields[key] = value.map((item) => item! as String).toList();
    }
    return fields;
  }

  Map<String, Object?> _deepConvertMap(YamlMap yamlMap) {
    final map = <String, Object?>{};
    for (final key in yamlMap.keys) {
      map[key.toString()] = _deepConvert(yamlMap[key]);
    }
    return map;
  }

  List<Object?> _deepConvertList(YamlList yamlList) {
    return yamlList.map(_deepConvert).toList();
  }

  Object? _deepConvert(Object? value) {
    if (value is YamlMap) return _deepConvertMap(value);
    if (value is YamlList) return _deepConvertList(value);
    return value;
  }
}

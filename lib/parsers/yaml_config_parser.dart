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
  /// When [originalContent] is provided, this uses [YamlEditor] to update
  /// only the changed keys in place, preserving existing comments and
  /// formatting. If the original content fails to parse as a map, it falls
  /// back to building a fresh YAML document from `config.rawSettings`.
  @override
  String serialize(ToolConfig config, {String? originalContent}) {
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

          if (config.rules.isNotEmpty) {
            editor.update(['rules'], config.rules);
          } else if (currentDoc.containsKey('rules')) {
            editor.remove(['rules']);
          }

          if (config.permissions.isNotEmpty) {
            editor.update(['permissions'], config.permissions);
          } else if (currentDoc.containsKey('permissions')) {
            editor.remove(['permissions']);
          }

          return editor.toString();
        }
      } on Exception catch (_) {
        // Fallback to building from scratch if parsing original fails
      }
    }

    // Fallback to building from scratch
    final editor = YamlEditor('');
    final outputMap = Map<String, Object?>.from(config.rawSettings);

    if (config.rules.isNotEmpty) {
      outputMap['rules'] = config.rules;
    } else {
      outputMap.remove('rules');
    }

    if (config.permissions.isNotEmpty) {
      outputMap['permissions'] = config.permissions;
    } else {
      outputMap.remove('permissions');
    }

    editor.update([], outputMap);
    return editor.toString();
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

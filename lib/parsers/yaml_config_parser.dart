import 'dart:convert';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

class YamlConfigParser with ConfigParserMixin implements ConfigParser {
  @override
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
  }) {
    if (isContentEmpty(content)) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: ConfigFormat.yaml,
      );
    }

    final Object? doc;
    try {
      doc = loadYaml(content);
    } catch (e) {
      throw ConfigParseException('Invalid YAML syntax: $e');
    }

    if (doc == null) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: ConfigFormat.yaml,
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
      format: ConfigFormat.yaml,
      rules: rules,
      permissions: permissions,
      rawSettings: rawMap,
    );
  }

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
                jsonEncode(normalizedDoc[entry.key]) != jsonEncode(entry.value)) {
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

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:toml/toml.dart';

/// Parses and serializes TOML configuration files.
class TomlConfigParser with ConfigParserMixin implements ConfigParser {
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
        format: ConfigFormat.toml,
      );
    }

    final TomlDocument doc;
    try {
      doc = TomlDocument.parse(content);
    } catch (e) {
      throw ConfigParseException('Invalid TOML syntax: $e');
    }

    final rawMap = doc.toMap();
    final rules = extractStringList(rawMap['rules']);
    final permissions = extractStringList(rawMap['permissions']);

    return ToolConfig(
      toolName: toolName,
      filePath: filePath,
      format: ConfigFormat.toml,
      rules: rules,
      permissions: permissions,
      originalContent: content,
      rawSettings: rawMap,
    );
  }

  @override
  String serialize(ToolConfig config, {String? originalContent}) {
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

    try {
      final doc = TomlDocument.fromMap(outputMap);
      return doc.toString();
    } catch (e) {
      throw ConfigParseException('Failed to serialize TOML: $e');
    }
  }
}

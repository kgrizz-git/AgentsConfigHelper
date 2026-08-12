import 'dart:convert';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';

class JsonConfigParser with ConfigParserMixin implements ConfigParser {
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
        format: ConfigFormat.json,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw ConfigParseException('Invalid JSON syntax: ${e.message}');
    }

    if (decoded == null) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: ConfigFormat.json,
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw const ConfigParseException(
        'JSON root must be an object (Map).',
      );
    }

    final rules = extractStringList(decoded['rules']);
    final permissions = extractStringList(decoded['permissions']);

    return ToolConfig(
      toolName: toolName,
      filePath: filePath,
      format: ConfigFormat.json,
      rules: rules,
      permissions: permissions,
      rawSettings: decoded,
    );
  }

  @override
  String serialize(ToolConfig config, {String? originalContent}) {
    // For JSON, if originalContent is provided, we could theoretically modify
    // it, but dart:convert does not support AST manipulation for JSON.
    // Instead, we reserialize rawSettings combined with rules/permissions.

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

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(outputMap)}\n';
  }
}

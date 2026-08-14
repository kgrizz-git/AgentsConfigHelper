import 'dart:convert';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/jsonc_cleaner.dart';
import 'package:agents_config_helper/vendor/json_ast/json_ast.dart' as json_ast;

class _Edit {
  _Edit(this.start, this.end, this.replacement);
  final int start;
  final int end;
  final String replacement;
}

/// Parses and serializes JSON and JSONC configuration files.
class JsonConfigParser with ConfigParserMixin implements ConfigParser {
  @override
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
  }) {
    final format = filePath.toLowerCase().endsWith('.jsonc')
        ? ConfigFormat.jsonc
        : ConfigFormat.json;

    if (isContentEmpty(content)) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: format,
        originalContent: content,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      // If strict JSON fails, try cleaning as JSONC
      try {
        final cleanContent = JsoncCleaner.clean(content);
        decoded = jsonDecode(cleanContent);
      } on FormatException catch (e) {
        throw ConfigParseException('Invalid JSON/JSONC syntax: ${e.message}');
      }
    }

    if (decoded == null) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: format,
        originalContent: content,
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
      format: format,
      rules: rules,
      permissions: permissions,
      originalContent: content,
      rawSettings: decoded,
    );
  }

  @override
  String serialize(ToolConfig config, {String? originalContent}) {
    if (originalContent != null && originalContent.trim().isNotEmpty) {
      try {
        final cleanContent = JsoncCleaner.clean(originalContent);
        final ast = json_ast.parse(cleanContent, json_ast.Settings());

        if (ast is json_ast.ObjectNode) {
          var result = originalContent;

          final newFields = <String, dynamic>{};
          if (config.rules.isNotEmpty) newFields['rules'] = config.rules;
          final originalPermissions = config.rawSettings['permissions'];
          final preservesNestedPermissions =
              originalPermissions != null && originalPermissions is! List;
          if (config.permissions.isNotEmpty) {
            newFields['permissions'] = config.permissions;
          }

          json_ast.PropertyNode? rulesNode;
          json_ast.PropertyNode? permissionsNode;
          for (final prop in ast.children) {
            if (prop.key!.value == 'rules') rulesNode = prop;
            if (prop.key!.value == 'permissions') permissionsNode = prop;
          }

          final edits = <_Edit>[];
          const encoder = JsonEncoder();

          void deleteNode(json_ast.PropertyNode node) {
            var start = node.loc!.start.offset;
            var end = node.loc!.end.offset;
            var precedingComma = -1;
            for (var i = start - 1; i >= 0; i--) {
              if (originalContent[i] == ',') {
                precedingComma = i;
                break;
              }
              if (cleanContent[i] == ' ' ||
                  cleanContent[i] == '\n' ||
                  cleanContent[i] == '\r' ||
                  cleanContent[i] == '\t') {
                continue;
              }
              break;
            }
            final commentFollowsPrecedingComma =
                precedingComma != -1 &&
                (originalContent
                        .substring(precedingComma + 1, start)
                        .contains('//') ||
                    originalContent
                        .substring(precedingComma + 1, start)
                        .contains('/*'));
            if (precedingComma != -1 && !commentFollowsPrecedingComma) {
              start = precedingComma;
            } else {
              for (var i = end; i < originalContent.length; i++) {
                if (originalContent[i] == ',') {
                  end = i + 1;
                  break;
                }
                if (cleanContent[i] == ' ' ||
                    cleanContent[i] == '\n' ||
                    cleanContent[i] == '\r' ||
                    cleanContent[i] == '\t') {
                  continue;
                }
                break;
              }
            }
            edits.add(_Edit(start, end, ''));
          }

          if (rulesNode != null) {
            if (newFields.containsKey('rules')) {
              edits.add(
                _Edit(
                  rulesNode.value!.loc!.start.offset,
                  rulesNode.value!.loc!.end.offset,
                  encoder.convert(newFields['rules']),
                ),
              );
            } else {
              deleteNode(rulesNode);
            }
          }

          if (permissionsNode != null && !preservesNestedPermissions) {
            if (newFields.containsKey('permissions')) {
              edits.add(
                _Edit(
                  permissionsNode.value!.loc!.start.offset,
                  permissionsNode.value!.loc!.end.offset,
                  encoder.convert(newFields['permissions']),
                ),
              );
            } else {
              deleteNode(permissionsNode);
            }
          }

          // Handle additions (keys that did not exist)
          final additions = <String>[];
          if (rulesNode == null && newFields.containsKey('rules')) {
            additions.add('"rules": ${encoder.convert(newFields['rules'])}');
          }
          if (permissionsNode == null && newFields.containsKey('permissions')) {
            additions.add(
              '"permissions": ${encoder.convert(newFields['permissions'])}',
            );
          }

          if (additions.isNotEmpty) {
            final insertPos = ast.loc!.end.offset - 1; // Before the closing }

            // Check if there is a trailing comma before insertPos
            var hasTrailingComma = false;
            for (var i = insertPos - 1; i >= 0; i--) {
              final char = originalContent[i];
              if (char == ' ' || char == '\n' || char == '\r' || char == '\t') {
                continue;
              }
              if (char == ',') hasTrailingComma = true;
              break;
            }

            final needsComma = ast.children.isNotEmpty && !hasTrailingComma;
            final prefix = needsComma ? ',\n  ' : '\n  ';
            const suffix = '\n';
            final insertion = prefix + additions.join(',\n  ') + suffix;
            edits.add(_Edit(insertPos, insertPos, insertion));
          }

          // Descending offsets preserve edit locations in the original string.
          edits.sort((a, b) => b.start.compareTo(a.start));
          for (final edit in edits) {
            result = result.replaceRange(
              edit.start,
              edit.end,
              edit.replacement,
            );
          }

          jsonDecode(JsoncCleaner.clean(result));
          return result;
        }
      } on Object catch (_) {
        // A failed in-place patch uses the full serialization fallback below.
      }
    }

    // Fallback to building from scratch
    final outputMap = Map<String, Object?>.from(config.rawSettings);

    if (config.rules.isNotEmpty) {
      outputMap['rules'] = config.rules;
    } else {
      outputMap.remove('rules');
    }

    final originalPermissions = config.rawSettings['permissions'];
    final preservesNestedPermissions =
        originalPermissions != null && originalPermissions is! List;
    if (config.permissions.isNotEmpty) {
      outputMap['permissions'] = config.permissions;
    } else if (!preservesNestedPermissions) {
      outputMap.remove('permissions');
    }

    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(outputMap)}\n';
  }
}

import 'dart:convert';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/jsonc_cleaner.dart';
import 'package:agents_config_helper/vendor/json_ast/json_ast.dart' as json_ast;

class _Edit {
  new(this.start, this.end, this.replacement);
  final int start;
  final int end;
  final String replacement;
}

/// Parses and serializes JSON and JSONC configuration files.
class JsonConfigParser with ConfigParserMixin implements ConfigParser {
  /// Shown when strict JSON decoding fails and the content is retried as
  /// JSONC (comments/trailing commas) instead.
  static const String jsoncFallbackWarning =
      'Parsed as JSONC — JSONC syntax (comments or trailing commas) was '
      'detected.';

  /// Parses raw JSON or JSONC content into a [ToolConfig].
  ///
  /// For [ConfigFormat.jsonc], a strict decode failure retries through
  /// [JsoncCleaner] and records a [ToolConfig.parseWarnings] entry. A strict
  /// [ConfigFormat.json] target instead rejects comments and trailing commas,
  /// so the app never writes JSONC to a tool that requires strict JSON. Empty
  /// or entirely-whitespace content preserves `content` as `originalContent`
  /// and returns an otherwise-empty [ToolConfig].
  @override
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
    ConfigFormat? format,
  }) {
    final resolvedFormat =
        format ??
        (filePath.toLowerCase().endsWith('.jsonc')
            ? ConfigFormat.jsonc
            : ConfigFormat.json);

    if (isContentEmpty(content)) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: resolvedFormat,
        originalContent: content,
      );
    }

    Object? decoded;
    var jsoncFallbackUsed = false;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (strictError) {
      if (resolvedFormat != ConfigFormat.jsonc) {
        // A strict target must stay strict: report a precise error instead of
        // silently accepting JSONC and writing a file the tool would reject.
        try {
          jsonDecode(JsoncCleaner.clean(content));
        } on FormatException {
          final position = _lineColumnFromOffset(content, strictError.offset);
          throw ConfigParseException(
            'Invalid JSON syntax: ${strictError.message}',
            line: position?.$1,
            column: position?.$2,
          );
        } on Exception {
          // The cleaner failed for a non-syntax reason; the strictness message
          // below is still the accurate explanation for this target.
        }
        final position = _lineColumnFromOffset(content, strictError.offset);
        throw ConfigParseException(
          'This file must be strict JSON: comments and trailing commas are '
          'not allowed. Remove them or edit the file as raw text.',
          line: position?.$1,
          column: position?.$2,
        );
      }
      try {
        final cleanContent = JsoncCleaner.clean(content);
        decoded = jsonDecode(cleanContent);
        jsoncFallbackUsed = true;
      } on FormatException catch (e) {
        final position = _lineColumnFromOffset(content, e.offset);
        throw ConfigParseException(
          'Invalid JSONC syntax: ${e.message}',
          line: position?.$1,
          column: position?.$2,
        );
      }
    }

    if (decoded == null) {
      return ToolConfig(
        toolName: toolName,
        filePath: filePath,
        format: resolvedFormat,
        originalContent: content,
        parseWarnings: jsoncFallbackUsed
            ? const [jsoncFallbackWarning]
            : const [],
        parsedAsJsonc: jsoncFallbackUsed,
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
      format: resolvedFormat,
      rules: rules,
      permissions: permissions,
      originalContent: content,
      rawSettings: decoded,
      parseWarnings: jsoncFallbackUsed
          ? const [jsoncFallbackWarning]
          : const [],
      parsedAsJsonc: jsoncFallbackUsed,
    );
  }

  /// Derives 1-based line/column coordinates from a character [offset] into
  /// [content]. Returns null when the offset is out of range. Used to turn
  /// [FormatException.offset] into editor-style positions.
  static (int, int)? _lineColumnFromOffset(String content, int? offset) {
    if (offset == null || offset < 0 || offset > content.length) return null;
    var line = 1;
    var column = 1;
    for (var i = 0; i < offset; i++) {
      if (content[i] == '\n') {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return (line, column);
  }

  /// Serializes a [ToolConfig] back into JSON/JSONC content.
  ///
  /// When [originalContent] is provided, this attempts a surgical in-place
  /// patch of only the dirty structured fields via AST offsets, so existing
  /// comments, formatting, unrelated keys, and untouched fields are preserved.
  /// If the patch cannot be applied safely, it falls back to re-encoding the
  /// full settings map from scratch (which discards comments).
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
      final outcome = _tryInPlaceOutcome(
        config,
        originalContent,
        effectiveEdits,
      );
      if (outcome != null) return outcome;
    }
    return _rewriteOutcome(config, originalContent, effectiveEdits);
  }

  /// Refuses a dirty field whose source shape cannot be rewritten safely.
  static void _assertDirtyFieldsSafe(
    Iterable<String> dirtyKeys,
    Map<String, List<json_ast.PropertyNode>> nodesByKey,
  ) {
    for (final key in dirtyKeys) {
      final nodes = nodesByKey[key] ?? const <json_ast.PropertyNode>[];
      if (nodes.length > 1) {
        throw StructuredEditRefusedException(
          'Cannot safely update "$key": the file contains more than one '
          '"$key" key. Resolve the duplicates or edit the raw file.',
          field: _fieldFor(key),
        );
      }
      if (nodes.length == 1 && !_isPlainStringArray(nodes.single.value)) {
        throw StructuredEditRefusedException(
          'Cannot safely update "$key": its current value is not a list '
          'of strings. Use the raw editor to change it.',
          field: _fieldFor(key),
        );
      }
    }
  }

  static StructuredField _fieldFor(String key) =>
      key == 'rules' ? StructuredField.rules : StructuredField.permissions;

  /// Whether [node] is a JSON array containing only strings.
  static bool _isPlainStringArray(json_ast.Node? node) {
    if (node is! json_ast.ArrayNode) return false;
    return node.children.every(
      (child) => child is json_ast.LiteralNode && child.value is String,
    );
  }

  static SerializeOutcome? _tryInPlaceOutcome(
    ToolConfig config,
    String originalContent,
    FieldEditMask edits,
  ) {
    try {
      final cleanContent = config.format == ConfigFormat.jsonc
          ? JsoncCleaner.clean(originalContent)
          : originalContent;
      final ast = json_ast.parse(cleanContent, json_ast.Settings());

      if (ast is json_ast.ObjectNode) {
        var result = originalContent;

        final dirtyValues = <String, List<String>>{
          if (edits.rules) 'rules': config.rules,
          if (edits.permissions) 'permissions': config.permissions,
        };

        final nodesByKey = <String, List<json_ast.PropertyNode>>{};
        for (final prop in ast.children) {
          final key = prop.key?.value;
          if (key == 'rules' || key == 'permissions') {
            nodesByKey
                .putIfAbsent(key!, () => <json_ast.PropertyNode>[])
                .add(prop);
          }
        }

        // Only a dirty field may be rewritten, and only when its source shape
        // can be updated without losing data. Untouched fields are not read or
        // modified here at all.
        _assertDirtyFieldsSafe(dirtyValues.keys, nodesByKey);

        final astEdits = <_Edit>[];
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
          astEdits.add(_Edit(start, end, ''));
        }

        final rulesNode = nodesByKey['rules']?.firstOrNull;
        final permissionsNode = nodesByKey['permissions']?.firstOrNull;

        if (edits.rules && rulesNode != null) {
          if (config.rules.isNotEmpty) {
            astEdits.add(
              _Edit(
                rulesNode.value!.loc!.start.offset,
                rulesNode.value!.loc!.end.offset,
                encoder.convert(config.rules),
              ),
            );
          } else {
            deleteNode(rulesNode);
          }
        }

        if (edits.permissions && permissionsNode != null) {
          if (config.permissions.isNotEmpty) {
            astEdits.add(
              _Edit(
                permissionsNode.value!.loc!.start.offset,
                permissionsNode.value!.loc!.end.offset,
                encoder.convert(config.permissions),
              ),
            );
          } else {
            deleteNode(permissionsNode);
          }
        }

        // Handle additions for dirty keys that did not exist.
        final additions = <String>[];
        if (edits.rules && rulesNode == null && config.rules.isNotEmpty) {
          additions.add('"rules": ${encoder.convert(config.rules)}');
        }
        if (edits.permissions &&
            permissionsNode == null &&
            config.permissions.isNotEmpty) {
          additions.add(
            '"permissions": ${encoder.convert(config.permissions)}',
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
          astEdits.add(_Edit(insertPos, insertPos, insertion));
        }

        // Descending offsets preserve edit locations in the original string.
        astEdits.sort((a, b) => b.start.compareTo(a.start));
        for (final edit in astEdits) {
          result = result.replaceRange(
            edit.start,
            edit.end,
            edit.replacement,
          );
        }

        jsonDecode(
          config.format == ConfigFormat.jsonc
              ? JsoncCleaner.clean(result)
              : result,
        );
        return SerializeOutcome(content: result, usedFallback: false);
      }
    } on StructuredEditRefusedException {
      rethrow;
    } on Object catch (_) {
      // A failed in-place patch uses the full serialization fallback below.
    }
    return null;
  }

  static SerializeOutcome _rewriteOutcome(
    ToolConfig config,
    String? originalContent,
    FieldEditMask edits,
  ) {
    // A full rewrite starts from the collapsed rawSettings map, so untouched
    // owned fields are restored from the source and any shape that cannot
    // survive the collapse is refused.
    final sourceFields =
        originalContent != null && originalContent.trim().isNotEmpty
        ? _sourceOwnedFields(originalContent, config.format)
        : null;

    final outputMap = Map<String, Object?>.from(config.rawSettings);

    if (edits.rules) {
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

    if (edits.permissions) {
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

    const encoder = JsonEncoder.withIndent('  ');
    return SerializeOutcome(
      content: '${encoder.convert(outputMap)}\n',
      usedFallback:
          originalContent != null && originalContent.trim().isNotEmpty,
    );
  }

  /// Returns the owned fields present in the source, with their string-list
  /// values. Refuses a rewrite when an owned field cannot be represented.
  static Map<String, List<String>?> _sourceOwnedFields(
    String originalContent,
    ConfigFormat format,
  ) {
    final json_ast.Node ast;
    try {
      ast = json_ast.parse(
        format == ConfigFormat.jsonc
            ? JsoncCleaner.clean(originalContent)
            : originalContent,
        json_ast.Settings(),
      );
    } on Object {
      throw StructuredEditRefusedException(
        format == ConfigFormat.jsonc
            ? 'Cannot rewrite the file: its current content is not valid JSONC.'
            : 'Cannot rewrite the file: its current content is not valid '
                  'strict JSON (comments and trailing commas are not allowed).',
      );
    }
    if (ast is! json_ast.ObjectNode) {
      // A non-object root has no owned fields to preserve.
      return const <String, List<String>?>{};
    }
    final fields = <String, List<String>?>{};
    for (final key in const ['rules', 'permissions']) {
      final nodes = ast.children
          .where((prop) => prop.key?.value == key)
          .toList();
      if (nodes.length > 1) {
        throw StructuredEditRefusedException(
          'Cannot rewrite the file: it contains more than one "$key" key.',
          field: _fieldFor(key),
        );
      }
      if (nodes.isEmpty) continue;
      final value = nodes.single.value;
      if (!_isPlainStringArray(value)) {
        throw StructuredEditRefusedException(
          'Cannot rewrite the file: "$key" is not a list of strings and would '
          'be lost.',
          field: _fieldFor(key),
        );
      }
      fields[key] = (value! as json_ast.ArrayNode).children
          .map((child) => (child as json_ast.LiteralNode).value! as String)
          .toList();
    }
    return fields;
  }
}

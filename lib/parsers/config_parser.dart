import 'package:agents_config_helper/models/tool_config.dart';

/// Base exception for configuration parsing errors.
class ConfigParseException implements Exception {
  /// Creates a parsing exception with a user-facing [message] and optional
  /// 1-based [line]/[column] position in the source content.
  const new(this.message, {this.line, this.column});

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

/// The structured fields a flat editor owns.
enum StructuredField {
  /// Rule entries.
  rules,

  /// Flat permission entries.
  permissions,
}

/// Which structured fields the user actually changed.
///
/// Serializers must only rewrite a field when it is dirty; every untouched
/// field keeps its exact source representation, including shapes the flat
/// editor cannot represent.
class FieldEditMask {
  /// Creates a mask with the supplied dirty fields.
  const new({this.rules = false, this.permissions = false});

  /// No structured field changed.
  const new none() : rules = false, permissions = false;

  /// Both structured fields changed.
  const new both() : rules = true, permissions = true;

  /// Whether [StructuredField.rules] changed.
  final bool rules;

  /// Whether [StructuredField.permissions] changed.
  final bool permissions;

  /// Whether [field] changed.
  bool isDirty(StructuredField field) => switch (field) {
    StructuredField.rules => rules,
    StructuredField.permissions => permissions,
  };

  /// Whether any structured field changed.
  bool get any => rules || permissions;
}

/// Thrown when a dirty structured field cannot be rewritten without losing
/// data the flat editor does not represent.
class StructuredEditRefusedException extends ConfigParseException {
  /// Creates a refusal for [field] with a user-facing [message].
  const new(super.message, {this.field});

  /// The field that could not be safely rewritten.
  final StructuredField? field;
}

/// Thrown when a structured serializer cannot preserve the original source and
/// the save path is blocked unless the caller explicitly opts into a rewrite.
class SerializationFallbackException implements Exception {
  const new({
    required this.format,
    required this.wouldBeLost,
  });

  final String format;
  final String wouldBeLost;

  @override
  String toString() =>
      'SerializationFallbackException: $format save would lose $wouldBeLost';
}

/// Result of a structured serialization attempt.
class SerializeOutcome {
  const new({
    required this.content,
    required this.usedFallback,
  });

  /// The serialized content to write.
  final String content;

  /// True when the serializer had to rebuild the document from scratch
  /// instead of updating the original source in place.
  final bool usedFallback;
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
  ///
  /// [edits] names the structured fields the user changed. A serializer must
  /// leave every other field byte-identical. When omitted, [resolveEdits]
  /// derives the mask from the source and the loaded baseline.
  String serialize(
    ToolConfig config, {
    String? originalContent,
    FieldEditMask? edits,
  });

  /// Serializes a [ToolConfig] and reports whether the preserving path
  /// succeeded or the whole-document fallback was used.
  SerializeOutcome serializeWithOutcome(
    ToolConfig config, {
    String? originalContent,
    FieldEditMask? edits,
  }) {
    return SerializeOutcome(
      content: serialize(
        config,
        originalContent: originalContent,
        edits: edits,
      ),
      usedFallback: false,
    );
  }
}

/// Resolves the dirty structured fields for a serializer call.
extension ConfigParserEditResolution on ConfigParser {
  /// Uses [edits] when supplied; otherwise derives the mask by comparing the
  /// config with the baseline parsed from [originalContent].
  ///
  /// Deriving from the baseline is required because a mixed-list or non-list
  /// source projects to a normalized list, so source comparison cannot tell an
  /// untouched field from a deliberate change.
  FieldEditMask resolveEdits(
    ToolConfig config,
    String? originalContent,
    FieldEditMask? edits,
  ) {
    if (edits != null) return edits;
    final source =
        (originalContent != null && originalContent.trim().isNotEmpty)
        ? originalContent
        : config.originalContent;
    if (source.trim().isEmpty) {
      return FieldEditMask(
        rules: config.rules.isNotEmpty,
        permissions: config.permissions.isNotEmpty,
      );
    }
    try {
      final baseline = parse(
        source,
        filePath: config.filePath,
        toolName: config.toolName,
        format: config.format,
      );
      return FieldEditMask(
        rules: !_sameStringList(config.rules, baseline.rules),
        permissions: !_sameStringList(
          config.permissions,
          baseline.permissions,
        ),
      );
    } on Exception {
      // Only an expected parse failure means the mask cannot be derived; let
      // Errors (programming bugs) propagate instead of silently marking both
      // fields dirty.
      return const FieldEditMask.both();
    }
  }
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

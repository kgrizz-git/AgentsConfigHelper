import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:path/path.dart' as p;

/// A parser for unstructured text and markdown instruction documents.
/// It wraps the entire file content into `ToolConfig.originalContent`
/// without modifying it.
class TextConfigParser implements ConfigParser {
  /// Parses raw text into a [ToolConfig] whose `originalContent` holds the
  /// entire, unaltered file content.
  @override
  ToolConfig parse(
    String content, {
    required String filePath,
    required String toolName,
    ConfigFormat? format,
  }) {
    final resolvedFormat = format ?? _determineFormat(filePath);
    return ToolConfig(
      toolName: toolName,
      filePath: filePath,
      format: resolvedFormat,
      originalContent: content,
    );
  }

  /// Returns [originalContent] when provided, falling back to
  /// `config.originalContent`.
  ///
  /// [originalContent] is the caller's serialized output (typically the file's
  /// on-disk content at save time, passed by `ConfigService.saveConfig`), not
  /// the load-time file content. Text and markdown files have no structured
  /// fields that could desync, so honoring it is intentional: if the file
  /// changed on disk while the editor was open, the save writes the current
  /// disk state instead of a stale in-memory copy.
  @override
  String serialize(ToolConfig config, {String? originalContent}) {
    return originalContent ?? config.originalContent;
  }

  ConfigFormat _determineFormat(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.md' || ext == '.mdc') {
      return ConfigFormat.markdown;
    }
    return ConfigFormat.text;
  }
}

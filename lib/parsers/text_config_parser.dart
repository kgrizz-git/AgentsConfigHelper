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
  }) {
    final format = _determineFormat(filePath);
    return ToolConfig(
      toolName: toolName,
      filePath: filePath,
      format: format,
      originalContent: content,
    );
  }

  /// Returns `config.originalContent` unchanged; text/markdown files are
  /// never reformatted or rewritten.
  @override
  String serialize(ToolConfig config, {String? originalContent}) {
    return config.originalContent;
  }

  ConfigFormat _determineFormat(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.md' || ext == '.mdc') {
      return ConfigFormat.markdown;
    }
    return ConfigFormat.text;
  }
}

import 'dart:io';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:path/path.dart' as p;

/// A facade service that orchestrates reading configs, parsing them,
/// backing them up, and safely serializing them back to disk.
class ConfigService {
  ConfigService({required this.backupService});
  final BackupService backupService;

  // Internal parsers
  final _jsonParser = JsonConfigParser();
  final _yamlParser = YamlConfigParser();
  final _tomlParser = TomlConfigParser();

  /// Reads a config file from [path], determines the appropriate parser,
  /// and returns a structured [ToolConfig].
  ///
  /// Throws a [FileSystemException] if the file cannot be read.
  /// Throws a [ConfigParseException] if parsing fails.
  Future<ToolConfig> loadConfig(String path) async {
    final file = File(path);
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    final content = await file.readAsString();
    final parser = _getParserForPath(path);
    final toolName = _guessToolNameFromPath(path);

    return parser.parse(content, filePath: path, toolName: toolName);
  }

  /// Safely saves [config] to disk.
  ///
  /// Automatically creates a backup of the existing file using [BackupService],
  /// then overwrites the file with the serialized config.
  Future<void> saveConfig(ToolConfig config, {String? originalContent}) async {
    final file = File(config.filePath);

    // Backup before write if the file already exists
    // ignore: avoid_slow_async_io
    if (await file.exists()) {
      await backupService.createBackup(config.filePath);
    } else {
      // Ensure directory exists if we are creating a brand new config
      final parentDir = file.parent;
      // ignore: avoid_slow_async_io
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
    }

    final parser = _getParserForFormat(config.format);
    final serialized = parser.serialize(
      config,
      originalContent: originalContent,
    );

    await file.writeAsString(serialized);
  }

  ConfigParser _getParserForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.json':
        return _jsonParser;
      case '.yaml':
      case '.yml':
        return _yamlParser;
      case '.toml':
        return _tomlParser;
      default:
        // Default to JSON if we can't tell, or throw?
        // Some tools might use files with no extension. We'll default to JSON.
        return _jsonParser;
    }
  }

  ConfigParser _getParserForFormat(ConfigFormat format) {
    switch (format) {
      case ConfigFormat.json:
        return _jsonParser;
      case ConfigFormat.yaml:
        return _yamlParser;
      case ConfigFormat.toml:
        return _tomlParser;
      case ConfigFormat.unknown:
        throw UnsupportedError('Unsupported config format: $format');
    }
  }

  String _guessToolNameFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('claude')) {
      return 'Claude';
    }
    if (lowerPath.contains('codex')) {
      return 'Codex';
    }
    if (lowerPath.contains('opencode')) {
      return 'Opencode';
    }
    if (lowerPath.contains('paseo')) {
      return 'Paseo';
    }
    if (lowerPath.contains('cursor')) {
      return 'Cursor';
    }
    if (lowerPath.contains('kiro')) {
      return 'Kiro';
    }
    if (lowerPath.contains('devin')) {
      return 'Devin';
    }
    if (lowerPath.contains('gemini') || lowerPath.contains('antigravity')) {
      return 'Antigravity';
    }
    if (lowerPath.contains('agy-acp')) {
      return 'agy-acp';
    }
    return 'Unknown';
  }
}

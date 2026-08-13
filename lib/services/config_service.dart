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
  /// Creates a configuration service that backs up files before writes.
  ConfigService({
    required this.backupService,
    String? Function()? homeDirectoryResolver,
  }) : _homeDirectoryResolver = homeDirectoryResolver ?? _resolveHomeDirectory;

  /// Creates backups of existing configs before overwriting them.
  final BackupService backupService;
  final String? Function() _homeDirectoryResolver;

  // Internal parsers
  final _jsonParser = JsonConfigParser();
  final _yamlParser = YamlConfigParser();
  final _tomlParser = TomlConfigParser();

  static String? _resolveHomeDirectory() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      return home;
    }
    if (Platform.isWindows) {
      final drive = Platform.environment['HOMEDRIVE'];
      final path = Platform.environment['HOMEPATH'];
      if (drive != null && path != null) {
        return '$drive$path';
      }
    }
    return null;
  }

  /// Resolves a user-supplied path to an absolute local filesystem path.
  String resolvePath(String path) {
    if (path == '~' ||
        path.startsWith('~/') ||
        (Platform.isWindows && path.startsWith(r'~\'))) {
      final home = _homeDirectoryResolver();
      if (home == null) {
        throw FileSystemException(
          'Cannot resolve home directory for a path starting with ~',
          path,
        );
      }
      final relativePath = path == '~' ? '' : path.substring(2);
      return p.normalize(p.absolute(p.join(home, relativePath)));
    }
    return p.normalize(p.absolute(path));
  }

  /// Reads a config file from [path], determines the appropriate parser,
  /// and returns a structured [ToolConfig].
  ///
  /// Throws a [FileSystemException] if the file cannot be read.
  /// Throws a [ConfigParseException] if parsing fails.
  Future<ToolConfig> loadConfig(String path) async {
    final expandedPath = resolvePath(path);
    final file = File(expandedPath);
    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', expandedPath);
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
  Future<void> saveConfig(ToolConfig config) async {
    final expandedPath = resolvePath(config.filePath);
    final file = File(expandedPath);
    String? originalContent;

    // Backup before write if the file already exists
    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (await file.exists()) {
      originalContent = await file.readAsString();
      await backupService.createBackup(expandedPath);
    } else {
      // Ensure directory exists if we are creating a brand new config
      final parentDir = file.parent;
      // The asynchronous check avoids blocking the UI thread.
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
      case '.jsonc':
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

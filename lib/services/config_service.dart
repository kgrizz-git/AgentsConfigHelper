import 'dart:io';
import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
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

  /// Loads a configuration explicitly discovered by the app.
  Future<ToolConfig> loadDiscoveredConfig(DiscoveredConfig config) async {
    final file = File(config.filePath);
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', config.filePath);
    }
    final content = await file.readAsString();
    final parser = _getParserForFormat(config.format);
    return parser.parse(
      content,
      filePath: config.filePath,
      toolName: config.sourceLabel,
    );
  }

  /// Reads a config file from a manual [path], determines the appropriate parser
  /// using the ToolDescriptorRegistry, and returns a structured [ToolConfig].
  ///
  /// Throws a [FileSystemException] if the file cannot be read.
  /// Throws a [ValidationException] if the file type is unsupported.
  Future<ToolConfig> loadConfig(String path) async {
    final expandedPath = resolvePath(path);
    final file = File(expandedPath);
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', expandedPath);
    }

    final content = await file.readAsString();

    // We import ToolDescriptorRegistry to validate the manual path
    // The home resolver might be used to see if it matches a known user target
    final home = _homeDirectoryResolver();
    final match = ToolDescriptorRegistry.matchPath(
      expandedPath,
      normalizedHomePath: home,
    );

    final parser = _getParserForFormat(match.format);
    return parser.parse(
      content,
      filePath: expandedPath,
      toolName: match.sourceLabel,
    );
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
    // ignore: avoid_slow_async_io
    if (await file.exists()) {
      originalContent = await file.readAsString();
      await backupService.createBackup(expandedPath);
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

  ConfigParser _getParserForFormat(ConfigFormat format) {
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
        return _jsonParser;
      case ConfigFormat.yaml:
        return _yamlParser;
      case ConfigFormat.toml:
        return _tomlParser;
      case ConfigFormat.unknown:
        throw UnsupportedError('Unsupported config format: $format');
    }
  }
}

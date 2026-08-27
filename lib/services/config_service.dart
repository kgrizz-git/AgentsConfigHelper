import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/parsers/text_config_parser.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/file_operations.dart';
import 'package:agents_config_helper/services/home_directory_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A facade service that orchestrates reading configs, parsing them,
/// backing them up, and safely serializing them back to disk.
class ConfigService {
  /// Creates a configuration service that backs up files before writes.
  ConfigService({
    required this.backupService,
    String? Function()? homeDirectoryResolver,
    FileOperations? fileOperations,
  }) : _homeDirectoryResolver = homeDirectoryResolver ?? resolveHomeDirectory,
       _fileOperations = fileOperations ?? const LocalFileOperations();

  /// Creates backups of existing configs before overwriting them.
  final BackupService backupService;
  final String? Function() _homeDirectoryResolver;
  final FileOperations _fileOperations;

  // Internal parsers
  final _jsonParser = JsonConfigParser();
  final _yamlParser = YamlConfigParser();
  final _tomlParser = TomlConfigParser();
  final _textParser = TextConfigParser();

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

  /// Checks whether [path] exists within the configured file boundary.
  Future<bool> fileExists(String path) =>
      _fileOperations.fileExists(resolvePath(path));

  /// Reads raw text from [path] within the configured file boundary.
  Future<String> readRawText(String path) =>
      _fileOperations.readText(resolvePath(path));

  /// Loads a configuration explicitly discovered by the app.
  Future<ToolConfig> loadDiscoveredConfig(DiscoveredConfig config) async {
    // Resolve `~` the same way the save methods do, so a discovered path loads
    // the exact file that a later save would overwrite.
    final resolvedPath = resolvePath(config.filePath);
    if (!await _fileOperations.fileExists(resolvedPath)) {
      throw FileSystemException('File not found', resolvedPath);
    }
    final content = await _fileOperations.readText(resolvedPath);
    final parser = _getParserForFormat(config.format);
    return parser.parse(
      content,
      filePath: resolvedPath,
      toolName: config.sourceLabel,
      format: config.format,
    );
  }

  /// Safely saves [config] to disk and returns the freshly-parsed result.
  ///
  /// Automatically creates a backup of the existing file using [BackupService],
  /// then overwrites the file with the serialized config and re-parses it
  /// so the returned [ToolConfig] has an up-to-date `originalContent`.
  Future<ToolConfig> saveConfig(ToolConfig config) async {
    final expandedPath = resolvePath(config.filePath);
    String? originalContent;

    if (await _fileOperations.fileExists(expandedPath)) {
      originalContent = await _fileOperations.readText(expandedPath);
      await backupService.createBackup(expandedPath);
    }

    final parser = _getParserForFormat(config.format);
    final serialized = parser.serialize(
      config,
      originalContent: originalContent,
    );

    await _fileOperations.writeText(expandedPath, serialized);

    return parser.parse(
      serialized,
      filePath: config.filePath,
      toolName: config.toolName,
      format: config.format,
    );
  }

  /// Whether `config.originalContent` is a usable baseline for a structured
  /// raw-save merge. This is the same parser check used by `saveRawConfig`.
  bool hasUsableBaseline(ToolConfig config) {
    final parser = _getParserForFormat(config.format);
    return _parseUsableBaseline(parser, config) != null;
  }

  /// Safely saves raw [rawContent] to disk and returns the updated
  /// [ToolConfig].
  ///
  /// Automatically creates a backup of the existing file using [BackupService],
  /// then overwrites the file with the raw content and re-parses it.
  ///
  /// [config] carries the rules/permissions from the structured editor,
  /// which may have been edited independently of [rawContent]. If they
  /// diverge from `config.originalContent` (the pre-edit baseline), both
  /// edits are reconciled by re-serializing on top of the raw text rather
  /// than silently discarding one or the other.
  Future<ToolConfig> saveRawConfig(ToolConfig config, String rawContent) async {
    final parser = _getParserForFormat(config.format);

    // Validate the raw content by attempting to parse it before writing.
    // Throws an exception (e.g. ConfigParseException) if invalid.
    final parsedFromRaw = parser.parse(
      rawContent,
      filePath: config.filePath,
      toolName: config.toolName,
      format: config.format,
    );

    // Compare against the pre-edit baseline (not parsedFromRaw) to detect
    // whether the structured editor was touched independently of the raw
    // text — parsedFromRaw's rules/permissions naturally differ from
    // config's whenever the raw edit itself touches those fields, which
    // must not be mistaken for a structured-editor edit.
    //
    // This is internal bookkeeping, not user-facing validation: the only
    // input that may legitimately fail parsing is `rawContent` (handled
    // above). If the baseline snapshot (`config.originalContent`) no longer
    // parses — e.g. it went stale relative to disk — do NOT surface that as
    // an "invalid raw content" error. Skip the structured-merge path and
    // honor the already-validated raw text as-is.
    final baseline = _parseUsableBaseline(parser, config);

    String contentToWrite;
    ToolConfig parsedConfig;
    if (baseline != null &&
        (!listEquals(config.rules, baseline.rules) ||
            !listEquals(config.permissions, baseline.permissions))) {
      // Text/markdown serializers cannot carry structured rules/permissions —
      // they return the raw text verbatim. A divergence here means the
      // structured editor was touched, but serializing would silently drop
      // that overlay. Reject instead of losing the edit.
      if (config.format == ConfigFormat.text ||
          config.format == ConfigFormat.markdown) {
        throw ConfigParseException(
          'Cannot save structured rules/permissions changes to a '
          '${config.format.name} config: this format has no structured '
          'fields. Edit the raw text directly or switch to a structured '
          'format.',
        );
      }
      final mergedConfig = parsedFromRaw.copyWith(
        rules: config.rules,
        permissions: config.permissions,
      );
      contentToWrite = parser.serialize(
        mergedConfig,
        originalContent: rawContent,
      );
      parsedConfig = parser.parse(
        contentToWrite,
        filePath: config.filePath,
        toolName: config.toolName,
        format: config.format,
      );
    } else {
      contentToWrite = rawContent;
      parsedConfig = parsedFromRaw;
    }

    final expandedPath = resolvePath(config.filePath);

    if (await _fileOperations.fileExists(expandedPath)) {
      await backupService.createBackup(expandedPath);
    }

    await _fileOperations.writeText(expandedPath, contentToWrite);

    return parsedConfig;
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
      case ConfigFormat.markdown:
      case ConfigFormat.text:
        return _textParser;
      case ConfigFormat.unknown:
        throw UnsupportedError('Unsupported config format: $format');
    }
  }

  ToolConfig? _parseUsableBaseline(ConfigParser parser, ToolConfig config) {
    try {
      return parser.parse(
        config.originalContent,
        filePath: config.filePath,
        toolName: config.toolName,
        format: config.format,
      );
    } on Exception {
      // Only an expected parse/format failure (e.g. ConfigParseException,
      // FormatException) means the baseline is unusable; let Errors —
      // programming bugs — propagate rather than silently skipping the merge.
      return null;
    }
  }
}

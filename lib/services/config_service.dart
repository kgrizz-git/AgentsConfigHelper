import 'dart:io';

import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/parsers/text_config_parser.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:agents_config_helper/services/backup_service.dart';
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
  }) : _homeDirectoryResolver = homeDirectoryResolver ?? resolveHomeDirectory;

  /// Creates backups of existing configs before overwriting them.
  final BackupService backupService;
  final String? Function() _homeDirectoryResolver;

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

  /// Loads a configuration explicitly discovered by the app.
  Future<ToolConfig> loadDiscoveredConfig(DiscoveredConfig config) async {
    // Resolve `~` the same way the save methods do, so a discovered path loads
    // the exact file that a later save would overwrite.
    final resolvedPath = resolvePath(config.filePath);
    final file = File(resolvedPath);
    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', resolvedPath);
    }
    final content = await file.readAsString();
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
    final file = File(expandedPath);
    String? originalContent;

    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (await file.exists()) {
      originalContent = await file.readAsString();
      await backupService.createBackup(expandedPath);
    } else {
      // Ensure directory exists if we are creating a brand new config.
      final parentDir = file.parent;
      // Checking directory existence asynchronously avoids blocking the UI
      // thread.
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

    return parser.parse(
      serialized,
      filePath: config.filePath,
      toolName: config.toolName,
      format: config.format,
    );
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
    ToolConfig? baseline;
    try {
      baseline = parser.parse(
        config.originalContent,
        filePath: config.filePath,
        toolName: config.toolName,
        format: config.format,
      );
    } on Object {
      baseline = null;
    }

    String contentToWrite;
    ToolConfig parsedConfig;
    if (baseline != null &&
        (!listEquals(config.rules, baseline.rules) ||
            !listEquals(config.permissions, baseline.permissions))) {
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
    final file = File(expandedPath);

    // Checking file existence asynchronously avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (await file.exists()) {
      await backupService.createBackup(expandedPath);
    } else {
      final parentDir = file.parent;
      // Checking directory existence asynchronously avoids blocking the UI
      // thread.
      // ignore: avoid_slow_async_io
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
    }

    await file.writeAsString(contentToWrite);

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
}

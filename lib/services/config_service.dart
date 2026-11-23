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

/// An immutable preview of a save.
///
/// Carries the exact content that will be written and the source it was
/// computed from, so the writer can verify the source still matches and commit
/// those bytes without re-serializing.
class SavePreview {
  const new({
    required this.config,
    required this.content,
    required this.sourceContent,
    required this.sourceExists,
    required this.parsed,
    required this.usedFallback,
  });

  /// The config that produced this preview.
  final ToolConfig config;

  /// The exact content to write.
  final String content;

  /// The source content the preview was computed from.
  final String sourceContent;

  /// Whether the source file existed when the preview was computed.
  final bool sourceExists;

  /// The parsed result of [content].
  final ToolConfig parsed;

  /// Whether the serializer used its whole-document fallback.
  final bool usedFallback;
}

/// Thrown when the source changed between load, preview, and commit.
class SaveConflictException implements Exception {
  const new(this.preview, this.currentContent, {this.filePath = ''});

  /// The source changed after the config was loaded but before a preview could
  /// be computed, so there is no preview to attach.
  factory stale(
    String filePath,
    String? currentContent,
  ) => SaveConflictException(null, currentContent, filePath: filePath);

  /// The preview that can no longer be committed as-is, when one exists.
  final SavePreview? preview;

  /// The path whose source changed.
  final String filePath;

  /// The current source content, or null when the file was deleted.
  final String? currentContent;

  /// The changed file's path.
  String get path => preview?.config.filePath ?? filePath;

  @override
  String toString() => 'SaveConflictException: $path changed after preview';
}

/// A facade service that orchestrates reading configs, parsing them,
/// backing them up, and safely serializing them back to disk.
class ConfigService {
  /// Creates a configuration service that backs up files before writes.
  new({
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
  ///
  /// Set [overwriteConfirmed] only after the user explicitly chose to discard
  /// external changes. It bypasses the load-baseline check, never the
  /// immediately-before-replacement source guard.
  Future<ToolConfig> saveConfig(
    ToolConfig config, {
    bool allowRewrite = false,
    bool overwriteConfirmed = false,
  }) async {
    final preview = await previewSaveConfig(
      config,
      allowRewrite: allowRewrite,
      overwriteConfirmed: overwriteConfirmed,
    );
    return await commitSavePreview(preview);
  }

  /// Computes the exact content a structured save will write without touching
  /// disk, capturing the source it was computed from.
  ///
  /// [overwriteConfirmed] bypasses only the load-baseline check; the preview
  /// still captures the current source so [commitSavePreview] can refuse a
  /// later change.
  Future<SavePreview> previewSaveConfig(
    ToolConfig config, {
    bool allowRewrite = false,
    bool overwriteConfirmed = false,
  }) async {
    final expandedPath = resolvePath(config.filePath);
    final sourceExists = await _fileOperations.fileExists(expandedPath);
    final originalContent = sourceExists
        ? await _fileOperations.readText(expandedPath)
        : null;

    final loadedContent = config.originalContent;
    final sourceMatchesLoad = sourceExists
        ? originalContent == loadedContent
        : loadedContent.trim().isEmpty;
    if (!sourceMatchesLoad && !overwriteConfirmed) {
      throw SaveConflictException.stale(
        config.filePath,
        sourceExists ? originalContent : null,
      );
    }

    final parser = _getParserForFormat(config.format);
    final baseline = _parseUsableBaseline(parser, config);
    if (baseline == null) {
      throw const ConfigParseException(
        'Cannot save structured changes: the loaded baseline could not be '
        'parsed. Reload the file or edit it as raw text.',
      );
    }
    final edits = _editsFor(config, baseline);
    final outcome = parser.serializeWithOutcome(
      config,
      originalContent: originalContent,
      edits: edits,
    );

    if (outcome.usedFallback && !allowRewrite) {
      final loss = _fallbackLossDescription(config.format);
      throw SerializationFallbackException(
        format: _formatLabel(config.format),
        wouldBeLost: loss,
      );
    }

    // Validate the exact bytes that will be written before any backup or
    // write. A strict target must never be written as JSONC and fail only
    // afterwards.
    final parsed = _validateSerialized(parser, outcome.content, config);

    return SavePreview(
      config: config,
      content: outcome.content,
      sourceContent: originalContent ?? '',
      sourceExists: sourceExists,
      parsed: parsed,
      usedFallback: outcome.usedFallback,
    );
  }

  /// Commits a preview after verifying the source has not changed.
  ///
  /// The preview's exact bytes are written; serialization is never recomputed.
  /// The compare-then-replace check narrows but cannot eliminate a race with a
  /// non-cooperating external writer (see the plan's Risks).
  Future<ToolConfig> commitSavePreview(SavePreview preview) async {
    final expandedPath = resolvePath(preview.config.filePath);
    final existsNow = await _fileOperations.fileExists(expandedPath);
    if (existsNow != preview.sourceExists) {
      throw SaveConflictException(
        preview,
        existsNow ? await _fileOperations.readText(expandedPath) : null,
      );
    }
    if (existsNow) {
      final current = await _fileOperations.readText(expandedPath);
      if (current != preview.sourceContent) {
        throw SaveConflictException(preview, current);
      }
      await backupService.createBackup(expandedPath);
    }
    await _fileOperations.writeTextAtomically(expandedPath, preview.content);
    return preview.parsed;
  }

  /// Whether `config.originalContent` is a usable baseline for a structured
  /// raw-save merge. This is the same parser check used by `saveRawConfig`.
  bool hasUsableBaseline(ToolConfig config) {
    final parser = _getParserForFormat(config.format);
    return _parseUsableBaseline(parser, config) != null;
  }

  /// Whether the current raw JSON buffer requires the JSONC parser fallback.
  ///
  /// The editor uses this only for a pending raw-plus-structured merge, so its
  /// disclosure describes the buffer that will be serialized rather than the
  /// source that was originally loaded. Invalid raw content cannot be saved;
  /// retain the loaded status until validation presents that error to the user.
  bool rawContentParsedAsJsonc(ToolConfig config, String rawContent) {
    if (config.format != ConfigFormat.json &&
        config.format != ConfigFormat.jsonc) {
      return false;
    }

    try {
      return _jsonParser
          .parse(
            rawContent,
            filePath: config.filePath,
            toolName: config.toolName,
            format: config.format,
          )
          .parsedAsJsonc;
    } on Exception {
      return config.parsedAsJsonc;
    }
  }

  /// Whether the current on-disk JSON source requires JSONC parsing.
  ///
  /// This is used for the structured-save review disclosure because
  /// [saveConfig] reads the source file immediately before serializing it.
  /// A missing or unreadable source cannot contribute JSONC syntax to that
  /// save path, so it reports false rather than making a stale claim.
  Future<bool> currentSourceParsedAsJsonc(ToolConfig config) async {
    if (config.format != ConfigFormat.json &&
        config.format != ConfigFormat.jsonc) {
      return false;
    }

    final expandedPath = resolvePath(config.filePath);
    try {
      if (!await _fileOperations.fileExists(expandedPath)) return false;
      final currentContent = await _fileOperations.readText(expandedPath);
      return rawContentParsedAsJsonc(config, currentContent);
    } on Exception {
      return false;
    }
  }

  /// Safely saves raw [rawContent] to disk and returns the updated
  /// [ToolConfig].
  Future<ToolConfig> saveRawConfig(
    ToolConfig config,
    String rawContent, {
    bool allowRewrite = false,
    bool overwriteConfirmed = false,
  }) async {
    final preview = await previewSaveRaw(
      config,
      rawContent,
      allowRewrite: allowRewrite,
      overwriteConfirmed: overwriteConfirmed,
    );
    return await commitSavePreview(preview);
  }

  /// Computes the exact content a raw save will write without touching disk.
  ///
  /// [overwriteConfirmed] bypasses only the load-baseline check; the preview
  /// still captures the current source so [commitSavePreview] can refuse a
  /// later change.
  ///
  /// [config] carries the rules/permissions from the structured editor, which
  /// may have been edited independently of [rawContent]. If they diverge from
  /// `config.originalContent` (the pre-edit baseline), both edits are
  /// reconciled by re-serializing on top of the raw text rather than silently
  /// discarding one or the other.
  Future<SavePreview> previewSaveRaw(
    ToolConfig config,
    String rawContent, {
    bool allowRewrite = false,
    bool overwriteConfirmed = false,
  }) async {
    final expandedPath = resolvePath(config.filePath);
    final sourceExists = await _fileOperations.fileExists(expandedPath);
    final sourceContent = sourceExists
        ? await _fileOperations.readText(expandedPath)
        : '';

    final loadedContent = config.originalContent;
    final sourceMatchesLoad = sourceExists
        ? sourceContent == loadedContent
        : loadedContent.trim().isEmpty;
    if (!sourceMatchesLoad && !overwriteConfirmed) {
      throw SaveConflictException.stale(
        config.filePath,
        sourceExists ? sourceContent : null,
      );
    }

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
    var usedFallback = false;
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
      final edits = _editsFor(config, baseline);
      _refuseSameFieldContention(config, baseline, parsedFromRaw, edits);
      final mergedConfig = parsedFromRaw.copyWith(
        rules: config.rules,
        permissions: config.permissions,
      );
      final mergeOutcome = parser.serializeWithOutcome(
        mergedConfig,
        originalContent: rawContent,
        edits: edits,
      );
      if (mergeOutcome.usedFallback && !allowRewrite) {
        final loss = _fallbackLossDescription(config.format);
        throw SerializationFallbackException(
          format: _formatLabel(config.format),
          wouldBeLost: loss,
        );
      }
      contentToWrite = mergeOutcome.content;
      usedFallback = mergeOutcome.usedFallback;
      parsedConfig = _validateSerialized(parser, contentToWrite, config);
    } else {
      contentToWrite = rawContent;
      parsedConfig = parsedFromRaw;
    }

    return SavePreview(
      config: config,
      content: contentToWrite,
      sourceContent: sourceContent,
      sourceExists: sourceExists,
      parsed: parsedConfig,
      usedFallback: usedFallback,
    );
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

  /// Parses the exact content a save will write, before any backup or write.
  ///
  /// This is the last gate: a strict target must never be written as JSONC and
  /// reported invalid only after the live file has already changed.
  ToolConfig _validateSerialized(
    ConfigParser parser,
    String content,
    ToolConfig config,
  ) {
    try {
      return parser.parse(
        content,
        filePath: config.filePath,
        toolName: config.toolName,
        format: config.format,
      );
    } on ConfigParseException catch (error) {
      throw ConfigParseException(
        'The generated ${_formatLabel(config.format)} content is not valid: '
        '${error.message}',
        line: error.line,
        column: error.column,
      );
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

  /// The structured fields whose editor value differs from the loaded
  /// baseline. Source comparison cannot be used because a mixed-list source
  /// projects to its strings.
  static FieldEditMask _editsFor(ToolConfig config, ToolConfig baseline) {
    return FieldEditMask(
      rules: !listEquals(config.rules, baseline.rules),
      permissions: !listEquals(config.permissions, baseline.permissions),
    );
  }

  /// Refuses a combined save when the raw buffer and the structured editor
  /// both changed the same field to different values: per-field ownership
  /// cannot decide which edit the user meant.
  static void _refuseSameFieldContention(
    ToolConfig config,
    ToolConfig baseline,
    ToolConfig rawParsed,
    FieldEditMask edits,
  ) {
    if (edits.rules &&
        !listEquals(rawParsed.rules, baseline.rules) &&
        !listEquals(config.rules, rawParsed.rules)) {
      throw const StructuredEditRefusedException(
        'Rules changed in both the raw editor and the structured editor. '
        'Edit this field in one place, then save.',
        field: StructuredField.rules,
      );
    }
    if (edits.permissions &&
        !listEquals(rawParsed.permissions, baseline.permissions) &&
        !listEquals(config.permissions, rawParsed.permissions)) {
      throw const StructuredEditRefusedException(
        'Permissions changed in both the raw editor and the structured editor. '
        'Edit this field in one place, then save.',
        field: StructuredField.permissions,
      );
    }
  }

  static String _formatLabel(ConfigFormat format) {
    switch (format) {
      case ConfigFormat.json:
        return 'JSON';
      case ConfigFormat.jsonc:
        return 'JSONC';
      case ConfigFormat.yaml:
        return 'YAML';
      case ConfigFormat.toml:
        return 'TOML';
      case ConfigFormat.markdown:
      case ConfigFormat.text:
      case ConfigFormat.unknown:
        return format.name.toUpperCase();
    }
  }

  static String _fallbackLossDescription(ConfigFormat format) {
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
        return 'comments and formatting';
      case ConfigFormat.yaml:
        return 'comments, anchors, aliases, and formatting';
      case ConfigFormat.toml:
        return 'comments, whitespace, and layout';
      case ConfigFormat.markdown:
      case ConfigFormat.text:
      case ConfigFormat.unknown:
        return 'formatting';
    }
  }
}

import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:path/path.dart' as p;

/// Result of matching a path against the tool descriptor registry.
class RegistryMatchResult {
  RegistryMatchResult({
    required this.scope,
    required this.format,
    required this.sourceLabel,
    required this.kind,
    this.descriptor,
  });

  /// The matched tool descriptor, or null if this is an unknown manual file.
  final ToolDescriptor? descriptor;

  /// The matched scope.
  final ConfigLocationScope scope;

  /// The determined configuration format.
  final ConfigFormat format;

  /// The label for the source (e.g. tool name or 'Unknown configuration').
  final String sourceLabel;

  /// The kind of the specific [ConfigTarget] that matched.
  final ConfigSourceKind kind;
}

/// Exception thrown when a file extension is unsupported.
class ValidationException implements Exception {
  ValidationException(this.message);

  /// The validation error message.
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// Path glob matching and catalog lookup helpers for [ToolDescriptor] lists.
class RegistryPathMatching {
  /// Forward-slash prefix for Copilot CLI user configs under the home tree.
  static const copilotCliUserPrefix = '.copilot/';

  /// Forward-slash prefix for the Cline Linux/WSL global-rules fallback.
  static const clineRulesFallbackPrefix = 'Cline/Rules/';

  /// Whether [relativePath] is a Copilot CLI user target under `.copilot/`.
  static bool isCopilotCliUserTarget(String relativePath) =>
      _forwardSlashes(relativePath).startsWith(copilotCliUserPrefix);

  /// Whether [relativePath] is the Cline `~/Cline/Rules` fallback target.
  static bool isClineRulesFallbackTarget(String relativePath) =>
      _forwardSlashes(relativePath).startsWith(clineRulesFallbackPrefix);

  /// Resolves a user-scope [relativePath] under [normalizedHomePath], honoring
  /// [normalizedCopilotHomePath] for Copilot CLI targets (replaces `~/.copilot`).
  static String resolveUserTargetPattern({
    required String normalizedHomePath,
    required String relativePath,
    String? normalizedCopilotHomePath,
  }) {
    if (normalizedCopilotHomePath != null &&
        isCopilotCliUserTarget(relativePath)) {
      final rest = _forwardSlashes(
        relativePath,
      ).substring(copilotCliUserPrefix.length);
      return p.normalize(p.join(normalizedCopilotHomePath, rest));
    }
    return p.normalize(p.join(normalizedHomePath, relativePath));
  }

  static String _forwardSlashes(String path) => path.replaceAll(r'\', '/');

  /// Returns true if [actualNormalizedPath] matches [expectedPattern].
  ///
  /// `*` matches a single path segment; `**` matches zero or more segments
  /// (including across separators). A trailing `**/` may match zero segments
  /// so that `dir/**/*.ext` also matches direct children of `dir`.
  ///
  /// Both sides are compared with forward-slash separators so recursive
  /// patterns work when the actual path has normalized Windows backslashes.
  /// Matching is case-insensitive on Windows.
  static bool isMatch(String expectedPattern, String actualNormalizedPath) {
    final expected = _canonicalizeForMatch(expectedPattern);
    final actual = _canonicalizeForMatch(actualNormalizedPath);
    if (!expected.contains('*')) {
      // Use path.equals so relative-vs-absolute coercion still works (string
      // == does not). On Windows, path.equals is also case-insensitive.
      return p.equals(expected, actual);
    }
    // Escape first, then restore glob wildcards. Handle `**/` before `**`
    // before `*` so nested globs keep correct semantics. After canonicalizing
    // to `/`, only forward-slash forms are needed.
    final regexStr = RegExp.escape(expected)
        .replaceAll(r'\*\*/', '(?:.*/)?')
        .replaceAll(r'\*\*', '.*')
        .replaceAll(r'\*', '[^/]*');
    final regex = RegExp(
      '^$regexStr\$',
      caseSensitive: !Platform.isWindows,
    );
    return regex.hasMatch(actual);
  }

  /// Normalizes [path] to forward slashes for glob comparison.
  static String _canonicalizeForMatch(String path) {
    // r'\' is a one-character backslash (raw string ends before the closing quote).
    return path.replaceAll(r'\', '/');
  }

  /// Matches a normalized absolute path against [catalog].
  ///
  /// Checks for an exact match against known user targets
  /// (if [normalizedHomePath] is provided) and known project targets
  /// (if [normalizedProjectRoots] are provided).
  /// If no exact match is found, treats it as a manual file and attempts
  /// to derive the format.
  /// Throws a [ValidationException] if the extension is unsupported.
  static RegistryMatchResult matchPath(
    String normalizedAbsolutePath, {
    required List<ToolDescriptor> catalog,
    String? normalizedHomePath,
    List<String> normalizedProjectRoots = const [],
    String? normalizedCopilotHomePath,
    bool enableClineRulesFallback = true,
  }) {
    for (final descriptor in catalog) {
      for (final target in descriptor.targets) {
        if (target.scope == ConfigLocationScope.user &&
            normalizedHomePath != null) {
          if (!enableClineRulesFallback &&
              isClineRulesFallbackTarget(target.relativePath)) {
            continue;
          }
          final expected = resolveUserTargetPattern(
            normalizedHomePath: normalizedHomePath,
            relativePath: target.relativePath,
            normalizedCopilotHomePath: normalizedCopilotHomePath,
          );
          if (isMatch(expected, normalizedAbsolutePath)) {
            return RegistryMatchResult(
              descriptor: descriptor,
              scope: ConfigLocationScope.user,
              format: target.format,
              sourceLabel: descriptor.displayName,
              kind: target.kind,
            );
          }
        } else if (target.scope == ConfigLocationScope.project) {
          for (final root in normalizedProjectRoots) {
            final expected = p.normalize(
              p.join(root, target.relativePath),
            );
            if (isMatch(expected, normalizedAbsolutePath)) {
              return RegistryMatchResult(
                descriptor: descriptor,
                scope: ConfigLocationScope.project,
                format: target.format,
                sourceLabel: descriptor.displayName,
                kind: target.kind,
              );
            }
          }
        }
      }
    }

    final ext = p.extension(normalizedAbsolutePath).toLowerCase();
    ConfigFormat format;
    switch (ext) {
      case '.json':
        format = ConfigFormat.json;
      case '.jsonc':
        format = ConfigFormat.jsonc;
      case '.yaml':
      case '.yml':
        format = ConfigFormat.yaml;
      case '.toml':
        format = ConfigFormat.toml;
      case '.md':
        format = ConfigFormat.markdown;
      case '.mdc':
        // Cursor .mdc rule files resolve to text via the catalog project
        // target; keep the manual-path fallback identical so both paths agree.
        format = ConfigFormat.text;
      case '.txt':
      case '.rules':
        format = ConfigFormat.text;
      default:
        if (ext.isEmpty ||
            p.basename(normalizedAbsolutePath) == '.cursorrules') {
          format = ConfigFormat.text;
        } else {
          throw ValidationException(
            'Unsupported configuration file extension: $ext',
          );
        }
    }

    final ConfigSourceKind kind;
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
      case ConfigFormat.yaml:
      case ConfigFormat.toml:
      case ConfigFormat.unknown:
        kind = ConfigSourceKind.structuredConfig;
      case ConfigFormat.markdown:
      case ConfigFormat.text:
        kind = ConfigSourceKind.instructionDocument;
    }

    return RegistryMatchResult(
      scope: ConfigLocationScope.manual,
      format: format,
      kind: kind,
      sourceLabel: 'Unknown configuration',
    );
  }
}

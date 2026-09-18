import 'dart:io';

import 'package:agents_config_helper/catalog/platform_applicability.dart';
import 'package:agents_config_helper/catalog/registry_path_matching.dart';
import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:path/path.dart' as p;

/// The kind of configuration source shown in the overview report.
enum OverviewKind {
  /// A structured config file (JSON, YAML, TOML).
  config,

  /// A permissions file.
  permissions,

  /// A rules / instruction document.
  rules,

  /// Anything else or unknown.
  other,
}

/// Why an overview entry is listed, present, or suppressed.
enum OverviewRelevance {
  /// The file was discovered on disk.
  present,

  /// A catalog target for a tool with discovered configuration is absent.
  expectedMissing,

  /// A documented optional/alternate/legacy target is absent.
  optionalMissing,

  /// A catalog target that applies only to a different operating system.
  otherPlatform,

  /// The owning tool has no discovered configuration, so its absent targets
  /// are suppressed by default.
  notConfigured,
}

/// Which subset of catalog targets a report or export contains.
enum ReportView {
  /// Present, expected-missing, and optional-missing entries only.
  relevant,

  /// Every catalog target, including other-platform and not-configured.
  audit,
}

/// A single row in the config overview report.
class ConfigOverviewEntry {
  /// Creates an overview entry.
  const new({
    required this.toolId,
    required this.displayName,
    required this.displayPath,
    required this.kind,
    required this.format,
    required this.scope,
    required this.secretBearing,
    required this.relevance,
    this.platform = ConfigPlatform.any,
    this.filePath,
  });

  /// The stable tool identifier, or null for the "Other" group.
  final ToolId? toolId;

  /// Human-readable tool name, or "Other" for unmatched manual entries.
  final String displayName;

  /// Absolute path used for `file:` links, or null when unconstructible.
  /// Absent entries may still carry a path; [relevance] suppresses the link.
  final String? filePath;

  /// Human-readable path shown in the row.
  final String displayPath;

  /// Badge kind: config, permissions, rules, or other.
  final OverviewKind kind;

  /// The serialization format.
  final ConfigFormat format;

  /// Location scope mirroring [ConfigLocationScope].
  final ConfigLocationScope scope;

  /// True when this file may contain sensitive values.
  final bool secretBearing;

  /// Why this entry is listed: present, expected missing, optional missing,
  /// other platform, or not configured.
  final OverviewRelevance relevance;

  /// The catalog target's declared host platform, for audit labels.
  final ConfigPlatform platform;

  /// True when the file exists on disk and can be linked.
  bool get isPresent => relevance == OverviewRelevance.present;

  /// True only for a genuinely expected catalog target that is absent.
  bool get isExpectedMissing => relevance == OverviewRelevance.expectedMissing;

  @override
  String toString() =>
      'ConfigOverviewEntry('
      'toolId=$toolId, '
      'displayName=$displayName, '
      'filePath=$filePath, '
      'displayPath=$displayPath, '
      'kind=$kind, '
      'format=$format, '
      'scope=$scope, '
      'secretBearing=$secretBearing, '
      'relevance=$relevance, '
      'platform=$platform)';
}

const _sensitiveBasenames = <String>{
  'token',
  'secret',
  'credential',
  'auth',
  'private-key',
  '.env',
};

OverviewKind _kindFromSourceKind(ConfigSourceKind kind) {
  switch (kind) {
    case ConfigSourceKind.structuredConfig:
      return OverviewKind.config;
    case ConfigSourceKind.instructionDocument:
      return OverviewKind.rules;
  }
}

String kindLabel(OverviewKind kind) {
  return kind.name;
}

String formatLabel(ConfigFormat format) {
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
      return 'Markdown';
    case ConfigFormat.text:
      return 'plain';
    case ConfigFormat.unknown:
      return 'Unknown';
  }
}

String scopeLabel(ConfigLocationScope scope) {
  return scope.name;
}

bool _isSecretBearing(ToolId? toolId, String absolutePath) {
  if (toolId != null &&
      ToolDescriptorRegistry.toolsWithSecretBearingConfigs.contains(toolId)) {
    return true;
  }
  final basename = p.basename(absolutePath).toLowerCase();
  if (basename == '.env') return true;
  if (RegExp(r'^\.env\..+$').hasMatch(basename)) return true;

  final stem = basename.contains('.')
      ? basename.substring(0, basename.lastIndexOf('.'))
      : basename;
  // Also match the singular form so plurals like secrets.json, tokens.json,
  // and credentials.json are flagged (a single trailing s is stripped;
  // words ending in ss are left alone).
  final singularStem = stem.replaceAllMapped(
    RegExp(r'(^|[.\-_\s])([^ .\-_\s]*[^s.\-_\s])s(?=$|[.\-_\s])'),
    (match) => '${match.group(1)}${match.group(2)}',
  );
  for (final name in _sensitiveBasenames) {
    if (name == '.env') continue;
    final pattern = RegExp(
      r'(^|[.\-_\s])' + RegExp.escape(name) + r'($|[.\-_\s])',
    );
    if (pattern.hasMatch(stem) || pattern.hasMatch(singularStem)) return true;
  }
  return false;
}

String _displayPath(
  String absolutePath,
  ConfigLocationScope scope,
  String? normalizedHome,
  String? root,
  String? copilotHome,
) {
  if (scope == ConfigLocationScope.user) {
    if (copilotHome != null && p.isWithin(copilotHome, absolutePath)) {
      return absolutePath;
    }
    if (normalizedHome != null) {
      return p.relative(absolutePath, from: normalizedHome);
    }
  } else if (scope == ConfigLocationScope.project && root != null) {
    final basename = p.basename(root);
    final relative = p.relative(absolutePath, from: root);
    return '$basename/$relative';
  }
  if (normalizedHome != null &&
      !Platform.isWindows &&
      p.isWithin(normalizedHome, absolutePath)) {
    final relative = p.relative(absolutePath, from: normalizedHome);
    return '~/$relative';
  }
  return absolutePath;
}

int _toolIndex(ToolId? toolId, List<ToolDescriptor> catalog) {
  if (toolId == null) return catalog.length;
  final index = catalog.indexWhere((t) => t.id == toolId);
  return index == -1 ? catalog.length : index;
}

String? _findProjectRoot(String absolutePath, List<String> normalizedRoots) {
  // Nested roots are allowed, so select the longest (most specific) match —
  // first-match order would attribute nested-project files to the outer root.
  String? mostSpecificRoot;
  for (final root in normalizedRoots) {
    if (p.isWithin(root, absolutePath) &&
        (mostSpecificRoot == null || root.length > mostSpecificRoot.length)) {
      mostSpecificRoot = root;
    }
  }
  return mostSpecificRoot;
}

int _scopeOrder(ConfigLocationScope scope) {
  switch (scope) {
    case ConfigLocationScope.user:
      return 0;
    case ConfigLocationScope.project:
      return 1;
    case ConfigLocationScope.manual:
      return 2;
  }
}

ConfigOverviewEntry _entryFromDiscovered(
  DiscoveredConfig item,
  ToolDescriptor? tool,
  String? normalizedHome, {
  String? root,
  String? copilotHome,
}) {
  return ConfigOverviewEntry(
    toolId: tool?.id,
    displayName: tool?.displayName ?? 'Unknown',
    filePath: item.filePath,
    displayPath: _displayPath(
      item.filePath,
      item.scope,
      normalizedHome,
      root,
      copilotHome,
    ),
    kind: _kindFromSourceKind(item.kind),
    format: item.format,
    scope: item.scope,
    secretBearing: _isSecretBearing(tool?.id, item.filePath),
    relevance: OverviewRelevance.present,
  );
}

ConfigOverviewEntry _absentEntry(
  ToolDescriptor tool,
  ConfigTarget target,
  String expectedPath,
  OverviewRelevance relevance,
  String? normalizedHome, {
  String? root,
  String? copilotHome,
}) {
  return ConfigOverviewEntry(
    toolId: tool.id,
    displayName: tool.displayName,
    filePath: expectedPath,
    displayPath: _displayPath(
      expectedPath,
      target.scope,
      normalizedHome,
      root,
      copilotHome,
    ),
    kind: _kindFromSourceKind(target.kind),
    format: target.format,
    scope: target.scope,
    secretBearing: _isSecretBearing(tool.id, expectedPath),
    relevance: relevance,
    platform: target.platform,
  );
}

/// Classifies an absent catalog target relative to the host platform and
/// whether its owning tool has any discovered configuration.
OverviewRelevance _classifyAbsent(
  ConfigTarget target,
  ToolDescriptor tool,
  ConfigPlatform host,
  Set<ToolId> configuredToolIds,
) {
  if (!targetAppliesToPlatform(target.platform, host)) {
    return OverviewRelevance.otherPlatform;
  }
  if (!configuredToolIds.contains(tool.id)) {
    return OverviewRelevance.notConfigured;
  }
  if (target.optional) return OverviewRelevance.optionalMissing;
  return OverviewRelevance.expectedMissing;
}

/// Assembles the overview model from discovery results and the tool catalog.
///
/// Absent catalog targets are classified by relevance: other-platform and
/// not-configured targets are suppressed by default, while expected and
/// optional targets stay visible. Manual entries with no catalog match are
/// grouped under a trailing "Other" section.
List<ConfigOverviewEntry> buildOverviewModel(
  DiscoveryResult discovery,
  List<ToolDescriptor> catalog, {
  required List<String> projectRoots,
  required ConfigPlatform platform,
  String? homePath,
  String? copilotHome,
}) {
  final normalizedHome = homePath == null ? null : p.normalize(homePath);
  final normalizedRoots = projectRoots.map(p.normalize).toList();
  final discoveredByPath = <String, DiscoveredConfig>{};
  for (final item in discovery.items) {
    discoveredByPath[p.normalize(item.filePath)] = item;
  }

  // A tool "has discovered configuration" when discovery returned at least one
  // descriptor-backed item for it. This is not proof the executable is
  // installed (see the plan's heuristic limitations).
  final configuredToolIds = <ToolId>{};
  for (final item in discovery.items) {
    final tool = item.descriptor;
    if (tool != null && (item.fromCatalog || item.fromManual)) {
      configuredToolIds.add(tool.id);
    }
  }

  final entries = <ConfigOverviewEntry>[];
  final addedPaths = <String>{};

  for (final tool in catalog) {
    for (final target in tool.targets) {
      if (target.relativePath.contains('*')) continue;

      if (target.scope == ConfigLocationScope.user) {
        final expected = RegistryPathMatching.resolveUserTargetPattern(
          normalizedHomePath: normalizedHome,
          relativePath: target.relativePath,
          normalizedCopilotHomePath: copilotHome,
        );
        if (expected == null || !addedPaths.add(expected)) continue;
        final match = discoveredByPath[expected];
        if (match != null) {
          entries.add(
            _entryFromDiscovered(
              match,
              tool,
              normalizedHome,
              copilotHome: copilotHome,
            ),
          );
        } else {
          entries.add(
            _absentEntry(
              tool,
              target,
              expected,
              _classifyAbsent(target, tool, platform, configuredToolIds),
              normalizedHome,
              copilotHome: copilotHome,
            ),
          );
        }
      } else if (target.scope == ConfigLocationScope.project) {
        if (normalizedRoots.isEmpty) continue;
        for (final root in normalizedRoots) {
          final expected = p.normalize(p.join(root, target.relativePath));
          if (!addedPaths.add(expected)) continue;
          final match = discoveredByPath[expected];
          if (match != null) {
            entries.add(
              _entryFromDiscovered(
                match,
                tool,
                normalizedHome,
                root: root,
                copilotHome: copilotHome,
              ),
            );
          } else {
            entries.add(
              _absentEntry(
                tool,
                target,
                expected,
                _classifyAbsent(target, tool, platform, configuredToolIds),
                normalizedHome,
                root: root,
                copilotHome: copilotHome,
              ),
            );
          }
        }
      }
    }
  }

  final otherEntries = <ConfigOverviewEntry>[];
  for (final item in discovery.items) {
    final normalizedPath = p.normalize(item.filePath);
    if (addedPaths.contains(normalizedPath)) continue;

    // Route by catalog match (descriptor), not by provenance flags:
    // discovery merges provenance, so a manually-added path that also
    // matches a catalog target carries both fromManual and fromCatalog.
    // Such items belong to their owning tool, not to Other.
    final tool = item.descriptor;
    if (tool != null && (item.fromCatalog || item.fromManual)) {
      final root = _findProjectRoot(normalizedPath, normalizedRoots);
      entries.add(
        _entryFromDiscovered(
          item,
          tool,
          normalizedHome,
          root: root,
          copilotHome: copilotHome,
        ),
      );
    } else {
      otherEntries.add(
        _entryFromDiscovered(
          item,
          null,
          normalizedHome,
          copilotHome: copilotHome,
        ),
      );
    }
  }
  otherEntries.sort(
    (a, b) => a.displayPath.compareTo(b.displayPath),
  );
  entries
    ..addAll(otherEntries)
    ..sort((a, b) {
      final aToolIndex = _toolIndex(a.toolId, catalog);
      final bToolIndex = _toolIndex(b.toolId, catalog);
      if (aToolIndex != bToolIndex) {
        return aToolIndex.compareTo(bToolIndex);
      }
      final scopeDiff = _scopeOrder(a.scope).compareTo(_scopeOrder(b.scope));
      if (scopeDiff != 0) return scopeDiff;
      return a.displayPath.compareTo(b.displayPath);
    });

  return entries;
}

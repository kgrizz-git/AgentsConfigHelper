import 'dart:io';
import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:path/path.dart' as p;

/// Service responsible for discovering AI agent configuration files
/// on the local filesystem.
class DiscoveryService {
  /// Scans the file system for configuration files based on the given
  /// [request].
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) async {
    final items = <DiscoveredConfig>[];
    final warnings = <DiscoveryWarning>[];
    final seenPaths = <String>{};

    Future<void> addIfValid(
      DiscoveredConfig config, {
      bool isManual = false,
    }) async {
      if (seenPaths.contains(config.filePath)) {
        if (isManual) {
          final existingIndex = items.indexWhere(
            (i) => i.filePath == config.filePath,
          );
          if (existingIndex != -1) {
            items[existingIndex] = items[existingIndex].copyWith(
              isManual: true,
            );
          }
        }
        return;
      }

      final file = File(config.filePath);
      try {
        // Checking file existence asynchronously avoids blocking the UI thread.
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          items.add(config);
          seenPaths.add(config.filePath);
        } else if (isManual) {
          warnings.add(
            DiscoveryWarning(
              path: config.filePath,
              message: 'Manual path does not exist.',
            ),
          );
        }
      } on Object catch (e) {
        warnings.add(
          DiscoveryWarning(
            path: config.filePath,
            message: 'Error accessing file: $e',
          ),
        );
      }
    }

    Future<void> processTarget(
      String expectedPattern,
      ConfigTarget target,
      ToolDescriptor descriptor,
      ConfigLocationScope scope,
    ) async {
      if (!expectedPattern.contains('*')) {
        // Exact match
        final config = DiscoveredConfig.fromPath(
          filePath: expectedPattern,
          scope: scope,
          kind: target.kind,
          format: target.format,
          sourceLabel: descriptor.displayName,
          descriptor: descriptor,
        );
        await addIfValid(config);
      } else {
        // Bounded glob enumeration
        try {
          final dirPath = p.dirname(expectedPattern);
          final dir = Directory(dirPath);
          // Checking directory existence asynchronously avoids blocking
          // the UI thread.
          // ignore: avoid_slow_async_io
          if (!await dir.exists()) return;

          var count = 0;
          var truncated = false;
          const maxEntries = 100;

          await for (final entity in dir.list()) {
            if (entity is File) {
              if (ToolDescriptorRegistry.isMatch(
                expectedPattern,
                entity.path,
              )) {
                final config = DiscoveredConfig.fromPath(
                  filePath: entity.path,
                  scope: scope,
                  kind: target.kind,
                  format: target.format,
                  sourceLabel: descriptor.displayName,
                  descriptor: descriptor,
                );
                await addIfValid(config);
                count++;
                if (count >= maxEntries) {
                  truncated = true;
                  break;
                }
              }
            }
          }

          if (truncated) {
            warnings.add(
              DiscoveryWarning(
                path: expectedPattern,
                message:
                    'Glob enumeration hit the $maxEntries-entry cap; '
                    'some matches may have been omitted.',
              ),
            );
          }
        } on Object catch (e) {
          warnings.add(
            DiscoveryWarning(
              path: expectedPattern,
              message: 'Error enumerating glob target: $e',
            ),
          );
        }
      }
    }

    // 1. User targets
    if (request.normalizedHomePath != null) {
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          if (target.scope == ConfigLocationScope.user) {
            final expectedPattern = p.normalize(
              p.join(request.normalizedHomePath!, target.relativePath),
            );
            await processTarget(
              expectedPattern,
              target,
              descriptor,
              ConfigLocationScope.user,
            );
          }
        }
      }
    }

    // 2. Project targets
    for (final root in request.normalizedProjectRoots) {
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          if (target.scope == ConfigLocationScope.project) {
            final expectedPattern = p.normalize(
              p.join(root, target.relativePath),
            );
            await processTarget(
              expectedPattern,
              target,
              descriptor,
              ConfigLocationScope.project,
            );
          }
        }
      }
    }

    // 3. Manual paths
    for (final manualPath in request.manualPaths) {
      final normalizedPath = p.normalize(manualPath);
      try {
        final match = ToolDescriptorRegistry.matchPath(
          normalizedPath,
          normalizedHomePath: request.normalizedHomePath,
          normalizedProjectRoots: request.normalizedProjectRoots,
        );

        final config = DiscoveredConfig.fromPath(
          filePath: normalizedPath,
          scope: match.scope,
          // match.kind is the kind of the specific target that matched.
          // For unmatched/unknown manual files there's no target at all, so
          // fall back to structuredConfig.
          kind: match.kind ?? ConfigSourceKind.structuredConfig,
          format: match.format,
          sourceLabel: match.sourceLabel,
          descriptor: match.descriptor,
          isManual: true,
        );

        await addIfValid(config, isManual: true);
      } on ValidationException catch (e) {
        warnings.add(
          DiscoveryWarning(
            path: normalizedPath,
            message: e.message,
          ),
        );
      } on Object catch (e) {
        warnings.add(
          DiscoveryWarning(
            path: normalizedPath,
            message: 'Error processing path: $e',
          ),
        );
      }
    }

    return DiscoveryResult(items: items, warnings: warnings);
  }
}

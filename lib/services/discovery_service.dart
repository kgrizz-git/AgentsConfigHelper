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

    // Returns true only when [config] is newly added to [items].
    // When a duplicate path is found, the existing entry's provenance is
    // updated (union) so discovery order does not matter.
    Future<bool> addIfValid(DiscoveredConfig config) async {
      // Dedup by a platform-aware key: case-insensitive on Windows so a manual
      // entry and a catalog target that differ only in case don't produce two
      // sidebar rows for the same file.
      final pathKey = Platform.isWindows
          ? config.filePath.toLowerCase()
          : config.filePath;
      if (seenPaths.contains(pathKey)) {
        // Merge provenance into the existing entry. Scope stays as-is (set
        // from the first match at discovery time).
        final idx = items.indexWhere(
          (item) =>
              (Platform.isWindows
                  ? item.filePath.toLowerCase()
                  : item.filePath) ==
              pathKey,
        );
        // The seenPaths/items invariants are kept in lockstep, but guard
        // defensively so a future divergence is a clean no-op rather than a
        // RangeError.
        if (idx < 0) {
          seenPaths.add(pathKey);
          return false;
        }
        final existing = items[idx];
        // Only provenance flags are passed; id/filePath/kind are unchanged, so
        // copyWith keeps the existing id stable (it re-derives id only when
        // kind/filePath differ). Scope stays as-is from the first match.
        items[idx] = existing.copyWith(
          fromCatalog: existing.fromCatalog || config.fromCatalog,
          fromManual: existing.fromManual || config.fromManual,
        );
        return false;
      }

      final file = File(config.filePath);
      try {
        // Checking file existence asynchronously avoids blocking the UI thread.
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          items.add(config);
          seenPaths.add(pathKey);
          return true;
        } else if (config.fromManual) {
          // File.exists() is false for a directory; report that distinctly so
          // the user isn't told a path that plainly exists "does not exist".
          // ignore: avoid_slow_async_io
          final isDirectory = await Directory(config.filePath).exists();
          warnings.add(
            DiscoveryWarning(
              path: config.filePath,
              message: isDirectory
                  ? 'Manual path is a directory, not a configuration file.'
                  : 'Manual path does not exist.',
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
      return false;
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
          fromCatalog: true,
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
            if (entity is File &&
                ToolDescriptorRegistry.isMatch(expectedPattern, entity.path)) {
              if (count >= maxEntries) {
                // A further matching entry exists beyond the cap, so results
                // are genuinely truncated.
                truncated = true;
                break;
              }
              // Count every matching entry, not just newly-added ones, so the
              // cap bounds the work done per glob even when many matches are
              // duplicates already discovered via another target.
              count++;
              final config = DiscoveredConfig.fromPath(
                filePath: entity.path,
                scope: scope,
                kind: target.kind,
                format: target.format,
                sourceLabel: descriptor.displayName,
                descriptor: descriptor,
                fromCatalog: true,
              );
              await addIfValid(config);
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
          kind: match.kind ?? ConfigSourceKind.structuredConfig,
          format: match.format,
          sourceLabel: match.sourceLabel,
          descriptor: match.descriptor,
          fromManual: true,
        );

        await addIfValid(config);
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

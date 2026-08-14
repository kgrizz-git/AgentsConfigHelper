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
  /// Scans the file system for configuration files based on the given [request].
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
          final existingIndex =
              items.indexWhere((i) => i.filePath == config.filePath);
          if (existingIndex != -1) {
            items[existingIndex] =
                items[existingIndex].copyWith(isManual: true);
          }
        }
        return;
      }

      final file = File(config.filePath);
      try {
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
      } catch (e) {
        warnings.add(
          DiscoveryWarning(
            path: config.filePath,
            message: 'Error accessing file: $e',
          ),
        );
      }
    }

    // 1. User targets
    if (request.normalizedHomePath != null) {
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          if (target.scope == ConfigLocationScope.user) {
            final absolutePath = p.normalize(
              p.join(request.normalizedHomePath!, target.relativePath),
            );
            final config = DiscoveredConfig.fromPath(
              filePath: absolutePath,
              scope: ConfigLocationScope.user,
              kind: target.kind,
              format: target.format,
              sourceLabel: descriptor.displayName,
              descriptor: descriptor,
            );
            await addIfValid(config);
          }
        }
      }
    }

    // 2. Project targets
    for (final root in request.normalizedProjectRoots) {
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          if (target.scope == ConfigLocationScope.project) {
            final absolutePath = p.normalize(p.join(root, target.relativePath));
            final config = DiscoveredConfig.fromPath(
              filePath: absolutePath,
              scope: ConfigLocationScope.project,
              kind: target.kind,
              format: target.format,
              sourceLabel: descriptor.displayName,
              descriptor: descriptor,
            );
            await addIfValid(config);
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
          // Since manual could be unknown, default to structuredConfig if no target gives a specific kind
          kind:
              match.descriptor?.targets
                  .where((t) => t.scope == match.scope)
                  .firstOrNull
                  ?.kind ??
              ConfigSourceKind.structuredConfig,
          format: match.format,
          sourceLabel: match.sourceLabel,
          descriptor: match.descriptor,
        );

        await addIfValid(config, isManual: true);
      } on ValidationException catch (e) {
        warnings.add(
          DiscoveryWarning(
            path: normalizedPath,
            message: e.message,
          ),
        );
      } catch (e) {
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

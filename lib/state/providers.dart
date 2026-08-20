import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/services/home_directory_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// Provides the app's [ConfigService] singleton.
///
/// Must be overridden at app startup with a configured instance; the
/// default implementation throws.
@Riverpod(keepAlive: true)
ConfigService configService(Ref ref) {
  throw UnimplementedError('configService must be overridden');
}

/// Provides a [DiscoveryService] singleton for scanning the filesystem for
/// agent configuration files.
@Riverpod(keepAlive: true)
DiscoveryService discoveryService(Ref ref) {
  return const DiscoveryService();
}

/// Provides the [IDiscoveryPreferencesStore] singleton used to persist
/// manual file paths and project roots.
@Riverpod(keepAlive: true)
IDiscoveryPreferencesStore discoveryPreferencesStore(Ref ref) {
  return DiscoveryPreferencesStore();
}

/// Provides the function used to resolve the current user's home
/// directory.
@Riverpod(keepAlive: true)
String? Function() homeDirectoryResolver(Ref ref) {
  return resolveHomeDirectory;
}

/// Notifier that runs filesystem discovery and exposes the resulting
/// [DiscoveryResult], combining stored preferences (manual paths, project
/// roots) with the resolved home directory.
///
/// Each call to [build] or [refresh] bumps an internal generation
/// counter; if a refresh's result arrives after a newer refresh started
/// (or after the notifier is disposed), it's discarded instead of
/// overwriting fresher state.
@riverpod
class DiscoveryController extends _$DiscoveryController {
  int _generation = 0;
  bool _disposed = false;

  /// Runs discovery once on first read and whenever the provider is
  /// rebuilt.
  @override
  FutureOr<DiscoveryResult> build() async {
    ref.onDispose(() => _disposed = true);
    _generation++;
    return _runDiscovery();
  }

  Future<DiscoveryResult> _runDiscovery() async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    final discoveryService = ref.read(discoveryServiceProvider);

    final prefsResult = await prefsStore.load();
    final prefs = prefsResult.preferences;

    final homeDirRaw = ref.read(homeDirectoryResolverProvider)();
    final homeDir = homeDirRaw != null ? p.normalize(homeDirRaw) : null;

    final copilotHomeRaw = nonEmptyEnvironmentVariable('COPILOT_HOME');
    final copilotHome = absoluteNormalizedPath(copilotHomeRaw);

    final request = DiscoveryRequest(
      normalizedHomePath: homeDir,
      normalizedProjectRoots: prefs.projectRoots,
      manualPaths: prefs.manualFilePaths,
      normalizedCopilotHomePath: copilotHome,
    );

    final result = await discoveryService.discoverConfigs(request);

    final prefsWarnings = [
      for (final w in prefsResult.warnings)
        DiscoveryWarning(path: '', message: w),
    ];

    final warnings = <DiscoveryWarning>[
      ...prefsWarnings,
      ...result.warnings,
    ];

    if (copilotHomeRaw != null && copilotHome == null) {
      warnings.insert(
        0,
        DiscoveryWarning(
          path: copilotHomeRaw,
          message:
              'Ignoring COPILOT_HOME because it is not an absolute path '
              '(got "$copilotHomeRaw").',
        ),
      );
    }

    if (homeDir == null) {
      // Surface this rather than silently skipping all user-scope
      // discovery: an unresolvable home directory otherwise looks
      // identical to "nothing found".
      warnings.insert(
        0,
        DiscoveryWarning(
          path: '',
          message: copilotHome != null
              ? "Could not resolve the user's home directory; non-Copilot "
                    'user-scope configurations were not searched '
                    '(COPILOT_HOME is still searched).'
              : "Could not resolve the user's home directory; user-scope "
                    'configurations were not searched.',
        ),
      );
    }

    return DiscoveryResult(
      items: result.items,
      warnings: warnings,
      projectRoots: prefs.projectRoots,
    );
  }

  /// Re-runs discovery, guarding against stale results: if the notifier
  /// is disposed or a newer [refresh] call starts before this one
  /// finishes, its result is dropped instead of being applied to [state].
  Future<void> refresh() async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    _generation++;
    final currentGen = _generation;
    final result = await AsyncValue.guard(_runDiscovery);
    if (!_disposed && _generation == currentGen) {
      state = result;
    }
  }

  /// Persists [path] as a manual file path, then refreshes discovery
  /// results.
  Future<void> addManualPath(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.addManualPath(path);
    await refresh();
  }

  /// Removes [path] from the manual file paths, then refreshes discovery
  /// results.
  Future<void> removeManualPath(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.removeManualPath(path);
    await refresh();
  }

  /// Persists [path] as a project root, then refreshes discovery results.
  Future<void> addProjectRoot(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.addProjectRoot(path);
    await refresh();
  }

  /// Removes [path] from the project roots, then refreshes discovery
  /// results.
  Future<void> removeProjectRoot(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.removeProjectRoot(path);
    await refresh();
  }
}

/// Provides the list of backups on disk for the config at the given file
/// path, sorted most-recent first.
final AutoDisposeFutureProviderFamily<List<File>, String> backupListProvider =
    FutureProvider.autoDispose.family<List<File>, String>((
      ref,
      filePath,
    ) async {
      final configService = ref.watch(configServiceProvider);
      // The family key stays unresolved (callers pass config.filePath), but
      // resolve `~` before listing so the filenames match those createBackup
      // writes from the resolved path in saveConfig/saveRawConfig.
      final resolvedPath = configService.resolvePath(filePath);
      return configService.backupService.listBackups(resolvedPath);
    });

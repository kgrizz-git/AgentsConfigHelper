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

@Riverpod(keepAlive: true)
ConfigService configService(Ref ref) {
  throw UnimplementedError('configService must be overridden');
}

@Riverpod(keepAlive: true)
DiscoveryService discoveryService(Ref ref) {
  return DiscoveryService();
}

@Riverpod(keepAlive: true)
IDiscoveryPreferencesStore discoveryPreferencesStore(Ref ref) {
  return DiscoveryPreferencesStore();
}

@Riverpod(keepAlive: true)
String? Function() homeDirectoryResolver(Ref ref) {
  return resolveHomeDirectory;
}

@riverpod
class DiscoveryController extends _$DiscoveryController {
  int _generation = 0;

  @override
  FutureOr<DiscoveryResult> build() async {
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

    final request = DiscoveryRequest(
      normalizedHomePath: homeDir,
      normalizedProjectRoots: prefs.projectRoots,
      manualPaths: prefs.manualFilePaths,
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

    if (homeDir == null) {
      // Surface this rather than silently skipping all user-scope
      // discovery: an unresolvable home directory otherwise looks
      // identical to "nothing found".
      warnings.insert(
        0,
        const DiscoveryWarning(
          path: '',
          message:
              "Could not resolve the user's home directory; user-scope "
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

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    _generation++;
    final currentGen = _generation;
    final result = await AsyncValue.guard(_runDiscovery);
    if (_generation == currentGen) {
      state = result;
    }
  }

  Future<void> addManualPath(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.addManualPath(path);
    await refresh();
  }

  Future<void> removeManualPath(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.removeManualPath(path);
    await refresh();
  }

  Future<void> addProjectRoot(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.addProjectRoot(path);
    await refresh();
  }

  Future<void> removeProjectRoot(String path) async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.removeProjectRoot(path);
    await refresh();
  }
}

final FutureProviderFamily<List<File>, String> backupListProvider =
    FutureProvider.family<List<File>, String>((ref, filePath) async {
      final configService = ref.watch(configServiceProvider);
      return configService.backupService.listBackups(filePath);
    });

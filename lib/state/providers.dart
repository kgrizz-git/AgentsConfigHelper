import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
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

    final homeDirRaw =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final homeDir = homeDirRaw != null ? p.normalize(homeDirRaw) : null;

    final request = DiscoveryRequest(
      normalizedHomePath: homeDir,
      normalizedProjectRoots: prefs.projectRoots,
      manualPaths: prefs.manualFilePaths,
    );

    return discoveryService.discoverConfigs(request);
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
    final homeDirRaw =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final homeDir = homeDirRaw != null ? p.normalize(homeDirRaw) : null;
    if (homeDir != null) {
      final normalizedPath = p.normalize(p.absolute(path));
      if (!p.isWithin(homeDir, normalizedPath) &&
          !p.equals(homeDir, normalizedPath)) {
        throw ArgumentError(
          'Manual path must be within the user home directory.',
        );
      }
    }

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

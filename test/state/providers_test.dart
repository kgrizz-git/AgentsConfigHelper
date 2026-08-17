import 'dart:async';
import 'dart:collection';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDiscoveryPreferencesStore implements IDiscoveryPreferencesStore {
  _FakeDiscoveryPreferencesStore({this.loadResults = const []});

  final List<String> addedManualPaths = [];
  final List<DiscoveryPreferencesResult> loadResults;

  int _loadIndex = 0;

  @override
  Future<void> addManualPath(String path) async {
    addedManualPaths.add(path);
  }

  @override
  Future<void> addProjectRoot(String path) async {}

  @override
  Future<DiscoveryPreferencesResult> load() async {
    if (_loadIndex < loadResults.length) {
      return loadResults[_loadIndex++];
    }
    return const DiscoveryPreferencesResult(
      preferences: DiscoveryPreferences(),
    );
  }

  @override
  Future<void> removeManualPath(String path) async {}

  @override
  Future<void> removeProjectRoot(String path) async {}
}

class _FakeDiscoveryService extends DiscoveryService {
  final Queue<Completer<DiscoveryResult>> _completers =
      Queue<Completer<DiscoveryResult>>();
  int callCount = 0;

  void enqueueCompleter(Completer<DiscoveryResult> completer) {
    _completers.add(completer);
  }

  @override
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) {
    callCount++;
    if (_completers.isNotEmpty) {
      return _completers.removeFirst().future;
    }
    return Future.value(const DiscoveryResult(items: []));
  }
}

void main() {
  test(
    'DiscoveryController prevents stale refresh from overwriting newer result',
    () async {
      final fakePrefs = _FakeDiscoveryPreferencesStore();
      final fakeService = _FakeDiscoveryService();

      final container = ProviderContainer(
        overrides: [
          discoveryPreferencesStoreProvider.overrideWithValue(fakePrefs),
          discoveryServiceProvider.overrideWithValue(fakeService),
        ],
      );

      addTearDown(container.dispose);

      // Initial build
      await container.read(discoveryControllerProvider.future);
      expect(fakeService.callCount, 1);

      // Prepare two futures that we will resolve manually in reverse order.
      // Both are enqueued up front so that the two refreshes each consume
      // their own completer (FIFO), regardless of how the async preferences
      // load() interleaves with discoverConfigs().
      final completer1 = Completer<DiscoveryResult>();
      final completer2 = Completer<DiscoveryResult>();
      fakeService
        ..enqueueCompleter(completer1)
        ..enqueueCompleter(completer2);

      final controller = container.read(discoveryControllerProvider.notifier);

      // Trigger refresh 1 (will consume completer1)
      final refresh1 = controller.refresh();

      // Trigger refresh 2 (will consume completer2; this should prevent
      // refresh 1 from overwriting the newer state once it resolves)
      final refresh2 = controller.refresh();

      // Resolve refresh 2 first
      const result2 = DiscoveryResult(items: []);
      completer2.complete(result2);
      await refresh2;

      // Resolve refresh 1 (the stale one) later
      const result1 = DiscoveryResult(
        items: [],
        warnings: [DiscoveryWarning(path: 'fake', message: 'stale')],
      );
      completer1.complete(result1);
      await refresh1;

      // Check final state - it should be the result from refresh2, not refresh1
      final finalState = container.read(discoveryControllerProvider);
      expect(finalState.value, equals(result2));
      expect(
        finalState.value?.warnings,
        isEmpty,
      ); // Should not have the stale warning
      expect(
        fakeService.callCount,
        3,
      ); // initial build + two refreshes
    },
  );

  test(
    'DiscoveryController.addManualPath accepts path outside home directory',
    () async {
      final fakePrefs = _FakeDiscoveryPreferencesStore();
      final fakeService = _FakeDiscoveryService();

      final container = ProviderContainer(
        overrides: [
          discoveryPreferencesStoreProvider.overrideWithValue(fakePrefs),
          discoveryServiceProvider.overrideWithValue(fakeService),
          homeDirectoryResolverProvider.overrideWithValue(
            () => '/tmp/fake-home',
          ),
        ],
      );

      addTearDown(container.dispose);

      final controller = container.read(discoveryControllerProvider.notifier);
      await controller.addManualPath('/tmp/somewhere-else/config.json');

      expect(fakePrefs.addedManualPaths, ['/tmp/somewhere-else/config.json']);
    },
  );

  test(
    'DiscoveryController merges preference-store warnings into DiscoveryResult',
    () async {
      final fakePrefs = _FakeDiscoveryPreferencesStore(
        loadResults: [
          const DiscoveryPreferencesResult(
            preferences: DiscoveryPreferences(),
            warnings: [
              "Removed duplicate or empty paths from 'manualFilePaths'.",
              "Ignored non-absolute path: 'relative/path'",
            ],
          ),
        ],
      );
      final fakeService = _FakeDiscoveryService();

      final container = ProviderContainer(
        overrides: [
          discoveryPreferencesStoreProvider.overrideWithValue(fakePrefs),
          discoveryServiceProvider.overrideWithValue(fakeService),
        ],
      );

      addTearDown(container.dispose);

      final result = await container.read(discoveryControllerProvider.future);

      expect(result.warnings.length, 2);
      expect(result.warnings[0].path, '');
      expect(
        result.warnings[0].message,
        "Removed duplicate or empty paths from 'manualFilePaths'.",
      );
      expect(result.warnings[1].path, '');
      expect(
        result.warnings[1].message,
        "Ignored non-absolute path: 'relative/path'",
      );
    },
  );

  test(
    'DiscoveryController surfaces a warning when the home directory '
    "can't be resolved, instead of silently skipping user-scope discovery",
    () async {
      final fakePrefs = _FakeDiscoveryPreferencesStore();
      final fakeService = _FakeDiscoveryService();

      final container = ProviderContainer(
        overrides: [
          discoveryPreferencesStoreProvider.overrideWithValue(fakePrefs),
          discoveryServiceProvider.overrideWithValue(fakeService),
          homeDirectoryResolverProvider.overrideWithValue(() => null),
        ],
      );

      addTearDown(container.dispose);

      final result = await container.read(discoveryControllerProvider.future);

      expect(
        result.warnings.any((w) => w.message.contains('home directory')),
        isTrue,
      );
    },
  );
}

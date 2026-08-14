import 'dart:async';
import 'dart:io';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDiscoveryPreferencesStore implements IDiscoveryPreferencesStore {
  @override
  Future<void> addManualPath(String path) async {}

  @override
  Future<void> addProjectRoot(String path) async {}

  @override
  Future<DiscoveryPreferencesResult> load() async {
    return const DiscoveryPreferencesResult(
      preferences: DiscoveryPreferences(

      ),
    );
  }

  @override
  Future<void> removeManualPath(String path) async {}

  @override
  Future<void> removeProjectRoot(String path) async {}
}

class _FakeDiscoveryService extends DiscoveryService {
  Completer<DiscoveryResult>? completer;
  int callCount = 0;

  @override
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) {
    callCount++;
    if (completer != null) {
      return completer!.future;
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

      // Prepare two futures that we will resolve manually in reverse order
      final completer1 = Completer<DiscoveryResult>();
      final completer2 = Completer<DiscoveryResult>();

      final controller = container.read(discoveryControllerProvider.notifier);

      // Trigger refresh 1
      fakeService.completer = completer1;
      final refresh1 = controller.refresh();

      // Trigger refresh 2 (this should cancel refresh 1 from updating state)
      fakeService.completer = completer2;
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
    },
  );

  test(
    'DiscoveryController.addManualPath throws if path is outside home directory',
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

      final controller = container.read(discoveryControllerProvider.notifier);

      // Usually /tmp or /var is outside home. On Windows it could be C:\temp.
      const outsidePath =
          r'C:\temp\file.json'; // Hardcode some clearly non-home paths for testing
      const outsidePathUnix = '/tmp/file.json';

      final homeDirRaw =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDirRaw != null) {
        expect(
          () => controller.addManualPath(
            Platform.environment['HOME'] != null
                ? outsidePathUnix
                : outsidePath,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    },
  );
}

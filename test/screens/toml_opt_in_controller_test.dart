import 'dart:async';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/screens/toml_opt_in_controller.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubStore implements IDiscoveryPreferencesStore {
  _StubStore({required this.persisted});

  bool persisted;
  Completer<DiscoveryPreferencesResult>? loadGate;

  @override
  Future<DiscoveryPreferencesResult> load() {
    if (loadGate != null) return loadGate!.future;
    return Future.value(
      DiscoveryPreferencesResult(
        preferences: DiscoveryPreferences(tomlStructuredSaveEnabled: persisted),
      ),
    );
  }

  @override
  Future<void> enableTomlStructuredSave() async => persisted = true;

  @override
  Future<void> disableTomlStructuredSave() async => persisted = false;

  @override
  Future<void> addManualPath(String path) async {}

  @override
  Future<void> removeManualPath(String path) async {}

  @override
  Future<void> addProjectRoot(String path) async {}

  @override
  Future<void> removeProjectRoot(String path) async {}
}

void main() {
  test('in-flight load cannot overwrite a newer enable', () async {
    final store = _StubStore(persisted: false)..loadGate = Completer();
    var mounted = true;
    final controller = TomlOptInController(
      store: store,
      isMounted: () => mounted,
      setState: (fn) => fn(),
    );

    // load() begins and stays in flight, holding the stale value false.
    final loadFuture = controller.load();

    // A user opts in while the original load is still pending.
    await controller.enable();
    expect(controller.tomlStructuredSaveEnabled, isTrue);

    // The stale load completes afterwards with the old false value; it must
    // not clobber the enable.
    store.loadGate!.complete(
      const DiscoveryPreferencesResult(
        preferences: DiscoveryPreferences(),
      ),
    );
    await loadFuture;

    expect(controller.tomlStructuredSaveEnabled, isTrue);
    mounted = false;
  });

  test('load applies when no newer operation intervened', () async {
    final store = _StubStore(persisted: true);
    var mounted = true;
    final controller = TomlOptInController(
      store: store,
      isMounted: () => mounted,
      setState: (fn) => fn(),
    );

    await controller.load();

    expect(controller.tomlStructuredSaveEnabled, isTrue);
    mounted = false;
  });
}

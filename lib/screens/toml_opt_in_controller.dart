import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:flutter/widgets.dart';

/// Owns the persisted TOML structured-save opt-in for the main shell.
class TomlOptInController {
  /// Creates a controller bound to [store].
  ///
  /// [isMounted] must report the owner's live mounted state; it is consulted
  /// after each await so no `setState` runs on an unmounted widget.
  /// [setState] forwards to the owner's `State.setState`.
  TomlOptInController({
    required this.store,
    required this.isMounted,
    required this.setState,
  });

  /// The preferences store that persists the opt-in.
  final IDiscoveryPreferencesStore store;

  /// Live mounted check for the owning widget.
  final bool Function() isMounted;

  /// Forwards state updates to the owning widget.
  final void Function(VoidCallback fn) setState;

  bool _tomlStructuredSaveEnabled = false;
  int _generation = 0;

  /// Whether the user has opted in to lossy structured TOML saves.
  bool get tomlStructuredSaveEnabled => _tomlStructuredSaveEnabled;

  /// Loads the persisted opt-in value.
  Future<void> load() async {
    final generation = ++_generation;
    final result = await store.load();
    // Ignore a stale load that began before a newer enable()/disable() so it
    // cannot overwrite the more recent decision.
    if (isMounted() && generation == _generation) {
      setState(() {
        _tomlStructuredSaveEnabled =
            result.preferences.tomlStructuredSaveEnabled;
      });
    }
  }

  /// Persists the opt-in and reflects it locally.
  Future<void> enable() async {
    _generation++;
    await store.enableTomlStructuredSave();
    if (isMounted()) {
      setState(() {
        _tomlStructuredSaveEnabled = true;
      });
    }
  }

  /// Clears the persisted opt-in and reflects it locally.
  Future<void> disable() async {
    _generation++;
    await store.disableTomlStructuredSave();
    if (isMounted()) {
      setState(() {
        _tomlStructuredSaveEnabled = false;
      });
    }
  }
}

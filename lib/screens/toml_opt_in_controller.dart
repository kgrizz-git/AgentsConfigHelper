import 'package:agents_config_helper/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the persisted TOML structured-save opt-in for the main shell.
class TomlOptInController {
  /// Creates a controller bound to [ref].
  ///
  /// [isMounted] must report the owner's live mounted state; it is consulted
  /// after each await so no `setState` runs on an unmounted widget.
  /// [setState] forwards to the owner's `State.setState`.
  TomlOptInController({
    required this.ref,
    required this.isMounted,
    required this.setState,
  });

  /// Provider scope used to read the preferences store.
  final WidgetRef ref;

  /// Live mounted check for the owning widget.
  final bool Function() isMounted;

  /// Forwards state updates to the owning widget.
  final void Function(VoidCallback fn) setState;

  bool _tomlStructuredSaveEnabled = false;

  /// Whether the user has opted in to lossy structured TOML saves.
  bool get tomlStructuredSaveEnabled => _tomlStructuredSaveEnabled;

  /// Loads the persisted opt-in value.
  Future<void> load() async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    final result = await prefsStore.load();
    if (isMounted()) {
      setState(() {
        _tomlStructuredSaveEnabled =
            result.preferences.tomlStructuredSaveEnabled;
      });
    }
  }

  /// Persists the opt-in and reflects it locally.
  Future<void> enable() async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.enableTomlStructuredSave();
    if (isMounted()) {
      setState(() {
        _tomlStructuredSaveEnabled = true;
      });
    }
  }

  /// Clears the persisted opt-in and reflects it locally.
  Future<void> disable() async {
    final prefsStore = ref.read(discoveryPreferencesStoreProvider);
    await prefsStore.disableTomlStructuredSave();
    if (isMounted()) {
      setState(() {
        _tomlStructuredSaveEnabled = false;
      });
    }
  }
}

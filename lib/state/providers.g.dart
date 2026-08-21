// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app's [ConfigService] singleton.
///
/// Must be overridden at app startup with a configured instance; the
/// default implementation throws.

@ProviderFor(configService)
final configServiceProvider = ConfigServiceProvider._();

/// Provides the app's [ConfigService] singleton.
///
/// Must be overridden at app startup with a configured instance; the
/// default implementation throws.

final class ConfigServiceProvider
    extends $FunctionalProvider<ConfigService, ConfigService, ConfigService>
    with $Provider<ConfigService> {
  /// Provides the app's [ConfigService] singleton.
  ///
  /// Must be overridden at app startup with a configured instance; the
  /// default implementation throws.
  ConfigServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'configServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$configServiceHash();

  @$internal
  @override
  $ProviderElement<ConfigService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConfigService create(Ref ref) {
    return configService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConfigService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConfigService>(value),
    );
  }
}

String _$configServiceHash() => r'146854e6d02f074cbe54a30bbeed2b02895be50c';

/// Provides a [DiscoveryService] singleton for scanning the filesystem for
/// agent configuration files.

@ProviderFor(discoveryService)
final discoveryServiceProvider = DiscoveryServiceProvider._();

/// Provides a [DiscoveryService] singleton for scanning the filesystem for
/// agent configuration files.

final class DiscoveryServiceProvider
    extends
        $FunctionalProvider<
          DiscoveryService,
          DiscoveryService,
          DiscoveryService
        >
    with $Provider<DiscoveryService> {
  /// Provides a [DiscoveryService] singleton for scanning the filesystem for
  /// agent configuration files.
  DiscoveryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryServiceHash();

  @$internal
  @override
  $ProviderElement<DiscoveryService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiscoveryService create(Ref ref) {
    return discoveryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryService>(value),
    );
  }
}

String _$discoveryServiceHash() => r'd9621d71a9e185f83db077121a43ef9e689a8282';

/// Provides the [IDiscoveryPreferencesStore] singleton used to persist
/// manual file paths and project roots.

@ProviderFor(discoveryPreferencesStore)
final discoveryPreferencesStoreProvider = DiscoveryPreferencesStoreProvider._();

/// Provides the [IDiscoveryPreferencesStore] singleton used to persist
/// manual file paths and project roots.

final class DiscoveryPreferencesStoreProvider
    extends
        $FunctionalProvider<
          IDiscoveryPreferencesStore,
          IDiscoveryPreferencesStore,
          IDiscoveryPreferencesStore
        >
    with $Provider<IDiscoveryPreferencesStore> {
  /// Provides the [IDiscoveryPreferencesStore] singleton used to persist
  /// manual file paths and project roots.
  DiscoveryPreferencesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryPreferencesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryPreferencesStoreHash();

  @$internal
  @override
  $ProviderElement<IDiscoveryPreferencesStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IDiscoveryPreferencesStore create(Ref ref) {
    return discoveryPreferencesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IDiscoveryPreferencesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IDiscoveryPreferencesStore>(value),
    );
  }
}

String _$discoveryPreferencesStoreHash() =>
    r'601f5bcf186772ead71199d94b72c3cfe29168cc';

/// Provides the function used to resolve the current user's home
/// directory.

@ProviderFor(homeDirectoryResolver)
final homeDirectoryResolverProvider = HomeDirectoryResolverProvider._();

/// Provides the function used to resolve the current user's home
/// directory.

final class HomeDirectoryResolverProvider
    extends
        $FunctionalProvider<
          String? Function(),
          String? Function(),
          String? Function()
        >
    with $Provider<String? Function()> {
  /// Provides the function used to resolve the current user's home
  /// directory.
  HomeDirectoryResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeDirectoryResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeDirectoryResolverHash();

  @$internal
  @override
  $ProviderElement<String? Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String? Function() create(Ref ref) {
    return homeDirectoryResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String? Function()>(value),
    );
  }
}

String _$homeDirectoryResolverHash() =>
    r'e9a4d34bf4cdfc4b3911dcba77750cd028d28afc';

/// Notifier that runs filesystem discovery and exposes the resulting
/// [DiscoveryResult], combining stored preferences (manual paths, project
/// roots) with the resolved home directory.
///
/// Each call to [build] or [refresh] bumps an internal generation
/// counter; if a refresh's result arrives after a newer refresh started
/// (or after the notifier is disposed), it's discarded instead of
/// overwriting fresher state.

@ProviderFor(DiscoveryController)
final discoveryControllerProvider = DiscoveryControllerProvider._();

/// Notifier that runs filesystem discovery and exposes the resulting
/// [DiscoveryResult], combining stored preferences (manual paths, project
/// roots) with the resolved home directory.
///
/// Each call to [build] or [refresh] bumps an internal generation
/// counter; if a refresh's result arrives after a newer refresh started
/// (or after the notifier is disposed), it's discarded instead of
/// overwriting fresher state.
final class DiscoveryControllerProvider
    extends $AsyncNotifierProvider<DiscoveryController, DiscoveryResult> {
  /// Notifier that runs filesystem discovery and exposes the resulting
  /// [DiscoveryResult], combining stored preferences (manual paths, project
  /// roots) with the resolved home directory.
  ///
  /// Each call to [build] or [refresh] bumps an internal generation
  /// counter; if a refresh's result arrives after a newer refresh started
  /// (or after the notifier is disposed), it's discarded instead of
  /// overwriting fresher state.
  DiscoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryControllerHash();

  @$internal
  @override
  DiscoveryController create() => DiscoveryController();
}

String _$discoveryControllerHash() =>
    r'932135d09cc8d44f36d34ba1dace96c137e2e045';

/// Notifier that runs filesystem discovery and exposes the resulting
/// [DiscoveryResult], combining stored preferences (manual paths, project
/// roots) with the resolved home directory.
///
/// Each call to [build] or [refresh] bumps an internal generation
/// counter; if a refresh's result arrives after a newer refresh started
/// (or after the notifier is disposed), it's discarded instead of
/// overwriting fresher state.

abstract class _$DiscoveryController extends $AsyncNotifier<DiscoveryResult> {
  FutureOr<DiscoveryResult> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DiscoveryResult>, DiscoveryResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DiscoveryResult>, DiscoveryResult>,
              AsyncValue<DiscoveryResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$configServiceHash() => r'146854e6d02f074cbe54a30bbeed2b02895be50c';

/// See also [configService].
@ProviderFor(configService)
final configServiceProvider = Provider<ConfigService>.internal(
  configService,
  name: r'configServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$configServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConfigServiceRef = ProviderRef<ConfigService>;
String _$discoveryServiceHash() => r'cc7a0330a7ed7ae698a3c87dc3f691903d2a1a52';

/// See also [discoveryService].
@ProviderFor(discoveryService)
final discoveryServiceProvider = Provider<DiscoveryService>.internal(
  discoveryService,
  name: r'discoveryServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$discoveryServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DiscoveryServiceRef = ProviderRef<DiscoveryService>;
String _$discoveryPreferencesStoreHash() =>
    r'601f5bcf186772ead71199d94b72c3cfe29168cc';

/// See also [discoveryPreferencesStore].
@ProviderFor(discoveryPreferencesStore)
final discoveryPreferencesStoreProvider =
    Provider<IDiscoveryPreferencesStore>.internal(
      discoveryPreferencesStore,
      name: r'discoveryPreferencesStoreProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$discoveryPreferencesStoreHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DiscoveryPreferencesStoreRef = ProviderRef<IDiscoveryPreferencesStore>;
String _$homeDirectoryResolverHash() =>
    r'e9a4d34bf4cdfc4b3911dcba77750cd028d28afc';

/// See also [homeDirectoryResolver].
@ProviderFor(homeDirectoryResolver)
final homeDirectoryResolverProvider = Provider<String? Function()>.internal(
  homeDirectoryResolver,
  name: r'homeDirectoryResolverProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeDirectoryResolverHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeDirectoryResolverRef = ProviderRef<String? Function()>;
String _$discoveryControllerHash() =>
    r'9b35f02ba7109a879382e4cf20f024f76831caa0';

/// See also [DiscoveryController].
@ProviderFor(DiscoveryController)
final discoveryControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      DiscoveryController,
      DiscoveryResult
    >.internal(
      DiscoveryController.new,
      name: r'discoveryControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$discoveryControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DiscoveryController = AutoDisposeAsyncNotifier<DiscoveryResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

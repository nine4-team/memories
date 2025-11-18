// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$useNewDictationPluginHash() =>
    r'6d1ffd1326281c31cb9285397dc2e2d47526e2c6';

/// Feature flag for the new dictation plugin behavior
///
/// When enabled, uses the latest plugin build that surfaces raw-audio references
/// along with streaming transcripts/event channels.
///
/// Default: false (legacy behavior) for QA comparison before broad rollout.
///
/// Copied from [useNewDictationPlugin].
@ProviderFor(useNewDictationPlugin)
final useNewDictationPluginProvider = AutoDisposeFutureProvider<bool>.internal(
  useNewDictationPlugin,
  name: r'useNewDictationPluginProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$useNewDictationPluginHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UseNewDictationPluginRef = AutoDisposeFutureProviderRef<bool>;
String _$useNewDictationPluginSyncHash() =>
    r'cc16d79871436fcd1b059e605be46c14df64aa60';

/// Synchronous provider that watches the async feature flag
/// Returns false if the async provider is loading or has an error
///
/// Copied from [useNewDictationPluginSync].
@ProviderFor(useNewDictationPluginSync)
final useNewDictationPluginSyncProvider = AutoDisposeProvider<bool>.internal(
  useNewDictationPluginSync,
  name: r'useNewDictationPluginSyncProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$useNewDictationPluginSyncHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UseNewDictationPluginSyncRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

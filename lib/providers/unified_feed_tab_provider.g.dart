// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_feed_tab_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unifiedFeedTabPersistenceServiceHash() =>
    r'5e6e7d80a446e2df5e03bdf2dcae456ab6cef430';

/// Provider for unified feed tab persistence service
///
/// Copied from [unifiedFeedTabPersistenceService].
@ProviderFor(unifiedFeedTabPersistenceService)
final unifiedFeedTabPersistenceServiceProvider =
    AutoDisposeProvider<UnifiedFeedTabPersistenceService>.internal(
  unifiedFeedTabPersistenceService,
  name: r'unifiedFeedTabPersistenceServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unifiedFeedTabPersistenceServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnifiedFeedTabPersistenceServiceRef
    = AutoDisposeProviderRef<UnifiedFeedTabPersistenceService>;
String _$unifiedFeedTabNotifierHash() =>
    r'5c95abe4b815fabbfe5ceade68122808d386bfc6';

/// Provider for the selected tab in unified feed
///
/// Manages the current filter selection and persists it to SharedPreferences.
/// null represents 'all' (no filter).
///
/// Copied from [UnifiedFeedTabNotifier].
@ProviderFor(UnifiedFeedTabNotifier)
final unifiedFeedTabNotifierProvider = AutoDisposeAsyncNotifierProvider<
    UnifiedFeedTabNotifier, MemoryType?>.internal(
  UnifiedFeedTabNotifier.new,
  name: r'unifiedFeedTabNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unifiedFeedTabNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UnifiedFeedTabNotifier = AutoDisposeAsyncNotifier<MemoryType?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$timelineFeedNotifierHash() =>
    r'4807a3965a384de382508fc5b4b60886dc34e4d5';

/// Provider for timeline feed state
///
/// Copied from [TimelineFeedNotifier].
@ProviderFor(TimelineFeedNotifier)
final timelineFeedNotifierProvider = AutoDisposeNotifierProvider<
    TimelineFeedNotifier, TimelineFeedState>.internal(
  TimelineFeedNotifier.new,
  name: r'timelineFeedNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$timelineFeedNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TimelineFeedNotifier = AutoDisposeNotifier<TimelineFeedState>;
String _$searchQueryNotifierHash() =>
    r'6c4e2efd14702a28cc5c72ed1f86af21f16b333a';

/// Provider for search query state
///
/// Copied from [SearchQueryNotifier].
@ProviderFor(SearchQueryNotifier)
final searchQueryNotifierProvider =
    AutoDisposeNotifierProvider<SearchQueryNotifier, String>.internal(
  SearchQueryNotifier.new,
  name: r'searchQueryNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchQueryNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchQueryNotifier = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

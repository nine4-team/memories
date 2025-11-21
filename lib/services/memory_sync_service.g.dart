// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memorySyncServiceHash() => r'91b4e05d63ab65fad8ad653806873092aa9a5ac2';

/// Service for syncing queued memories (moments, mementos, and stories) to the server
///
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the unified offline memory queue.
///
/// Copied from [memorySyncService].
@ProviderFor(memorySyncService)
final memorySyncServiceProvider =
    AutoDisposeProvider<MemorySyncService>.internal(
  memorySyncService,
  name: r'memorySyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memorySyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MemorySyncServiceRef = AutoDisposeProviderRef<MemorySyncService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

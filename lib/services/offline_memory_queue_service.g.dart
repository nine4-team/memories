// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_memory_queue_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineMemoryQueueServiceHash() =>
    r'87fc01e81745ee9df1e5cc8dd05589468fa47b47';

/// Service for managing offline queue of all memory types (moments, mementos, and stories)
///
/// Unified service that replaces OfflineQueueService and OfflineStoryQueueService.
/// All memory types are stored in a single queue since they share the same save pipeline.
/// The memory type is tracked via the QueuedMemory.memoryType field.
///
/// Copied from [offlineMemoryQueueService].
@ProviderFor(offlineMemoryQueueService)
final offlineMemoryQueueServiceProvider =
    AutoDisposeProvider<OfflineMemoryQueueService>.internal(
  offlineMemoryQueueService,
  name: r'offlineMemoryQueueServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineMemoryQueueServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineMemoryQueueServiceRef
    = AutoDisposeProviderRef<OfflineMemoryQueueService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

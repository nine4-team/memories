// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queueStatusHash() => r'05f35c040a3fd1d17d1c7d49e051cdfd3b3e1a63';

/// Provider that watches queue status for UI display
///
/// Includes moments, mementos, and stories in the queue status.
/// All memory types are stored in the unified OfflineMemoryQueueService.
///
/// Copied from [queueStatus].
@ProviderFor(queueStatus)
final queueStatusProvider = AutoDisposeFutureProvider<QueueStatusData>.internal(
  queueStatus,
  name: r'queueStatusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$queueStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef QueueStatusRef = AutoDisposeFutureProviderRef<QueueStatusData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

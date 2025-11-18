// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queueStatusHash() => r'28523158131682bf11938d3d1089983f2fdc8854';

/// Provider that watches queue status for UI display
///
/// Includes moments, mementos, and stories in the queue status.
/// Note: Mementos are stored in the same queue as moments (OfflineQueueService),
/// so they are included in the moment queue counts.
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

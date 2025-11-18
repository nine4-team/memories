// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_queue_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineQueueServiceHash() =>
    r'3d43befb266fef7cba4e17ce61cfc9ab365c7975';

/// Service for managing offline queue of moments and mementos
///
/// Both moments and mementos are stored in the same queue since they share
/// the same save pipeline and data structure. The memory type is tracked
/// via the QueuedMoment.memoryType field.
///
/// Copied from [offlineQueueService].
@ProviderFor(offlineQueueService)
final offlineQueueServiceProvider =
    AutoDisposeProvider<OfflineQueueService>.internal(
  offlineQueueService,
  name: r'offlineQueueServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineQueueServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineQueueServiceRef = AutoDisposeProviderRef<OfflineQueueService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

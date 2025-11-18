// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_story_queue_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineStoryQueueServiceHash() =>
    r'c1c7d1e508412b01a42fd2eafe6f810b782f6a5c';

/// Service for managing offline queue of stories
///
/// Stories include audio recordings that need to be uploaded along with
/// transcripts and media attachments. This service handles local persistence
/// using SharedPreferences with JSON serialization, following the same pattern
/// as OfflineQueueService for moments.
///
/// Copied from [offlineStoryQueueService].
@ProviderFor(offlineStoryQueueService)
final offlineStoryQueueServiceProvider =
    AutoDisposeProvider<OfflineStoryQueueService>.internal(
  offlineStoryQueueService,
  name: r'offlineStoryQueueServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineStoryQueueServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineStoryQueueServiceRef
    = AutoDisposeProviderRef<OfflineStoryQueueService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

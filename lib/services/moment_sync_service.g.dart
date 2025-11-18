// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$momentSyncServiceHash() => r'f2193e71ca69ad7f2ba631935a36f1d5c9b5042a';

/// Service for syncing queued moments and mementos to the server
///
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the offline queue (moments and mementos).
///
/// Copied from [momentSyncService].
@ProviderFor(momentSyncService)
final momentSyncServiceProvider =
    AutoDisposeProvider<MomentSyncService>.internal(
  momentSyncService,
  name: r'momentSyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$momentSyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MomentSyncServiceRef = AutoDisposeProviderRef<MomentSyncService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

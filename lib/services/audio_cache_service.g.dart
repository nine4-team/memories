// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_cache_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioCacheServiceHash() => r'73c871092af08abd91cd7cfda2a72dc30b60cdc3';

/// Service for managing audio file cache and lifecycle
///
/// Handles:
/// - Storing audio files in a cache directory with durability guarantees
/// - Cleaning up temporary files on cancel/discard flows
/// - Reusing audio files when retries occur (no duplicate recordings)
/// - Managing file lifecycle to prevent storage leaks
///
/// Copied from [audioCacheService].
@ProviderFor(audioCacheService)
final audioCacheServiceProvider =
    AutoDisposeProvider<AudioCacheService>.internal(
  audioCacheService,
  name: r'audioCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioCacheServiceRef = AutoDisposeProviderRef<AudioCacheService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

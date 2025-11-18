// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unifiedFeedRepositoryHash() =>
    r'e15ed59f07787d7199be9be858311e2465a37571';

/// Provider for unified feed repository
///
/// Copied from [unifiedFeedRepository].
@ProviderFor(unifiedFeedRepository)
final unifiedFeedRepositoryProvider =
    AutoDisposeProvider<UnifiedFeedRepository>.internal(
  unifiedFeedRepository,
  name: r'unifiedFeedRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unifiedFeedRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnifiedFeedRepositoryRef
    = AutoDisposeProviderRef<UnifiedFeedRepository>;
String _$unifiedFeedControllerHash() =>
    r'f5b5234b0dd491ec38f4743b377de404dc8744df';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$UnifiedFeedController
    extends BuildlessAutoDisposeNotifier<UnifiedFeedViewState> {
  late final MemoryType? memoryTypeFilter;

  UnifiedFeedViewState build([
    MemoryType? memoryTypeFilter,
  ]);
}

/// Provider for unified feed state
///
/// [memoryTypeFilter] is the filter to apply (null for 'all')
///
/// Copied from [UnifiedFeedController].
@ProviderFor(UnifiedFeedController)
const unifiedFeedControllerProvider = UnifiedFeedControllerFamily();

/// Provider for unified feed state
///
/// [memoryTypeFilter] is the filter to apply (null for 'all')
///
/// Copied from [UnifiedFeedController].
class UnifiedFeedControllerFamily extends Family<UnifiedFeedViewState> {
  /// Provider for unified feed state
  ///
  /// [memoryTypeFilter] is the filter to apply (null for 'all')
  ///
  /// Copied from [UnifiedFeedController].
  const UnifiedFeedControllerFamily();

  /// Provider for unified feed state
  ///
  /// [memoryTypeFilter] is the filter to apply (null for 'all')
  ///
  /// Copied from [UnifiedFeedController].
  UnifiedFeedControllerProvider call([
    MemoryType? memoryTypeFilter,
  ]) {
    return UnifiedFeedControllerProvider(
      memoryTypeFilter,
    );
  }

  @override
  UnifiedFeedControllerProvider getProviderOverride(
    covariant UnifiedFeedControllerProvider provider,
  ) {
    return call(
      provider.memoryTypeFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'unifiedFeedControllerProvider';
}

/// Provider for unified feed state
///
/// [memoryTypeFilter] is the filter to apply (null for 'all')
///
/// Copied from [UnifiedFeedController].
class UnifiedFeedControllerProvider extends AutoDisposeNotifierProviderImpl<
    UnifiedFeedController, UnifiedFeedViewState> {
  /// Provider for unified feed state
  ///
  /// [memoryTypeFilter] is the filter to apply (null for 'all')
  ///
  /// Copied from [UnifiedFeedController].
  UnifiedFeedControllerProvider([
    MemoryType? memoryTypeFilter,
  ]) : this._internal(
          () => UnifiedFeedController()..memoryTypeFilter = memoryTypeFilter,
          from: unifiedFeedControllerProvider,
          name: r'unifiedFeedControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unifiedFeedControllerHash,
          dependencies: UnifiedFeedControllerFamily._dependencies,
          allTransitiveDependencies:
              UnifiedFeedControllerFamily._allTransitiveDependencies,
          memoryTypeFilter: memoryTypeFilter,
        );

  UnifiedFeedControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.memoryTypeFilter,
  }) : super.internal();

  final MemoryType? memoryTypeFilter;

  @override
  UnifiedFeedViewState runNotifierBuild(
    covariant UnifiedFeedController notifier,
  ) {
    return notifier.build(
      memoryTypeFilter,
    );
  }

  @override
  Override overrideWith(UnifiedFeedController Function() create) {
    return ProviderOverride(
      origin: this,
      override: UnifiedFeedControllerProvider._internal(
        () => create()..memoryTypeFilter = memoryTypeFilter,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        memoryTypeFilter: memoryTypeFilter,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<UnifiedFeedController,
      UnifiedFeedViewState> createElement() {
    return _UnifiedFeedControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnifiedFeedControllerProvider &&
        other.memoryTypeFilter == memoryTypeFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, memoryTypeFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UnifiedFeedControllerRef
    on AutoDisposeNotifierProviderRef<UnifiedFeedViewState> {
  /// The parameter `memoryTypeFilter` of this provider.
  MemoryType? get memoryTypeFilter;
}

class _UnifiedFeedControllerProviderElement
    extends AutoDisposeNotifierProviderElement<UnifiedFeedController,
        UnifiedFeedViewState> with UnifiedFeedControllerRef {
  _UnifiedFeedControllerProviderElement(super.provider);

  @override
  MemoryType? get memoryTypeFilter =>
      (origin as UnifiedFeedControllerProvider).memoryTypeFilter;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timeline_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$timelineFeedNotifierHash() =>
    r'1fc5f411373cd3e08b6e5f83235664ad69e88453';

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

abstract class _$TimelineFeedNotifier
    extends BuildlessAutoDisposeNotifier<TimelineFeedState> {
  late final MemoryType? memoryType;

  TimelineFeedState build([
    MemoryType? memoryType,
  ]);
}

/// Provider for timeline feed state with optional memory type filtering
///
/// Copied from [TimelineFeedNotifier].
@ProviderFor(TimelineFeedNotifier)
const timelineFeedNotifierProvider = TimelineFeedNotifierFamily();

/// Provider for timeline feed state with optional memory type filtering
///
/// Copied from [TimelineFeedNotifier].
class TimelineFeedNotifierFamily extends Family<TimelineFeedState> {
  /// Provider for timeline feed state with optional memory type filtering
  ///
  /// Copied from [TimelineFeedNotifier].
  const TimelineFeedNotifierFamily();

  /// Provider for timeline feed state with optional memory type filtering
  ///
  /// Copied from [TimelineFeedNotifier].
  TimelineFeedNotifierProvider call([
    MemoryType? memoryType,
  ]) {
    return TimelineFeedNotifierProvider(
      memoryType,
    );
  }

  @override
  TimelineFeedNotifierProvider getProviderOverride(
    covariant TimelineFeedNotifierProvider provider,
  ) {
    return call(
      provider.memoryType,
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
  String? get name => r'timelineFeedNotifierProvider';
}

/// Provider for timeline feed state with optional memory type filtering
///
/// Copied from [TimelineFeedNotifier].
class TimelineFeedNotifierProvider extends AutoDisposeNotifierProviderImpl<
    TimelineFeedNotifier, TimelineFeedState> {
  /// Provider for timeline feed state with optional memory type filtering
  ///
  /// Copied from [TimelineFeedNotifier].
  TimelineFeedNotifierProvider([
    MemoryType? memoryType,
  ]) : this._internal(
          () => TimelineFeedNotifier()..memoryType = memoryType,
          from: timelineFeedNotifierProvider,
          name: r'timelineFeedNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$timelineFeedNotifierHash,
          dependencies: TimelineFeedNotifierFamily._dependencies,
          allTransitiveDependencies:
              TimelineFeedNotifierFamily._allTransitiveDependencies,
          memoryType: memoryType,
        );

  TimelineFeedNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.memoryType,
  }) : super.internal();

  final MemoryType? memoryType;

  @override
  TimelineFeedState runNotifierBuild(
    covariant TimelineFeedNotifier notifier,
  ) {
    return notifier.build(
      memoryType,
    );
  }

  @override
  Override overrideWith(TimelineFeedNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TimelineFeedNotifierProvider._internal(
        () => create()..memoryType = memoryType,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        memoryType: memoryType,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<TimelineFeedNotifier, TimelineFeedState>
      createElement() {
    return _TimelineFeedNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TimelineFeedNotifierProvider &&
        other.memoryType == memoryType;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, memoryType.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TimelineFeedNotifierRef
    on AutoDisposeNotifierProviderRef<TimelineFeedState> {
  /// The parameter `memoryType` of this provider.
  MemoryType? get memoryType;
}

class _TimelineFeedNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<TimelineFeedNotifier,
        TimelineFeedState> with TimelineFeedNotifierRef {
  _TimelineFeedNotifierProviderElement(super.provider);

  @override
  MemoryType? get memoryType =>
      (origin as TimelineFeedNotifierProvider).memoryType;
}

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

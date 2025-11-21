// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_memory_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineMemoryDetailNotifierHash() =>
    r'36d6bd2fe5b6e6071957f07f8276a242b06e8af3';

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

abstract class _$OfflineMemoryDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<MemoryDetail> {
  late final String localId;

  FutureOr<MemoryDetail> build(
    String localId,
  );
}

/// Provider for offline memory detail (queued items only)
///
/// [localId] is the local ID of the queued memory to fetch
/// This provider only works for queued offline memories stored in local queues.
/// It does not attempt to fetch remote details for preview-only entries.
///
/// Copied from [OfflineMemoryDetailNotifier].
@ProviderFor(OfflineMemoryDetailNotifier)
const offlineMemoryDetailNotifierProvider = OfflineMemoryDetailNotifierFamily();

/// Provider for offline memory detail (queued items only)
///
/// [localId] is the local ID of the queued memory to fetch
/// This provider only works for queued offline memories stored in local queues.
/// It does not attempt to fetch remote details for preview-only entries.
///
/// Copied from [OfflineMemoryDetailNotifier].
class OfflineMemoryDetailNotifierFamily
    extends Family<AsyncValue<MemoryDetail>> {
  /// Provider for offline memory detail (queued items only)
  ///
  /// [localId] is the local ID of the queued memory to fetch
  /// This provider only works for queued offline memories stored in local queues.
  /// It does not attempt to fetch remote details for preview-only entries.
  ///
  /// Copied from [OfflineMemoryDetailNotifier].
  const OfflineMemoryDetailNotifierFamily();

  /// Provider for offline memory detail (queued items only)
  ///
  /// [localId] is the local ID of the queued memory to fetch
  /// This provider only works for queued offline memories stored in local queues.
  /// It does not attempt to fetch remote details for preview-only entries.
  ///
  /// Copied from [OfflineMemoryDetailNotifier].
  OfflineMemoryDetailNotifierProvider call(
    String localId,
  ) {
    return OfflineMemoryDetailNotifierProvider(
      localId,
    );
  }

  @override
  OfflineMemoryDetailNotifierProvider getProviderOverride(
    covariant OfflineMemoryDetailNotifierProvider provider,
  ) {
    return call(
      provider.localId,
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
  String? get name => r'offlineMemoryDetailNotifierProvider';
}

/// Provider for offline memory detail (queued items only)
///
/// [localId] is the local ID of the queued memory to fetch
/// This provider only works for queued offline memories stored in local queues.
/// It does not attempt to fetch remote details for preview-only entries.
///
/// Copied from [OfflineMemoryDetailNotifier].
class OfflineMemoryDetailNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<OfflineMemoryDetailNotifier,
        MemoryDetail> {
  /// Provider for offline memory detail (queued items only)
  ///
  /// [localId] is the local ID of the queued memory to fetch
  /// This provider only works for queued offline memories stored in local queues.
  /// It does not attempt to fetch remote details for preview-only entries.
  ///
  /// Copied from [OfflineMemoryDetailNotifier].
  OfflineMemoryDetailNotifierProvider(
    String localId,
  ) : this._internal(
          () => OfflineMemoryDetailNotifier()..localId = localId,
          from: offlineMemoryDetailNotifierProvider,
          name: r'offlineMemoryDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$offlineMemoryDetailNotifierHash,
          dependencies: OfflineMemoryDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              OfflineMemoryDetailNotifierFamily._allTransitiveDependencies,
          localId: localId,
        );

  OfflineMemoryDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.localId,
  }) : super.internal();

  final String localId;

  @override
  FutureOr<MemoryDetail> runNotifierBuild(
    covariant OfflineMemoryDetailNotifier notifier,
  ) {
    return notifier.build(
      localId,
    );
  }

  @override
  Override overrideWith(OfflineMemoryDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: OfflineMemoryDetailNotifierProvider._internal(
        () => create()..localId = localId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        localId: localId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<OfflineMemoryDetailNotifier,
      MemoryDetail> createElement() {
    return _OfflineMemoryDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OfflineMemoryDetailNotifierProvider &&
        other.localId == localId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, localId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OfflineMemoryDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<MemoryDetail> {
  /// The parameter `localId` of this provider.
  String get localId;
}

class _OfflineMemoryDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<OfflineMemoryDetailNotifier,
        MemoryDetail> with OfflineMemoryDetailNotifierRef {
  _OfflineMemoryDetailNotifierProviderElement(super.provider);

  @override
  String get localId => (origin as OfflineMemoryDetailNotifierProvider).localId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

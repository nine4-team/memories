// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$momentDetailServiceHash() =>
    r'f065e0a97f4dd9c1d14b86c6286601a81a715d68';

/// Provider for moment detail service
///
/// Copied from [momentDetailService].
@ProviderFor(momentDetailService)
final momentDetailServiceProvider =
    AutoDisposeProvider<MomentDetailService>.internal(
  momentDetailService,
  name: r'momentDetailServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$momentDetailServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MomentDetailServiceRef = AutoDisposeProviderRef<MomentDetailService>;
String _$momentDetailNotifierHash() =>
    r'd641b09788ed2ab493f27b8db941f28ee83f7b00';

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

abstract class _$MomentDetailNotifier
    extends BuildlessAutoDisposeNotifier<MomentDetailViewState> {
  late final String momentId;

  MomentDetailViewState build(
    String momentId,
  );
}

/// Provider for moment detail state
///
/// [momentId] is the UUID of the moment to fetch
///
/// Copied from [MomentDetailNotifier].
@ProviderFor(MomentDetailNotifier)
const momentDetailNotifierProvider = MomentDetailNotifierFamily();

/// Provider for moment detail state
///
/// [momentId] is the UUID of the moment to fetch
///
/// Copied from [MomentDetailNotifier].
class MomentDetailNotifierFamily extends Family<MomentDetailViewState> {
  /// Provider for moment detail state
  ///
  /// [momentId] is the UUID of the moment to fetch
  ///
  /// Copied from [MomentDetailNotifier].
  const MomentDetailNotifierFamily();

  /// Provider for moment detail state
  ///
  /// [momentId] is the UUID of the moment to fetch
  ///
  /// Copied from [MomentDetailNotifier].
  MomentDetailNotifierProvider call(
    String momentId,
  ) {
    return MomentDetailNotifierProvider(
      momentId,
    );
  }

  @override
  MomentDetailNotifierProvider getProviderOverride(
    covariant MomentDetailNotifierProvider provider,
  ) {
    return call(
      provider.momentId,
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
  String? get name => r'momentDetailNotifierProvider';
}

/// Provider for moment detail state
///
/// [momentId] is the UUID of the moment to fetch
///
/// Copied from [MomentDetailNotifier].
class MomentDetailNotifierProvider extends AutoDisposeNotifierProviderImpl<
    MomentDetailNotifier, MomentDetailViewState> {
  /// Provider for moment detail state
  ///
  /// [momentId] is the UUID of the moment to fetch
  ///
  /// Copied from [MomentDetailNotifier].
  MomentDetailNotifierProvider(
    String momentId,
  ) : this._internal(
          () => MomentDetailNotifier()..momentId = momentId,
          from: momentDetailNotifierProvider,
          name: r'momentDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$momentDetailNotifierHash,
          dependencies: MomentDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              MomentDetailNotifierFamily._allTransitiveDependencies,
          momentId: momentId,
        );

  MomentDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.momentId,
  }) : super.internal();

  final String momentId;

  @override
  MomentDetailViewState runNotifierBuild(
    covariant MomentDetailNotifier notifier,
  ) {
    return notifier.build(
      momentId,
    );
  }

  @override
  Override overrideWith(MomentDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MomentDetailNotifierProvider._internal(
        () => create()..momentId = momentId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        momentId: momentId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<MomentDetailNotifier,
      MomentDetailViewState> createElement() {
    return _MomentDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MomentDetailNotifierProvider && other.momentId == momentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, momentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MomentDetailNotifierRef
    on AutoDisposeNotifierProviderRef<MomentDetailViewState> {
  /// The parameter `momentId` of this provider.
  String get momentId;
}

class _MomentDetailNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<MomentDetailNotifier,
        MomentDetailViewState> with MomentDetailNotifierRef {
  _MomentDetailNotifierProviderElement(super.provider);

  @override
  String get momentId => (origin as MomentDetailNotifierProvider).momentId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

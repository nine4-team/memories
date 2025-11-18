// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictationServiceHash() => r'614026fe3e293419933b512bbd95114b94af28f0';

/// Provider for dictation service
///
/// Copied from [dictationService].
@ProviderFor(dictationService)
final dictationServiceProvider = AutoDisposeProvider<DictationService>.internal(
  dictationService,
  name: r'dictationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dictationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictationServiceRef = AutoDisposeProviderRef<DictationService>;
String _$geolocationServiceHash() =>
    r'05dd867526d104eaa2a329fe4982be9c281ae68f';

/// Provider for geolocation service
///
/// Copied from [geolocationService].
@ProviderFor(geolocationService)
final geolocationServiceProvider =
    AutoDisposeProvider<GeolocationService>.internal(
  geolocationService,
  name: r'geolocationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$geolocationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GeolocationServiceRef = AutoDisposeProviderRef<GeolocationService>;
String _$captureStateNotifierHash() =>
    r'2e25da47c30ac737484a71c87df1b0b5e3646867';

/// Provider for capture state
///
/// Manages the state of the unified capture sheet including:
/// - Memory type selection (Moment/Story/Memento)
/// - Dictation transcript
/// - Description text
/// - Media attachments (photos/videos)
/// - Tags
/// - Dictation status
///
/// Copied from [CaptureStateNotifier].
@ProviderFor(CaptureStateNotifier)
final captureStateNotifierProvider =
    AutoDisposeNotifierProvider<CaptureStateNotifier, CaptureState>.internal(
  CaptureStateNotifier.new,
  name: r'captureStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$captureStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CaptureStateNotifier = AutoDisposeNotifier<CaptureState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

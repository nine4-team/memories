import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/moment_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/moment_detail_service.dart';

part 'moment_detail_provider.g.dart';

/// State of the moment detail view
enum MomentDetailState {
  initial,
  loading,
  loaded,
  error,
}

/// Moment detail view state
class MomentDetailViewState {
  final MomentDetailState state;
  final MomentDetail? moment;
  final String? errorMessage;
  final bool isFromCache; // Indicates if data is from cache (offline mode)

  const MomentDetailViewState({
    required this.state,
    this.moment,
    this.errorMessage,
    this.isFromCache = false,
  });

  MomentDetailViewState copyWith({
    MomentDetailState? state,
    MomentDetail? moment,
    String? errorMessage,
    bool? isFromCache,
  }) {
    return MomentDetailViewState(
      state: state ?? this.state,
      moment: moment ?? this.moment,
      errorMessage: errorMessage ?? this.errorMessage,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// Provider for moment detail service
@riverpod
MomentDetailService momentDetailService(MomentDetailServiceRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  return MomentDetailService(supabase);
}

/// Provider for moment detail state
/// 
/// [momentId] is the UUID of the moment to fetch
@riverpod
class MomentDetailNotifier extends _$MomentDetailNotifier {
  late final String _momentId;

  @override
  MomentDetailViewState build(String momentId) {
    _momentId = momentId;
    // Auto-load when provider is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMomentDetail();
    });
    return const MomentDetailViewState(state: MomentDetailState.initial);
  }

  /// Load moment detail data
  Future<void> loadMomentDetail() async {
    debugPrint('[MomentDetailNotifier] Loading moment detail for: $_momentId');
    state = state.copyWith(
      state: MomentDetailState.loading,
      errorMessage: null,
      isFromCache: false,
    );

    try {
      final service = ref.read(momentDetailServiceProvider);
      final connectivityService = ref.read(connectivityServiceProvider);
      final isOnline = await connectivityService.isOnline();
      
      debugPrint('[MomentDetailNotifier] Is online: $isOnline');
      
      // When offline, prefer cache; when online, prefer network (with cache fallback)
      final result = await service.getMomentDetail(
        _momentId,
        preferCache: !isOnline,
      );

      debugPrint('[MomentDetailNotifier] ✓ Loaded moment detail');
      debugPrint('[MomentDetailNotifier]   From cache: ${result.isFromCache}');
      debugPrint('[MomentDetailNotifier]   Moment ID: ${result.moment.id}');
      debugPrint('[MomentDetailNotifier]   Photos: ${result.moment.photos.length}');
      debugPrint('[MomentDetailNotifier]   Videos: ${result.moment.videos.length}');

      state = state.copyWith(
        state: MomentDetailState.loaded,
        moment: result.moment,
        errorMessage: null,
        isFromCache: result.isFromCache,
      );
    } catch (e, stackTrace) {
      debugPrint('[MomentDetailNotifier] ✗ Error loading moment detail: $e');
      debugPrint('[MomentDetailNotifier]   Stack trace: $stackTrace');
      state = state.copyWith(
        state: MomentDetailState.error,
        errorMessage: e.toString(),
        isFromCache: false,
      );
    }
  }

  /// Refresh moment detail data
  Future<void> refresh() async {
    await loadMomentDetail();
  }

  /// Delete the moment
  /// 
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteMoment() async {
    try {
      final service = ref.read(momentDetailServiceProvider);
      await service.deleteMoment(_momentId);
      return true;
    } catch (e) {
      state = state.copyWith(
        state: MomentDetailState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Get share link for the moment
  /// 
  /// Returns the shareable URL if successful, null if unavailable
  Future<String?> getShareLink() async {
    try {
      final service = ref.read(momentDetailServiceProvider);
      return await service.getShareLink(_momentId);
    } catch (e) {
      return null;
    }
  }
}


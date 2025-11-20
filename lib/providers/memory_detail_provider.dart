import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_detail_service.dart';

part 'memory_detail_provider.g.dart';

/// State of the memory detail view
enum MemoryDetailState {
  initial,
  loading,
  loaded,
  error,
}

/// Memory detail view state
class MemoryDetailViewState {
  final MemoryDetailState state;
  final MemoryDetail? memory;
  final String? errorMessage;
  final bool isFromCache; // Indicates if data is from cache (offline mode)

  const MemoryDetailViewState({
    required this.state,
    this.memory,
    this.errorMessage,
    this.isFromCache = false,
  });

  MemoryDetailViewState copyWith({
    MemoryDetailState? state,
    MemoryDetail? memory,
    String? errorMessage,
    bool? isFromCache,
  }) {
    return MemoryDetailViewState(
      state: state ?? this.state,
      memory: memory ?? this.memory,
      errorMessage: errorMessage ?? this.errorMessage,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

/// Provider for memory detail service
@riverpod
MemoryDetailService memoryDetailService(MemoryDetailServiceRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  return MemoryDetailService(supabase);
}

/// Provider for memory detail state
/// 
/// [memoryId] is the UUID of the memory to fetch
@riverpod
class MemoryDetailNotifier extends _$MemoryDetailNotifier {
  late final String _memoryId;
  bool _isDeleted = false; // Track if memory was deleted

  @override
  MemoryDetailViewState build(String memoryId) {
    _memoryId = memoryId;
    // Auto-load when provider is created, but skip if deleted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDeleted) {
        loadMemoryDetail();
      }
    });
    return const MemoryDetailViewState(state: MemoryDetailState.initial);
  }

  /// Load memory detail data
  Future<void> loadMemoryDetail() async {
    // Skip loading if memory was deleted
    if (_isDeleted || state.errorMessage == 'Memory has been deleted') {
      debugPrint('[MemoryDetailNotifier] Skipping load - memory was deleted');
      return;
    }
    
    debugPrint('[MemoryDetailNotifier] Loading memory detail for: $_memoryId');
    state = state.copyWith(
      state: MemoryDetailState.loading,
      errorMessage: null,
      isFromCache: false,
    );

    try {
      final service = ref.read(memoryDetailServiceProvider);
      final connectivityService = ref.read(connectivityServiceProvider);
      final isOnline = await connectivityService.isOnline();
      
      debugPrint('[MemoryDetailNotifier] Is online: $isOnline');
      
      // When offline, prefer cache; when online, prefer network (with cache fallback)
      final result = await service.getMemoryDetail(
        _memoryId,
        preferCache: !isOnline,
      );

      debugPrint('[MemoryDetailNotifier] ✓ Loaded memory detail');
      debugPrint('[MemoryDetailNotifier]   From cache: ${result.isFromCache}');
      debugPrint('[MemoryDetailNotifier]   Memory ID: ${result.memory.id}');
      debugPrint('[MemoryDetailNotifier]   Photos: ${result.memory.photos.length}');
      debugPrint('[MemoryDetailNotifier]   Videos: ${result.memory.videos.length}');

      state = state.copyWith(
        state: MemoryDetailState.loaded,
        memory: result.memory,
        errorMessage: null,
        isFromCache: result.isFromCache,
      );
    } catch (e, stackTrace) {
      debugPrint('[MemoryDetailNotifier] ✗ Error loading memory detail: $e');
      debugPrint('[MemoryDetailNotifier]   Stack trace: $stackTrace');
      
      // Check if error is because memory was deleted (404 or not found)
      final errorString = e.toString().toLowerCase();
      final isDeletedError = errorString.contains('not found') || 
                            errorString.contains('does not exist') ||
                            errorString.contains('already deleted');
      
      if (isDeletedError) {
        _isDeleted = true;
      }
      
      state = state.copyWith(
        state: MemoryDetailState.error,
        errorMessage: isDeletedError ? 'Memory has been deleted' : e.toString(),
        isFromCache: false,
      );
    }
  }

  /// Refresh memory detail data
  Future<void> refresh() async {
    // Don't refresh if memory was deleted
    if (_isDeleted) {
      debugPrint('[MemoryDetailNotifier] Skipping refresh - memory was deleted');
      return;
    }
    await loadMemoryDetail();
  }

  /// Delete the memory
  /// 
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteMemory() async {
    try {
      debugPrint('[MemoryDetailNotifier] Deleting memory: $_memoryId');
      final service = ref.read(memoryDetailServiceProvider);
      await service.deleteMemory(_memoryId);
      debugPrint('[MemoryDetailNotifier] Successfully deleted memory: $_memoryId');
      
      // Mark as deleted to prevent any future reload attempts
      _isDeleted = true;
      
      // Set state to error with a deleted flag to prevent auto-reload attempts
      state = state.copyWith(
        state: MemoryDetailState.error,
        errorMessage: 'Memory has been deleted',
        memory: null,
      );
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('[MemoryDetailNotifier] Error deleting memory: $e');
      debugPrint('[MemoryDetailNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        state: MemoryDetailState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Get share link for the memory
  /// 
  /// Returns the shareable URL if successful, null if unavailable
  Future<String?> getShareLink() async {
    try {
      final service = ref.read(memoryDetailServiceProvider);
      return await service.getShareLink(_memoryId);
    } catch (e) {
      return null;
    }
  }
}


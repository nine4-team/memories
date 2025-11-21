import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queue_change_event.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_sync_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/shared_preferences_local_memory_preview_store.dart';

part 'unified_feed_provider.g.dart';

/// State of the unified feed
enum UnifiedFeedState {
  /// Initial state before any load attempt
  initial,

  /// Loading initial page
  loading,

  /// Feed is ready with data
  ready,

  /// Appending more items (pagination)
  appending,

  /// Error state (initial load failed)
  error,

  /// Pagination error (has existing data)
  paginationError,

  /// Empty state (no memories found)
  empty,
}

/// Unified feed view state
class UnifiedFeedViewState {
  final UnifiedFeedState state;
  final List<TimelineMemory> memories;
  final UnifiedFeedCursor? nextCursor;
  final String? errorMessage;
  final bool hasMore;
  final bool isOffline;
  final List<int> availableYears;

  const UnifiedFeedViewState({
    required this.state,
    this.memories = const [],
    this.nextCursor,
    this.errorMessage,
    this.hasMore = false,
    this.isOffline = false,
    this.availableYears = const [],
  });

  UnifiedFeedViewState copyWith({
    UnifiedFeedState? state,
    List<TimelineMemory>? memories,
    UnifiedFeedCursor? nextCursor,
    String? errorMessage,
    bool? hasMore,
    bool? isOffline,
    List<int>? availableYears,
  }) {
    return UnifiedFeedViewState(
      state: state ?? this.state,
      memories: memories ?? this.memories,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      isOffline: isOffline ?? this.isOffline,
      availableYears: availableYears ?? this.availableYears,
    );
  }
}

/// Provider for unified feed repository
@riverpod
UnifiedFeedRepository unifiedFeedRepository(UnifiedFeedRepositoryRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  final offlineQueueService = ref.read(offlineMemoryQueueServiceProvider);
  final localPreviewStore = ref.read(localMemoryPreviewStoreProvider);

  return UnifiedFeedRepository(
    supabase,
    offlineQueueService,
    localPreviewStore,
  );
}

/// Provider for unified feed state
///
/// [memoryTypeFilters] is the set of memory types to include (empty set means all)
@riverpod
class UnifiedFeedController extends _$UnifiedFeedController {
  static const int _batchSize = 20;
  int _currentPageNumber = 1;
  Set<MemoryType> _memoryTypeFilters = {};
  StreamSubscription<SyncCompleteEvent>? _syncSub;
  StreamSubscription<QueueChangeEvent>? _queueChangeSub;

  @override
  UnifiedFeedViewState build([Set<MemoryType>? memoryTypeFilters]) {
    _memoryTypeFilters = memoryTypeFilters ?? {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };
    _setupSyncListener();
    _setupQueueChangeListeners();
    ref.onDispose(() {
      _syncSub?.cancel();
      _queueChangeSub?.cancel();
    });
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
  }

  void _setupSyncListener() {
    final syncService = ref.read(memorySyncServiceProvider);

    _syncSub?.cancel();
    _syncSub = syncService.syncCompleteStream.listen((event) {
      _removeQueuedEntry(event.localId);
      // We do NOT immediately re-fetch the feed here; the server-backed
      // version will naturally appear on next pagination/refresh.
    });
  }

  void _setupQueueChangeListeners() {
    final queueService = ref.read(offlineMemoryQueueServiceProvider);

    _queueChangeSub?.cancel();
    _queueChangeSub = queueService.changeStream.listen((event) {
      _handleQueueChange(event);
    });
  }

  void _handleQueueChange(QueueChangeEvent event) {
    // Handle different change types
    switch (event.type) {
      case QueueChangeType.added:
      case QueueChangeType.updated:
        // For added/updated, re-fetch the feed to get latest queue state
        // This ensures the feed reflects the latest queue contents
        if (state.state == UnifiedFeedState.ready || state.state == UnifiedFeedState.empty) {
          // Only refresh if feed is already loaded
          _fetchPage(
            cursor: null,
            append: false,
            pageNumber: 1,
          );
        }
        break;
      case QueueChangeType.removed:
        // For removed, optimistically remove from feed immediately
        _removeQueuedEntryByLocalId(event.localId);
        break;
    }
  }

  void _removeQueuedEntry(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }
  
  /// Handle queue change event - remove queued entry by localId
  void _removeQueuedEntryByLocalId(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }

  /// Load initial feed
  Future<void> loadInitial() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    state = state.copyWith(
      state: UnifiedFeedState.loading,
      memories: [],
      nextCursor: null,
      hasMore: false,
      isOffline: !isOnline,
      availableYears: const [],
    );

    try {
      await _fetchPage(
        cursor: null,
        append: false,
        pageNumber: 1,
      );
    } catch (e) {
      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'unified_feed_initial_load',
        context: {
          'memory_type_filters': _memoryTypeFilters.map((t) => t.apiValue).join(','),
          'is_offline': !isOnline,
        },
      );
      state = state.copyWith(
        state: UnifiedFeedState.error,
        errorMessage: _getUserFriendlyErrorMessage(e),
        isOffline: !isOnline,
      );
    }
  }

  /// Load next page (pagination)
  Future<void> loadMore() async {
    // Allow retry from pagination error state
    if (state.state == UnifiedFeedState.appending ||
        (!state.hasMore && state.state != UnifiedFeedState.paginationError) ||
        (state.nextCursor == null &&
            state.state != UnifiedFeedState.paginationError)) {
      return;
    }

    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    _currentPageNumber++;
    state = state.copyWith(
      state: UnifiedFeedState.appending,
      isOffline: !isOnline,
    );

    try {
      await _fetchPage(
        cursor: state.nextCursor!,
        append: true,
        pageNumber: _currentPageNumber,
      );
    } catch (e) {
      // Track pagination failure
      ref
          .read(timelineAnalyticsServiceProvider)
          .trackUnifiedFeedPaginationFailure(
            _currentPageNumber,
            e.toString(),
          );

      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'unified_feed_pagination',
        context: {
          'page_number': _currentPageNumber,
          'memory_type_filters': _memoryTypeFilters.map((t) => t.apiValue).join(','),
          'is_offline': !isOnline,
        },
      );

      // Keep existing memories visible, show inline error
      state = state.copyWith(
        state: UnifiedFeedState.paginationError,
        errorMessage: _getUserFriendlyErrorMessage(e),
        isOffline: !isOnline,
      );
    }
  }

  /// Refresh feed (reload first page)
  Future<void> refresh() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    // Disable refresh while offline
    if (!isOnline) {
      return;
    }

    _currentPageNumber = 1;
    await loadInitial();
  }

  /// Remove a memory from the feed (optimistic update)
  /// 
  /// [memoryId] is the ID of the memory to remove
  void removeMemory(String memoryId) {
    final updatedMemories = state.memories.where((m) => m.id != memoryId).toList();
    state = state.copyWith(memories: updatedMemories);
  }

  /// Update the memory type filters and reload
  Future<void> setFilter(Set<MemoryType> filters) async {
    _memoryTypeFilters = filters;
    _currentPageNumber = 1;
    await loadInitial();
  }

  Future<void> _fetchPage({
    UnifiedFeedCursor? cursor,
    required bool append,
    required int pageNumber,
  }) async {
    final stopwatch = Stopwatch()..start();
    final repository = ref.read(unifiedFeedRepositoryProvider);
    final connectivityService = ref.read(connectivityServiceProvider);

    // Check connectivity
    final isOnline = await connectivityService.isOnline();

    final result = await repository.fetchMergedFeed(
      cursor: cursor,
      filters: _memoryTypeFilters,
      batchSize: _batchSize,
      isOnline: isOnline,
    );

    final resolvedAvailableYears = append
        ? state.availableYears
        : await repository.fetchAvailableYears(filters: _memoryTypeFilters);

    stopwatch.stop();

    // Track pagination success
    ref
        .read(timelineAnalyticsServiceProvider)
        .trackUnifiedFeedPaginationSuccess(
          pageNumber,
          result.memories.length,
          stopwatch.elapsedMilliseconds,
        );

    state = state.copyWith(
      state: result.memories.isEmpty && !append
          ? UnifiedFeedState.empty
          : UnifiedFeedState.ready,
      memories:
          append ? [...state.memories, ...result.memories] : result.memories,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
      errorMessage: null,
      isOffline: !isOnline,
      availableYears: resolvedAvailableYears,
    );
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(Object error) {
    // Handle network/connectivity errors
    if (error is SocketException || error is TimeoutException) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Handle offline errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('offline') ||
        errorString.contains('no internet')) {
      return 'You appear to be offline. Please check your internet connection and try again.';
    }

    // Handle network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Handle timeout errors
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Generic error - don't expose technical details
    return 'Failed to load memories. Please try again.';
  }
}

/// Convenience provider for unified feed (all memory types)
final unifiedFeedProvider = unifiedFeedControllerProvider({
  MemoryType.story,
  MemoryType.moment,
  MemoryType.memento,
});

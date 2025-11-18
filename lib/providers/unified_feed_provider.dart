import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

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
  final List<TimelineMoment> memories;
  final UnifiedFeedCursor? nextCursor;
  final String? errorMessage;
  final bool hasMore;
  final bool isOffline;

  const UnifiedFeedViewState({
    required this.state,
    this.memories = const [],
    this.nextCursor,
    this.errorMessage,
    this.hasMore = false,
    this.isOffline = false,
  });

  UnifiedFeedViewState copyWith({
    UnifiedFeedState? state,
    List<TimelineMoment>? memories,
    UnifiedFeedCursor? nextCursor,
    String? errorMessage,
    bool? hasMore,
    bool? isOffline,
  }) {
    return UnifiedFeedViewState(
      state: state ?? this.state,
      memories: memories ?? this.memories,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// Provider for unified feed repository
@riverpod
UnifiedFeedRepository unifiedFeedRepository(UnifiedFeedRepositoryRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  return UnifiedFeedRepository(supabase);
}

/// Provider for unified feed state
///
/// [memoryTypeFilter] is the filter to apply (null for 'all')
@riverpod
class UnifiedFeedController extends _$UnifiedFeedController {
  static const int _batchSize = 20;
  int _currentPageNumber = 1;
  MemoryType? _memoryTypeFilter;

  @override
  UnifiedFeedViewState build([MemoryType? memoryTypeFilter]) {
    _memoryTypeFilter = memoryTypeFilter;
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
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
          'memory_type_filter': _memoryTypeFilter?.apiValue ?? 'all',
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
          'memory_type_filter': _memoryTypeFilter?.apiValue ?? 'all',
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

  /// Update the memory type filter and reload
  Future<void> setFilter(MemoryType? filter) async {
    _memoryTypeFilter = filter;
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
    if (!isOnline) {
      throw Exception('Device is offline');
    }

    final result = await repository.fetchPage(
      cursor: cursor,
      filter: _memoryTypeFilter,
      batchSize: _batchSize,
    );

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
      isOffline: false,
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
final unifiedFeedProvider = unifiedFeedControllerProvider(null);

/// Convenience provider for Story-only feed
final unifiedFeedStoryProvider =
    unifiedFeedControllerProvider(MemoryType.story);

/// Convenience provider for Moment-only feed
final unifiedFeedMomentProvider =
    unifiedFeedControllerProvider(MemoryType.moment);

/// Convenience provider for Memento-only feed
final unifiedFeedMementoProvider =
    unifiedFeedControllerProvider(MemoryType.memento);

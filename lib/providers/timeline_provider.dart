import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

part 'timeline_provider.g.dart';

/// Cursor for pagination
class TimelineCursor {
  final DateTime? capturedAt;
  final String? id;

  const TimelineCursor({
    this.capturedAt,
    this.id,
  });

  bool get isEmpty => capturedAt == null && id == null;

  Map<String, dynamic> toParams() {
    if (isEmpty) {
      return {};
    }
    return {
      'p_cursor_captured_at': capturedAt?.toIso8601String(),
      'p_cursor_id': id,
    };
  }
}

/// State of the timeline feed
enum TimelineState {
  initial,
  loading,
  loaded,
  loadingMore,
  error,
  empty,
}

/// Timeline feed state
class TimelineFeedState {
  final TimelineState state;
  final List<TimelineMoment> moments;
  final TimelineCursor? nextCursor;
  final String? errorMessage;
  final bool hasMore;

  const TimelineFeedState({
    required this.state,
    this.moments = const [],
    this.nextCursor,
    this.errorMessage,
    this.hasMore = false,
  });

  TimelineFeedState copyWith({
    TimelineState? state,
    List<TimelineMoment>? moments,
    TimelineCursor? nextCursor,
    String? errorMessage,
    bool? hasMore,
  }) {
    return TimelineFeedState(
      state: state ?? this.state,
      moments: moments ?? this.moments,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Provider for timeline feed state
@riverpod
class TimelineFeedNotifier extends _$TimelineFeedNotifier {
  static const int _batchSize = 25;
  int _currentPageNumber = 1;

  @override
  TimelineFeedState build() {
    return const TimelineFeedState(state: TimelineState.initial);
  }

  /// Load initial feed
  Future<void> loadInitial({String? searchQuery}) async {
    state = state.copyWith(
      state: TimelineState.loading,
      moments: [],
      nextCursor: null,
    );

    try {
      await _fetchPage(
        cursor: const TimelineCursor(),
        searchQuery: searchQuery,
        append: false,
        pageNumber: 1,
      );
    } catch (e) {
      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'initial_load',
        context: {'search_query': searchQuery?.isNotEmpty ?? false},
      );
      state = state.copyWith(
        state: TimelineState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load next page
  Future<void> loadMore({String? searchQuery}) async {
    if (state.state == TimelineState.loadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    _currentPageNumber++;
    state = state.copyWith(state: TimelineState.loadingMore);

    try {
      await _fetchPage(
        cursor: state.nextCursor!,
        searchQuery: searchQuery,
        append: true,
        pageNumber: _currentPageNumber,
      );
    } catch (e) {
      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'pagination',
        context: {'page_number': _currentPageNumber},
      );
      state = state.copyWith(
        state: TimelineState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresh feed
  Future<void> refresh({String? searchQuery}) async {
    _currentPageNumber = 1;
    await loadInitial(searchQuery: searchQuery);
  }

  Future<void> _fetchPage({
    required TimelineCursor cursor,
    String? searchQuery,
    required bool append,
    required int pageNumber,
  }) async {
    final stopwatch = Stopwatch()..start();
    final supabase = ref.read(supabaseClientProvider);
    final connectivityService = ref.read(connectivityServiceProvider);

    // Check connectivity
    final isOnline = await connectivityService.isOnline();
    if (!isOnline) {
      throw Exception('Device is offline');
    }

    final params = <String, dynamic>{
      'p_batch_size': _batchSize,
      ...cursor.toParams(),
    };

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      params['p_search_query'] = searchQuery.trim();
    }

    final response = await supabase.rpc('get_timeline_feed', params: params);

    if (response is! List) {
      throw Exception('Invalid response format');
    }

    final moments = response
        .map((json) => TimelineMoment.fromJson(json as Map<String, dynamic>))
        .toList();

    // Determine next cursor from last item
    TimelineCursor? nextCursor;
    bool hasMore = false;

    if (moments.isNotEmpty) {
      final lastMoment = moments.last;
      if (moments.length >= _batchSize) {
        // Likely more results available
        hasMore = true;
        nextCursor = TimelineCursor(
          capturedAt: lastMoment.capturedAt,
          id: lastMoment.id,
        );
      }
    }

    stopwatch.stop();
    
    // Track pagination performance
    ref.read(timelineAnalyticsServiceProvider).trackPagination(
      pageNumber,
      moments.length,
      stopwatch.elapsedMilliseconds,
    );

    state = state.copyWith(
      state: moments.isEmpty && !append
          ? TimelineState.empty
          : TimelineState.loaded,
      moments: append ? [...state.moments, ...moments] : moments,
      nextCursor: nextCursor,
      hasMore: hasMore,
      errorMessage: null,
    );
  }
}

/// Provider for search query state
@riverpod
class SearchQueryNotifier extends _$SearchQueryNotifier {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}


import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/search_service.dart';
import 'package:memories/models/search_result.dart';
import 'package:memories/providers/supabase_provider.dart';

part 'search_provider.g.dart';

/// Provider for search service
@riverpod
SearchService searchService(SearchServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SearchService(supabase);
}

/// Provider for current search query string
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider for debounced search query
/// 
/// Debounces the search query by 250ms before updating
@riverpod
class DebouncedSearchQuery extends _$DebouncedSearchQuery {
  Timer? _debounceTimer;

  @override
  String build() {
    final query = ref.watch(searchQueryProvider);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // If query is empty, update immediately
    if (query.isEmpty) {
      return '';
    }

    // Otherwise, debounce by 250ms
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      state = query;
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Return current state (will be updated by timer)
    return state;
  }
}

/// State for search results
class SearchResultsState {
  final List<SearchResult> items;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  SearchResultsState({
    required this.items,
    required this.currentPage,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.errorMessage,
  });

  SearchResultsState copyWith({
    List<SearchResult>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchResultsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static SearchResultsState initial() {
    return SearchResultsState(
      items: [],
      currentPage: 0,
      hasMore: false,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
  }
}

/// Provider for search results with pagination
@riverpod
class SearchResults extends _$SearchResults {
  String? _lastQuery;
  Future<void>? _lastSearchFuture;

  @override
  SearchResultsState build() {
    // Always start from a known initial state before we do anything that
    // reads or updates `state` (e.g., inside `_performSearch`). This avoids
    // "uninitialized provider" errors on first use in the app shell.
    state = SearchResultsState.initial();

    // Watch debounced query and trigger search when it changes
    final debouncedQuery = ref.watch(debouncedSearchQueryProvider);
    
    // Only search if query is non-empty and different from last query
    if (debouncedQuery.isNotEmpty && debouncedQuery != _lastQuery) {
      _lastQuery = debouncedQuery;
      // Cancel any pending search
      _lastSearchFuture?.ignore();
      // Trigger new search
      _lastSearchFuture = _performSearch(debouncedQuery, page: 1);
    } else if (debouncedQuery.isEmpty && _lastQuery != null) {
      // Clear results when query is cleared
      _lastQuery = null;
      // `state` has already been reset to the initial value above.
    }

    return state;
  }

  Future<void> _performSearch(String query, {required int page}) async {
    // Set loading state
    if (page == 1) {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        clearError: true,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final searchService = ref.read(searchServiceProvider);
      final results = await searchService.searchMemories(
        query: query,
        page: page,
      );

      // Check if query changed during fetch (ignore stale response)
      if (_lastQuery != query && page == 1) {
        return;
      }

      // Add recent search if this is the first page and we have results
      if (page == 1 && results.items.isNotEmpty) {
        try {
          await searchService.addRecentSearch(query);
          // Refresh recent searches provider
          ref.invalidate(recentSearchesProvider);
        } catch (e) {
          // Don't fail the search if recent search save fails
        }
      }

      // Update state with results
      state = state.copyWith(
        items: page == 1 ? results.items : [...state.items, ...results.items],
        currentPage: results.page,
        hasMore: results.hasMore,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      // Check if query changed during fetch (ignore stale error)
      if (_lastQuery != query && page == 1) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: _getUserFriendlyErrorMessage(e),
      );
    }
  }

  /// Load more results for the current query
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) {
      return;
    }

    final query = ref.read(debouncedSearchQueryProvider);
    if (query.isEmpty) {
      return;
    }

    await _performSearch(query, page: state.currentPage + 1);
  }

  /// Refresh search results for the current query
  Future<void> refresh() async {
    final query = ref.read(debouncedSearchQueryProvider);
    if (query.isEmpty) {
      return;
    }

    await _performSearch(query, page: 1);
  }

  /// Clear search results
  void clear() {
    _lastQuery = null;
    state = SearchResultsState.initial();
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('offline') || errorString.contains('network')) {
      return 'Unable to connect. Please check your internet connection.';
    } else if (errorString.contains('unauthorized')) {
      return 'Please sign in to search your memories.';
    } else if (errorString.contains('empty') || errorString.contains('argument')) {
      return 'Please enter a search query.';
    } else {
      return 'Unable to search. Please try again.';
    }
  }
}

/// Provider for recent searches
@riverpod
Future<List<RecentSearch>> recentSearches(RecentSearchesRef ref) async {
  final searchService = ref.read(searchServiceProvider);
  return await searchService.getRecentSearches();
}

/// Provider for clearing recent searches
@riverpod
class ClearRecentSearches extends _$ClearRecentSearches {
  @override
  FutureOr<void> build() {
    // This provider doesn't maintain state, it's just for triggering the action
  }

  Future<void> clear() async {
    final searchService = ref.read(searchServiceProvider);
    await searchService.clearRecentSearches();
    // Invalidate recent searches provider to refresh the list
    ref.invalidate(recentSearchesProvider);
  }
}

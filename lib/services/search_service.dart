import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/models/search_result.dart';
import 'package:memories/models/memory_type.dart';

/// Service for searching memories and managing recent searches
class SearchService {
  final SupabaseClient _supabase;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 50;

  SearchService(this._supabase);

  /// Search memories using full-text search
  /// 
  /// [query] is the search query string (required, non-empty)
  /// [page] is the page number (default: 1)
  /// [pageSize] is the number of results per page (default: 20, max: 50)
  /// [memoryType] is an optional filter by memory type (null for all types)
  /// 
  /// Returns a [SearchResultsPage] with paginated results
  Future<SearchResultsPage> searchMemories({
    required String query,
    int page = 1,
    int pageSize = _defaultPageSize,
    MemoryType? memoryType,
  }) async {
    // Normalize query
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw ArgumentError('Query cannot be empty or whitespace-only');
    }

    // Validate and clamp page size
    final clampedPageSize = pageSize.clamp(1, _maxPageSize);

    // Prepare parameters
    final params = <String, dynamic>{
      'p_query': normalizedQuery,
      'p_page': page,
      'p_page_size': clampedPageSize,
    };

    // Add memory type filter if specified
    if (memoryType != null) {
      params['p_memory_type'] = memoryType.apiValue;
    }

    // Call RPC function
    final response = await _supabase.rpc('search_memories', params: params);

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid response format from search_memories');
    }

    return SearchResultsPage.fromJson(response);
  }

  /// Get recent searches for the current user (last 5)
  /// 
  /// Returns a list of [RecentSearch] ordered by most recent first
  Future<List<RecentSearch>> getRecentSearches() async {
    final response = await _supabase.rpc('get_recent_searches');

    if (response is! List) {
      throw Exception('Invalid response format from get_recent_searches');
    }

    return response
        .map((json) => RecentSearch.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Add a search query to recent searches
  /// 
  /// [query] is the search query to add (will be normalized)
  /// 
  /// This will either insert a new recent search or update an existing one
  /// to move it to the most recent position. Maintains only the last 5 queries.
  Future<void> addRecentSearch(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw ArgumentError('Query cannot be empty or whitespace-only');
    }

    await _supabase.rpc('upsert_recent_search', params: {
      'p_query': normalizedQuery,
    });
  }

  /// Clear all recent searches for the current user
  Future<void> clearRecentSearches() async {
    await _supabase.rpc('clear_recent_searches');
  }
}

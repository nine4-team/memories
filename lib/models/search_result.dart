/// Model representing a search result from the search_memories RPC
class SearchResult {
  final String id;
  final String memoryType;
  final String title;
  final String? snippetText;
  final DateTime createdAt;

  SearchResult({
    required this.id,
    required this.memoryType,
    required this.title,
    this.snippetText,
    required this.createdAt,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      memoryType: json['memory_type'] as String,
      title: json['title'] as String? ?? '',
      snippetText: json['snippet_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Paginated search results response
class SearchResultsPage {
  final List<SearchResult> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  SearchResultsPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory SearchResultsPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>;
    return SearchResultsPage(
      items: itemsJson
          .map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// Recent search query model
class RecentSearch {
  final String query;
  final DateTime searchedAt;

  RecentSearch({
    required this.query,
    required this.searchedAt,
  });

  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      query: json['query'] as String,
      searchedAt: DateTime.parse(json['searched_at'] as String),
    );
  }
}

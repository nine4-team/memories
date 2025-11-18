import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/models/search_result.dart';

/// Global search bar widget for primary screens
/// 
/// Provides a persistent search field with:
/// - Debounced search (250ms)
/// - Loading and error states
/// - Recent searches display when focused and empty
/// - Clear functionality
/// - Accessibility support
class GlobalSearchBar extends ConsumerStatefulWidget {
  const GlobalSearchBar({super.key});

  @override
  ConsumerState<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends ConsumerState<GlobalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showRecentSearches = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync controller with provider state after widget is built
    final currentQuery = ref.read(searchQueryProvider);
    if (currentQuery.isNotEmpty && _controller.text != currentQuery) {
      _controller.text = currentQuery;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final hasFocus = _focusNode.hasFocus;
    final query = _controller.text.trim();
    
    setState(() {
      _showRecentSearches = hasFocus && query.isEmpty;
    });
  }

  void _onTextChanged() {
    final query = _controller.text;
    ref.read(searchQueryProvider.notifier).setQuery(query);
    
    // Hide recent searches when user starts typing
    if (query.isNotEmpty && _showRecentSearches) {
      setState(() {
        _showRecentSearches = false;
      });
    }
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    ref.read(searchResultsProvider.notifier).clear();
    setState(() {
      _showRecentSearches = _focusNode.hasFocus;
    });
  }

  void _selectRecentSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchQueryProvider.notifier).setQuery(query);
    setState(() {
      _showRecentSearches = false;
    });
    // Focus will trigger search via debounced provider
  }

  Future<void> _clearRecentSearches() async {
    await ref.read(clearRecentSearchesProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recent searches cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsState = ref.watch(searchResultsProvider);
    final recentSearchesAsync = ref.watch(recentSearchesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Semantics(
            label: 'Search memories',
            hint: 'Type to search your memories by title, description, or tags',
            textField: true,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search memories…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? Semantics(
                        label: 'Clear search',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        
        // Recent searches (when focused and empty)
        if (_showRecentSearches)
          _buildRecentSearches(recentSearchesAsync),
        
        // Loading indicator
        if (searchQuery.isNotEmpty && searchResultsState.isLoading)
          Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        
        // Error state
        if (searchQuery.isNotEmpty &&
            searchResultsState.errorMessage != null &&
            !searchResultsState.isLoading)
          _buildErrorState(searchResultsState.errorMessage!),
        
        // Empty state (no results)
        if (searchQuery.isNotEmpty &&
            !searchResultsState.isLoading &&
            searchResultsState.errorMessage == null &&
            searchResultsState.items.isEmpty)
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildRecentSearches(AsyncValue<List<RecentSearch>> recentSearchesAsync) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: recentSearchesAsync.when(
        data: (searches) {
          if (searches.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No recent searches',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent searches',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    TextButton(
                      onPressed: _clearRecentSearches,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searches.length,
                  itemBuilder: (context, index) {
                    final search = searches[index];
                    return ListTile(
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(search.query),
                      onTap: () => _selectRecentSearch(search.query),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load recent searches',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Can't load results. Tap to retry.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(searchResultsProvider.notifier).refresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No memories match your search',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/search_result.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/widgets/search_result_card.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';

/// List widget for displaying search results with pagination
/// 
/// Features:
/// - Displays list of search result cards
/// - "Load more" button when more results are available
/// - Loading states
/// - Navigation to detail screens on tap
class SearchResultsList extends ConsumerWidget {
  final List<SearchResult> results;
  final String query;
  final bool hasMore;
  final bool isLoadingMore;

  const SearchResultsList({
    super.key,
    required this.results,
    required this.query,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show "Load more" button at the end
        if (index == results.length) {
          return _buildLoadMoreButton(context, ref);
        }

        final result = results[index];
        return SearchResultCard(
          result: result,
          query: query,
          onTap: () => _navigateToDetail(context, result, index),
        );
      },
    );
  }

  /// Build "Load more" button
  Widget _buildLoadMoreButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoadingMore
              ? null
              : () {
                  ref.read(searchResultsProvider.notifier).loadMore();
                },
          child: isLoadingMore
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Load more results'),
        ),
      ),
    );
  }

  /// Navigate to memory detail screen
  void _navigateToDetail(
    BuildContext context,
    SearchResult result,
    int position,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          momentId: result.id,
        ),
      ),
    );
  }
}


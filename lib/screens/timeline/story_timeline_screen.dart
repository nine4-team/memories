import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/widgets/story_card.dart';
import 'package:memories/widgets/timeline_header.dart';
import 'package:memories/widgets/timeline_search_bar.dart';
import 'package:memories/widgets/skeleton_loader.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

/// Story-only timeline screen displaying Stories in reverse chronological order
/// 
/// Reuses the unified timeline infrastructure but filters to Stories only.
/// Maintains the same pagination, pull-to-refresh, and error handling patterns
/// as the unified timeline.
class StoryTimelineScreen extends ConsumerStatefulWidget {
  const StoryTimelineScreen({super.key});

  @override
  ConsumerState<StoryTimelineScreen> createState() => _StoryTimelineScreenState();
}

class _StoryTimelineScreenState extends ConsumerState<StoryTimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageStorageKey _pageStorageKey = const PageStorageKey('story_timeline');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storyTimelineFeedNotifierProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    
    // Track scroll depth
    if (maxScroll > 0) {
      final scrollDepth = ((position.pixels / maxScroll) * 100).round();
      final timelineState = ref.read(storyTimelineFeedNotifierProvider);
      ref.read(timelineAnalyticsServiceProvider).trackScrollDepth(
        scrollDepth,
        timelineState.moments.length,
      );
    }
    
    if (position.pixels >= maxScroll * 0.8) {
      // Load more when 80% scrolled
      final searchQuery = ref.read(searchQueryNotifierProvider);
      ref.read(storyTimelineFeedNotifierProvider.notifier).loadMore(
            searchQuery: searchQuery.isEmpty ? null : searchQuery,
          );
    }
  }

  Future<void> _onRefresh() async {
    ref.read(timelineAnalyticsServiceProvider).trackPullToRefresh();
    final searchQuery = ref.read(searchQueryNotifierProvider);
    await ref.read(storyTimelineFeedNotifierProvider.notifier).refresh(
          searchQuery: searchQuery.isEmpty ? null : searchQuery,
        );
  }

  void _navigateToStoryDetail(String storyId, int position) {
    ref.read(timelineAnalyticsServiceProvider).trackMomentCardTap(
      storyId,
      position,
      false, // Stories don't have media thumbnails
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          momentId: storyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(storyTimelineFeedNotifierProvider);
    final searchQuery = ref.watch(searchQueryNotifierProvider);
    // TODO: Implement proper connectivity checking
    final isOnline = true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          const TimelineSearchBar(),
          // Offline banner
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Offline - Showing cached content',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ],
              ),
            ),
          // Timeline content
          Expanded(
            child: _buildTimelineContent(timelineState, searchQuery),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(
    TimelineFeedState state,
    String searchQuery,
  ) {
    switch (state.state) {
      case TimelineState.initial:
      case TimelineState.loading:
        return _buildLoadingState();
      case TimelineState.empty:
        return _buildEmptyState(searchQuery);
      case TimelineState.error:
        return _buildErrorState(state.errorMessage);
      case TimelineState.loaded:
      case TimelineState.loadingMore:
        return _buildTimelineList(state);
    }
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 5,
        itemBuilder: (context, index) => const MomentCardSkeleton(),
      ),
    );
  }

  Widget _buildEmptyState(String searchQuery) {
    final emptyMessage = searchQuery.isNotEmpty
        ? 'No stories found for your search'
        : 'No stories yet';
    final emptyHint = searchQuery.isNotEmpty
        ? 'Try a different search term'
        : 'Record your first story to get started';

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Semantics(
          label: emptyMessage,
          hint: emptyHint,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: searchQuery.isNotEmpty ? 'No search results' : 'Empty story timeline',
                    excludeSemantics: true,
                    child: Icon(
                      searchQuery.isNotEmpty ? Icons.search_off : Icons.mic_none_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'No stories found'
                        : 'No stories yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Clear search and show all stories',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(searchQueryNotifierProvider.notifier).clear();
                          ref.read(storyTimelineFeedNotifierProvider.notifier).loadInitial();
                        },
                        child: const Text('Clear search'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Semantics(
          label: 'Error loading stories',
          hint: errorMessage ?? 'An error occurred',
          liveRegion: true,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: 'Error icon',
                    excludeSemantics: true,
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load stories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Error details: $errorMessage',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          errorMessage,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Retry loading stories',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(storyTimelineFeedNotifierProvider.notifier).loadInitial();
                      },
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineList(TimelineFeedState state) {
    final stories = state.moments;
    final isLoadingMore = state.state == TimelineState.loadingMore;

    // Group stories by hierarchy
    final groupedStories = _groupStoriesByHierarchy(stories);
    
    // Pre-calculate positions for all stories
    final storyPositions = <String, int>{};
    int position = 0;
    for (final story in stories) {
      storyPositions[story.id] = position++;
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        key: _pageStorageKey,
        controller: _scrollController,
        slivers: [
          // Build grouped list with headers
          ...groupedStories.entries.expand((entry) {
            final year = entry.key;
            final seasonMap = entry.value;
            return [
              YearHeader(year: year),
              ...seasonMap.entries.expand((seasonEntry) {
                final season = seasonEntry.key;
                final monthMap = seasonEntry.value;
                return [
                  SeasonHeader(season: season),
                  ...monthMap.entries.expand((monthEntry) {
                    final month = monthEntry.key;
                    final monthStories = monthEntry.value;
                    return [
                      MonthHeader(month: month),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final story = monthStories[index];
                            final position = storyPositions[story.id] ?? 0;
                            
                            return StoryCard(
                              story: story,
                              onTap: () => _navigateToStoryDetail(
                                story.id,
                                position,
                              ),
                            );
                          },
                          childCount: monthStories.length,
                        ),
                      ),
                    ];
                  }),
                ];
              }),
            ];
          }),
          // Loading more indicator
          if (isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          // End of list message
          if (!state.hasMore && stories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        "You've reached the beginning",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to capture screen for story recording
                        },
                        child: const Text('Record a new story'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Group stories by Year → Season → Month hierarchy
  Map<int, Map<String, Map<int, List<TimelineMoment>>>> _groupStoriesByHierarchy(
    List<TimelineMoment> stories,
  ) {
    final grouped = <int, Map<String, Map<int, List<TimelineMoment>>>>{};

    for (final story in stories) {
      grouped.putIfAbsent(story.year, () => {});
      final yearMap = grouped[story.year]!;

      yearMap.putIfAbsent(story.season, () => {});
      final seasonMap = yearMap[story.season]!;

      seasonMap.putIfAbsent(story.month, () => []);
      seasonMap[story.month]!.add(story);
    }

    return grouped;
  }
}


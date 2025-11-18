import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/widgets/moment_card.dart';
import 'package:memories/widgets/story_card.dart';
import 'package:memories/widgets/memento_card.dart';
import 'package:memories/widgets/timeline_header.dart';
import 'package:memories/widgets/timeline_search_bar.dart';
import 'package:memories/widgets/skeleton_loader.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

/// Main timeline screen displaying Moments in reverse chronological order
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageStorageKey _pageStorageKey = const PageStorageKey('timeline');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unifiedTimelineFeedNotifierProvider.notifier).loadInitial();
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
      final timelineState = ref.read(unifiedTimelineFeedNotifierProvider);
      ref.read(timelineAnalyticsServiceProvider).trackScrollDepth(
        scrollDepth,
        timelineState.moments.length,
      );
    }
    
    if (position.pixels >= maxScroll * 0.8) {
      // Load more when 80% scrolled
      final searchQuery = ref.read(searchQueryNotifierProvider);
      ref.read(unifiedTimelineFeedNotifierProvider.notifier).loadMore(
            searchQuery: searchQuery.isEmpty ? null : searchQuery,
          );
    }
  }

  Future<void> _onRefresh() async {
    ref.read(timelineAnalyticsServiceProvider).trackPullToRefresh();
    final searchQuery = ref.read(searchQueryNotifierProvider);
    await ref.read(unifiedTimelineFeedNotifierProvider.notifier).refresh(
          searchQuery: searchQuery.isEmpty ? null : searchQuery,
        );
  }

  void _navigateToMomentDetail(String momentId, int position, bool hasMedia) {
    ref.read(timelineAnalyticsServiceProvider).trackMomentCardTap(
      momentId,
      position,
      hasMedia,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          momentId: momentId,
          heroTag: hasMedia ? 'moment_thumbnail_$momentId' : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(unifiedTimelineFeedNotifierProvider);
    final searchQuery = ref.watch(searchQueryNotifierProvider);
    // TODO: Implement proper connectivity checking
    final isOnline = true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
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
        ? 'No memories found for your search'
        : 'No memories yet';
    final emptyHint = searchQuery.isNotEmpty
        ? 'Try a different search term'
        : 'Capture your first memory to get started';

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
                    label: searchQuery.isNotEmpty ? 'No search results' : 'Empty timeline',
                    excludeSemantics: true,
                    child: Icon(
                      searchQuery.isNotEmpty ? Icons.search_off : Icons.photo_library_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'No memories found'
                        : 'No memories yet',
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
                      label: 'Clear search and show all memories',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(searchQueryNotifierProvider.notifier).clear();
                          ref.read(unifiedTimelineFeedNotifierProvider.notifier).loadInitial();
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
          label: 'Error loading memories',
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
                    'Failed to load memories',
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
                    label: 'Retry loading memories',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(unifiedTimelineFeedNotifierProvider.notifier).loadInitial();
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
    final moments = state.moments;
    final isLoadingMore = state.state == TimelineState.loadingMore;

    // Group moments by hierarchy
    final groupedMoments = _groupMomentsByHierarchy(moments);
    
    // Pre-calculate positions for all moments
    final momentPositions = <String, int>{};
    int position = 0;
    for (final moment in moments) {
      momentPositions[moment.id] = position++;
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        key: _pageStorageKey,
        controller: _scrollController,
        slivers: [
          // Build grouped list with headers
          ...groupedMoments.entries.expand((entry) {
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
                    final monthMoments = monthEntry.value;
                    return [
                      MonthHeader(month: month),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final moment = monthMoments[index];
                            final position = momentPositions[moment.id] ?? 0;
                            
                            // Use appropriate card widget based on memory type
                            final memoryType = moment.memoryType.toLowerCase();
                            if (memoryType == 'memento') {
                              return MementoCard(
                                memento: moment,
                                onTap: () => _navigateToMomentDetail(
                                  moment.id,
                                  position,
                                  moment.primaryMedia != null,
                                ),
                              );
                            } else if (memoryType == 'story') {
                              return StoryCard(
                                story: moment,
                                onTap: () => _navigateToMomentDetail(
                                  moment.id,
                                  position,
                                  moment.primaryMedia != null,
                                ),
                              );
                            } else {
                              // Default to MomentCard for moments
                              return MomentCard(
                                moment: moment,
                                onTap: () => _navigateToMomentDetail(
                                  moment.id,
                                  position,
                                  moment.primaryMedia != null,
                                ),
                              );
                            }
                          },
                          childCount: monthMoments.length,
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
          if (!state.hasMore && moments.isNotEmpty)
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
                          // TODO: Navigate to capture screen
                        },
                        child: const Text('Capture a new memory'),
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

  /// Group moments by Year → Season → Month hierarchy
  Map<int, Map<String, Map<int, List<TimelineMoment>>>> _groupMomentsByHierarchy(
    List<TimelineMoment> moments,
  ) {
    final grouped = <int, Map<String, Map<int, List<TimelineMoment>>>>{};

    for (final moment in moments) {
      grouped.putIfAbsent(moment.year, () => {});
      final yearMap = grouped[moment.year]!;

      yearMap.putIfAbsent(moment.season, () => {});
      final seasonMap = yearMap[moment.season]!;

      seasonMap.putIfAbsent(moment.month, () => []);
      seasonMap[moment.month]!.add(moment);
    }

    return grouped;
  }
}


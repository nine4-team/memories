import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/widgets/unified_feed_segmented_control.dart';
import 'package:memories/widgets/memory_card.dart';
import 'package:memories/widgets/memory_header.dart';
import 'package:memories/widgets/unified_feed_empty_state.dart';
import 'package:memories/widgets/unified_feed_skeleton.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';

/// Unified Timeline screen displaying Stories, Moments, and Mementos
/// in a single reverse-chronological feed with filtering and grouping.
class UnifiedTimelineScreen extends ConsumerStatefulWidget {
  const UnifiedTimelineScreen({super.key});

  @override
  ConsumerState<UnifiedTimelineScreen> createState() =>
      _UnifiedTimelineScreenState();
}

class _UnifiedTimelineScreenState extends ConsumerState<UnifiedTimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageStorageKey _pageStorageKey =
      const PageStorageKey('unified_timeline');
  MemoryType? _previousTab;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      final tabState = ref.read(unifiedFeedTabNotifierProvider);
      tabState.whenData((selectedTab) {
        final controller = _getControllerForTab(selectedTab);
        final feedState = ref.read(controller);
        ref.read(timelineAnalyticsServiceProvider).trackScrollDepth(
              scrollDepth,
              feedState.memories.length,
            );
      });
    }

    // Load more when 80% scrolled
    if (position.pixels >= maxScroll * 0.8) {
      final tabState = ref.read(unifiedFeedTabNotifierProvider);
      tabState.whenData((selectedTab) {
        final controller = _getControllerForTab(selectedTab);
        final feedState = ref.read(controller);

        // Only load more if we have more to load and aren't already loading
        if (feedState.hasMore &&
            feedState.state != UnifiedFeedState.appending) {
          ref.read(controller.notifier).loadMore();
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    ref.read(timelineAnalyticsServiceProvider).trackPullToRefresh();

    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    await tabState.whenData((selectedTab) async {
      final controller = _getControllerForTab(selectedTab);
      await ref.read(controller.notifier).refresh();
    });
  }

  void _navigateToDetail(TimelineMoment memory, int position) {
    final memoryType = _getMemoryType(memory.memoryType);
    ref.read(timelineAnalyticsServiceProvider).trackUnifiedFeedCardTap(
          memory.id,
          memoryType.apiValue,
          position,
          memory.primaryMedia != null,
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          momentId: memory.id,
          heroTag: memory.primaryMedia != null
              ? 'memory_thumbnail_${memory.id}'
              : null,
        ),
      ),
    );
  }

  MemoryType _getMemoryType(String memoryType) {
    switch (memoryType.toLowerCase()) {
      case 'story':
        return MemoryType.story;
      case 'memento':
        return MemoryType.memento;
      case 'moment':
      default:
        return MemoryType.moment;
    }
  }

  /// Get the appropriate controller provider for the selected tab
  dynamic _getControllerForTab(MemoryType? tab) {
    switch (tab) {
      case MemoryType.story:
        return unifiedFeedStoryProvider;
      case MemoryType.moment:
        return unifiedFeedMomentProvider;
      case MemoryType.memento:
        return unifiedFeedMementoProvider;
      case null:
        return unifiedFeedProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Segmented control for filtering
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: UnifiedFeedSegmentedControl(),
          ),
          // Timeline content
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                // Watch tab changes
                final tabState = ref.watch(unifiedFeedTabNotifierProvider);

                return tabState.when(
                  data: (selectedTab) {
                    // Get the appropriate controller for the selected tab
                    final controller = _getControllerForTab(selectedTab);
                    final feedState = ref.watch(controller);

                    // Handle tab change - update filter which will reload
                    if (_previousTab != selectedTab) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(controller.notifier).setFilter(selectedTab);
                      });
                      _previousTab = selectedTab;
                    } else if (feedState.state == UnifiedFeedState.initial) {
                      // Initial load for the current tab
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(controller.notifier).loadInitial();
                      });
                    }

                    return _buildTimelineContent(feedState, selectedTab);
                  },
                  loading: () => const UnifiedFeedSkeletonList(),
                  error: (error, stack) => _buildErrorState(
                    'Failed to load tab selection: ${error.toString()}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(
    UnifiedFeedViewState state,
    MemoryType? currentFilter,
  ) {
    switch (state.state) {
      case UnifiedFeedState.initial:
      case UnifiedFeedState.loading:
        return _buildLoadingState();
      case UnifiedFeedState.empty:
        return _buildEmptyState(currentFilter);
      case UnifiedFeedState.error:
        return _buildErrorState(state.errorMessage);
      case UnifiedFeedState.ready:
      case UnifiedFeedState.appending:
      case UnifiedFeedState.paginationError:
        return _buildTimelineList(state, currentFilter);
    }
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: const UnifiedFeedSkeletonList(),
    );
  }

  Widget _buildEmptyState(MemoryType? currentFilter) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: UnifiedFeedEmptyState(
          currentFilter: currentFilter,
          onCaptureTap: () {
            // TODO: Navigate to capture screen
          },
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                        final tabState =
                            ref.read(unifiedFeedTabNotifierProvider);
                        tabState.whenData((selectedTab) {
                          final controller = _getControllerForTab(selectedTab);
                          ref.read(controller.notifier).loadInitial();
                        });
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

  Widget _buildTimelineList(
    UnifiedFeedViewState state,
    MemoryType? currentFilter,
  ) {
    final memories = state.memories;
    final isLoadingMore = state.state == UnifiedFeedState.appending;
    final isPaginationError = state.state == UnifiedFeedState.paginationError;

    // Group memories by hierarchy: Year → Season → Month
    final groupedMemories = _groupMemoriesByHierarchy(memories);

    // Pre-calculate positions for all memories
    final memoryPositions = <String, int>{};
    int position = 0;
    for (final memory in memories) {
      memoryPositions[memory.id] = position++;
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        key: _pageStorageKey,
        controller: _scrollController,
        slivers: [
          // Build grouped list with headers
          ...groupedMemories.entries.expand((entry) {
            final year = entry.key;
            final seasonMap = entry.value;
            return [
              MemoryYearHeader(year: year),
              ...seasonMap.entries.expand((seasonEntry) {
                final season = seasonEntry.key;
                final monthMap = seasonEntry.value;
                return [
                  MemorySeasonHeader(season: season),
                  ...monthMap.entries.expand((monthEntry) {
                    final month = monthEntry.key;
                    final monthMemories = monthEntry.value;
                    return [
                      MemoryMonthHeader(month: month),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final memory = monthMemories[index];
                            final position = memoryPositions[memory.id] ?? 0;

                            return MemoryCard(
                              memory: memory,
                              onTap: () => _navigateToDetail(memory, position),
                            );
                          },
                          childCount: monthMemories.length,
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
          // Pagination error with retry
          if (isPaginationError && memories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Failed to load more memories',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            final tabState =
                                ref.read(unifiedFeedTabNotifierProvider);
                            tabState.whenData((selectedTab) {
                              final controller =
                                  _getControllerForTab(selectedTab);
                              ref.read(controller.notifier).loadMore();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // End of list message
          if (!state.hasMore && memories.isNotEmpty && !isPaginationError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        "You've reached the beginning",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

  /// Group memories by Year → Season → Month hierarchy
  Map<int, Map<String, Map<int, List<TimelineMoment>>>>
      _groupMemoriesByHierarchy(List<TimelineMoment> memories) {
    final grouped = <int, Map<String, Map<int, List<TimelineMoment>>>>{};

    for (final memory in memories) {
      grouped.putIfAbsent(memory.year, () => {});
      final yearMap = grouped[memory.year]!;

      yearMap.putIfAbsent(memory.season, () => {});
      final seasonMap = yearMap[memory.season]!;

      seasonMap.putIfAbsent(memory.month, () => []);
      seasonMap[memory.month]!.add(memory);
    }

    return grouped;
  }
}

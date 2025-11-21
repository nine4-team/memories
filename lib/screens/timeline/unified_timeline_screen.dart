import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/providers/main_navigation_provider.dart';
import 'package:memories/widgets/unified_feed_segmented_control.dart';
import 'package:memories/widgets/memory_card.dart';
import 'package:memories/widgets/year_sidebar.dart';
import 'package:memories/widgets/unified_feed_empty_state.dart';
import 'package:memories/widgets/unified_feed_skeleton.dart';
import 'package:memories/widgets/global_search_bar.dart';
import 'package:memories/widgets/search_results_list.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/screens/memory/memory_detail_screen.dart';

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
  Set<MemoryType>? _previousSelectedTypes;
  int? _activeYear;
  final Map<int, GlobalKey> _yearKeys = {};

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
      tabState.whenData((selectedTypes) {
        final controller = unifiedFeedControllerProvider(selectedTypes);
        final feedState = ref.read(controller);
        ref.read(timelineAnalyticsServiceProvider).trackScrollDepth(
              scrollDepth,
              feedState.memories.length,
            );
      });
    }

    // Update active year based on scroll position
    _updateActiveYear(position.pixels);

    // Load more when 80% scrolled
    if (position.pixels >= maxScroll * 0.8) {
      final tabState = ref.read(unifiedFeedTabNotifierProvider);
      tabState.whenData((selectedTypes) {
        final controller = unifiedFeedControllerProvider(selectedTypes);
        final feedState = ref.read(controller);

        // Only load more if we have more to load and aren't already loading
        if (feedState.hasMore &&
            feedState.state != UnifiedFeedState.appending) {
          ref.read(controller.notifier).loadMore();
        }
      });
    }
  }

  void _updateActiveYear(double scrollOffset) {
    if (_yearKeys.isEmpty || !_scrollController.hasClients) return;

    const revealThreshold = 120.0;
    int? newActiveYear;

    // Iterate from oldest to newest so the first match represents
    // the deepest year currently revealed in the viewport.
    for (final entry in _yearKeys.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      final year = entry.key;
      final context = entry.value.currentContext;
      if (context == null) continue;

      final renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) continue;

      try {
        final viewport = RenderAbstractViewport.of(renderObject);
        final targetOffset =
            viewport.getOffsetToReveal(renderObject, 0).offset;
        if (targetOffset <= scrollOffset + revealThreshold) {
          newActiveYear = year;
          break;
        }
      } catch (_) {
        // Ignore measurement errors triggered during layout changes.
      }
    }

    // Fallback: use first memory's year if at top
    if (newActiveYear == null) {
      final tabState = ref.read(unifiedFeedTabNotifierProvider);
      tabState.whenData((selectedTypes) {
        final controller = unifiedFeedControllerProvider(selectedTypes);
        final feedState = ref.read(controller);
        if (feedState.memories.isNotEmpty && scrollOffset < revealThreshold) {
          newActiveYear = feedState.memories.first.year;
        }
      });
    }

    if (newActiveYear != null && newActiveYear != _activeYear) {
      setState(() {
        _activeYear = newActiveYear;
      });
    }
  }

  Future<void> _scrollToYear(int year) async {
    await _ensureYearDataLoaded(year);
    await _waitForYearRender(year);

    if (!mounted) return;

    if (_activeYear != year) {
      setState(() {
        _activeYear = year;
      });
    }

    final key = _yearKeys[year];
    if (key != null && key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _ensureYearDataLoaded(int year) async {
    final tabState = ref.read(unifiedFeedTabNotifierProvider);

    await tabState.whenData((selectedTypes) async {
      final controller = unifiedFeedControllerProvider(selectedTypes);

      while (mounted) {
        final feedState = ref.read(controller);
        final hasYearLoaded =
            feedState.memories.any((memory) => memory.year == year);
        final cannotLoadMore = !feedState.hasMore ||
            feedState.state == UnifiedFeedState.paginationError;
        final isCurrentlyLoading = feedState.state == UnifiedFeedState.appending;

        if (hasYearLoaded || cannotLoadMore) {
          break;
        }

        if (isCurrentlyLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 32));
          continue;
        }

        await ref.read(controller.notifier).loadMore();
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    });
  }

  Future<void> _waitForYearRender(int year) async {
    const maxAttempts = 30;
    int attempts = 0;

    while (mounted && attempts < maxAttempts) {
      final key = _yearKeys[year];
      if (key != null && key.currentContext != null) {
        return;
      }

      attempts++;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _onRefresh() async {
    ref.read(timelineAnalyticsServiceProvider).trackPullToRefresh();

    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    await tabState.whenData((selectedTypes) async {
      final controller = unifiedFeedControllerProvider(selectedTypes);
      await ref.read(controller.notifier).refresh();
    });
  }

  void _navigateToDetail(TimelineMemory memory, int position) {
    final memoryType = _getMemoryType(memory.memoryType);
    ref.read(timelineAnalyticsServiceProvider).trackUnifiedFeedCardTap(
          memory.id,
          memoryType.apiValue,
          position,
          memory.primaryMedia != null,
        );

    // Check if we can open detail offline
    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    final selectedTypes = tabState.valueOrNull ?? {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };
    final feedState = ref.read(unifiedFeedControllerProvider(selectedTypes));
    final isOffline = feedState.isOffline;
    
    final canOpenDetailOffline = memory.isOfflineQueued || memory.isDetailCachedLocally;
    final isPreviewOnlyOffline = isOffline && memory.isPreviewOnly && !canOpenDetailOffline;
    
    // If preview-only and offline, show message instead of navigating
    if (isPreviewOnlyOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This memory is not available offline yet.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Determine if this is an offline queued memory
    final isOfflineQueued = memory.isOfflineQueued;
    
    // Use localId for queued items, serverId for synced items
    final memoryId = isOfflineQueued 
        ? (memory.localId ?? memory.effectiveId)
        : (memory.serverId ?? memory.effectiveId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemoryDetailScreen(
          memoryId: memoryId,
          heroTag: memory.primaryMedia != null
              ? 'memory_thumbnail_${memory.id}'
              : null,
          isOfflineQueued: isOfflineQueued,
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Consumer(
          builder: (context, ref, child) {
            final searchQuery = ref.watch(searchQueryProvider);
            if (searchQuery.isEmpty) {
              return const UnifiedFeedSegmentedControl();
            }
            return const SizedBox.shrink();
          },
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Timeline content or search results
              Column(
                children: [
                  // Spacer for search bar - will be measured dynamically
                  const SizedBox(height: 64), // Approximate, will be adjusted
                  // Timeline content or search results
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final searchQuery = ref.watch(searchQueryProvider);
                        final searchResultsState = ref.watch(searchResultsProvider);

                        // Show search results if there's an active search query
                        if (searchQuery.isNotEmpty) {
                          // Show search results list if we have results or are loading
                          if (searchResultsState.items.isNotEmpty ||
                              searchResultsState.isLoading) {
                            return SearchResultsList(
                              results: searchResultsState.items,
                              query: searchQuery,
                              hasMore: searchResultsState.hasMore,
                              isLoadingMore: searchResultsState.isLoadingMore,
                            );
                          }
                          // Empty/error states are handled by GlobalSearchBar
                          return const SizedBox.shrink();
                        }

                        // Otherwise show timeline content
                        // Watch selected types changes
                        final tabState = ref.watch(unifiedFeedTabNotifierProvider);

                        return tabState.when(
                          data: (selectedTypes) {
                            // Get the controller for the selected types
                            final controller = unifiedFeedControllerProvider(selectedTypes);
                            final feedState = ref.watch(controller);

                            // Handle selection change - update filter which will reload
                            if (_previousSelectedTypes != selectedTypes) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(controller.notifier).setFilter(selectedTypes);
                              });
                              _previousSelectedTypes = selectedTypes;
                            } else if (feedState.state == UnifiedFeedState.initial) {
                              // Initial load for the current selection
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(controller.notifier).loadInitial();
                              });
                            }

                            return _buildTimelineContent(feedState, selectedTypes);
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
              // Global search bar positioned on top - spans full width including over year sidebar
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: GlobalSearchBar(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineContent(
    UnifiedFeedViewState state,
    Set<MemoryType> currentFilters,
  ) {
    switch (state.state) {
      case UnifiedFeedState.initial:
      case UnifiedFeedState.loading:
        return _buildLoadingState();
      case UnifiedFeedState.empty:
        return _buildEmptyState(currentFilters);
      case UnifiedFeedState.error:
        return _buildErrorState(state.errorMessage);
      case UnifiedFeedState.ready:
      case UnifiedFeedState.appending:
      case UnifiedFeedState.paginationError:
        return _buildTimelineList(state, currentFilters);
    }
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: const UnifiedFeedSkeletonList(),
    );
  }

  Widget _buildEmptyState(Set<MemoryType> currentFilters) {
    // Check if offline
    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    final isOffline = tabState.whenData((selectedTypes) {
      final feedState = ref.read(unifiedFeedControllerProvider(selectedTypes));
      return feedState.isOffline;
    }).valueOrNull ?? false;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: isOffline
            ? _OfflineEmptyTimelineMessage(
                onCaptureTap: () {
                  // Switch to capture tab in main navigation
                  ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
                },
              )
            : UnifiedFeedEmptyState(
                currentFilter: currentFilters.length == 1 ? currentFilters.first : null,
                onCaptureTap: () {
                  // Switch to capture tab in main navigation
                  ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
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
                        tabState.whenData((selectedTypes) {
                          final controller = unifiedFeedControllerProvider(selectedTypes);
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
    Set<MemoryType> currentFilters,
  ) {
    final memories = state.memories;
    final isLoadingMore = state.state == UnifiedFeedState.appending;
    final isPaginationError = state.state == UnifiedFeedState.paginationError;

    // Group memories by Year → Month (no season)
    final groupedMemories = _groupMemoriesByYearAndMonth(memories);

    // Extract years for sidebar
    final years = groupedMemories.keys.toList()..sort((a, b) => b.compareTo(a));
    final sidebarYearsSet = <int>{
      ...state.availableYears,
      ...years,
    };
    final sidebarYears = sidebarYearsSet.toList()
      ..sort((a, b) => b.compareTo(a));

    // Keep year marker keys synchronized with the available years
    final yearSet = years.toSet();
    _yearKeys.removeWhere((year, _) => !yearSet.contains(year));
    for (final year in years) {
      _yearKeys.putIfAbsent(year, () => GlobalKey());
    }

    // Pre-calculate positions for all memories
    final memoryPositions = <String, int>{};
    int position = 0;
    for (final memory in memories) {
      memoryPositions[memory.id] = position++;
    }

    // Set initial active year if not set
    if (_activeYear == null && years.isNotEmpty) {
      _activeYear = years.first;
    }

    return Row(
      children: [
        // Year sidebar
        YearSidebar(
          years: sidebarYears,
          activeYear: _activeYear,
          onYearTap: (year) => _scrollToYear(year),
        ),
        // Timeline content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              key: _pageStorageKey,
              controller: _scrollController,
              slivers: [
                // Build grouped list with month headers (not pinned - they scroll normally)
                ...groupedMemories.entries.expand((entry) {
                  final year = entry.key;
                  final monthMap = entry.value;
                  
                  return monthMap.entries.expand((monthEntry) {
                    final month = monthEntry.key;
                    final monthMemories = monthEntry.value;
                    final sortedMonths = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));
                    final monthIndex = sortedMonths.indexOf(month);
                    final isFirstMonth = monthIndex == 0;
                    
                    return [
                      // Add invisible marker for year start (first month of each year)
                      if (isFirstMonth)
                        SliverToBoxAdapter(
                          key: _yearKeys[year],
                          child: const SizedBox(height: 0),
                        ),
                      // Month header (not pinned - scrolls normally)
                      SliverToBoxAdapter(
                        child: _buildMonthHeaderWidget(month, year),
                      ),
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
                  });
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
                            tabState.whenData((selectedTypes) {
                              final controller =
                                  unifiedFeedControllerProvider(selectedTypes);
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
                          // Switch to capture tab in main navigation
                          ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
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
          ),
        ),
      ],
    );
  }


  /// Group memories by Year → Month (no season grouping)
  Map<int, Map<int, List<TimelineMemory>>> _groupMemoriesByYearAndMonth(
    List<TimelineMemory> memories,
  ) {
    final grouped = <int, Map<int, List<TimelineMemory>>>{};

    for (final memory in memories) {
      grouped.putIfAbsent(memory.year, () => {});
      final yearMap = grouped[memory.year]!;

      yearMap.putIfAbsent(memory.month, () => []);
      yearMap[memory.month]!.add(memory);
    }

    // Sort months within each year (descending - most recent first)
    for (final yearMap in grouped.values) {
      final sortedMonths = yearMap.keys.toList()..sort((a, b) => b.compareTo(a));
      final sortedMap = <int, List<TimelineMemory>>{};
      for (final month in sortedMonths) {
        sortedMap[month] = yearMap[month]!;
      }
      yearMap.clear();
      yearMap.addAll(sortedMap);
    }

    return grouped;
  }

  String _getMonthYearLabel(int month, int year) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month - 1]} $year';
  }

  Widget _buildMonthHeaderWidget(int month, int year) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        _getMonthYearLabel(month, year),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              letterSpacing: 0.15,
            ),
      ),
    );
  }
}

/// Offline empty timeline message widget
class _OfflineEmptyTimelineMessage extends StatelessWidget {
  final VoidCallback? onCaptureTap;

  const _OfflineEmptyTimelineMessage({
    this.onCaptureTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Offline icon',
              child: const Icon(
                Icons.cloud_off,
                size: 56,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'You\'re offline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              child: Text(
                'New memories you capture will appear here and sync when you\'re back online.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (onCaptureTap != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCaptureTap,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Capture a Memory'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

/// Search bar widget for timeline with debounce
class TimelineSearchBar extends ConsumerStatefulWidget {
  const TimelineSearchBar({super.key});

  @override
  ConsumerState<TimelineSearchBar> createState() => _TimelineSearchBarState();
}

class _TimelineSearchBarState extends ConsumerState<TimelineSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _controller.text;
      ref.read(searchQueryNotifierProvider.notifier).setQuery(query);
      
      // Trigger search
      final timelineNotifier = ref.read(timelineFeedNotifierProvider.notifier);
      timelineNotifier.loadInitial(searchQuery: query.isEmpty ? null : query).then((_) {
        // Track search query after results are loaded
        if (query.isNotEmpty) {
          final timelineState = ref.read(timelineFeedNotifierProvider);
          ref.read(timelineAnalyticsServiceProvider).trackSearchQuery(
            query,
            timelineState.moments.length,
          );
        }
      });
    });
  }

  void _clearSearch() {
    ref.read(timelineAnalyticsServiceProvider).trackSearchClear();
    _controller.clear();
    ref.read(searchQueryNotifierProvider.notifier).clear();
    ref.read(timelineFeedNotifierProvider.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryNotifierProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Semantics(
        label: 'Search memories',
        hint: 'Type to search your memories by title, description, or transcript',
        textField: true,
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search memories...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? Semantics(
                    label: 'Clear search',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                      // Ensure minimum 44px hit area
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
    );
  }
}


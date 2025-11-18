import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';

/// Segmented control for unified feed filter tabs
/// 
/// Provides tabs: All, Stories, Moments, Mementos
/// Connects to UnifiedFeedTabNotifier for state management
class UnifiedFeedSegmentedControl extends ConsumerWidget {
  const UnifiedFeedSegmentedControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(unifiedFeedTabNotifierProvider).valueOrNull;

    return Semantics(
      label: 'Memory type filter',
      child: SegmentedButton<MemoryType?>(
        segments: [
          ButtonSegment<MemoryType?>(
            value: null,
            label: const Text('All'),
            icon: const Icon(Icons.grid_view),
          ),
          ButtonSegment<MemoryType?>(
            value: MemoryType.story,
            label: Text(MemoryType.story.displayName),
            icon: const Icon(Icons.book),
          ),
          ButtonSegment<MemoryType?>(
            value: MemoryType.moment,
            label: Text(MemoryType.moment.displayName),
            icon: const Icon(Icons.access_time),
          ),
          ButtonSegment<MemoryType?>(
            value: MemoryType.memento,
            label: Text(MemoryType.memento.displayName),
            icon: const Icon(Icons.inventory_2),
          ),
        ],
        selected: {selectedTab},
        onSelectionChanged: (Set<MemoryType?> selection) {
          if (selection.isNotEmpty) {
            ref.read(unifiedFeedTabNotifierProvider.notifier).setTab(selection.first);
          } else {
            // If deselected, default to 'all' (null)
            ref.read(unifiedFeedTabNotifierProvider.notifier).setTab(null);
          }
        },
      ),
    );
  }
}


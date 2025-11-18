import 'package:flutter/material.dart';
import 'package:memories/models/memory_type.dart';

/// Empty state widget for unified feed
/// 
/// Shows different messages based on whether there are no memories at all
/// or no results for the current filter.
class UnifiedFeedEmptyState extends StatelessWidget {
  final MemoryType? currentFilter;
  final VoidCallback? onCaptureTap;

  const UnifiedFeedEmptyState({
    super.key,
    this.currentFilter,
    this.onCaptureTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered = currentFilter != null;
    
    final title = isFiltered
        ? _getFilteredEmptyTitle(currentFilter!)
        : 'No memories yet';
    
    final message = isFiltered
        ? _getFilteredEmptyMessage(currentFilter!)
        : 'Start capturing your memories to see them here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Empty state illustration',
              child: Icon(
                isFiltered ? Icons.filter_alt_outlined : Icons.photo_library_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (!isFiltered && onCaptureTap != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onCaptureTap,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Capture a Memory'),
              ),
            ],
            if (isFiltered) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  // This will be handled by the parent screen
                  // by clearing the filter
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFilteredEmptyTitle(MemoryType filter) {
    switch (filter) {
      case MemoryType.story:
        return 'No stories found';
      case MemoryType.moment:
        return 'No moments found';
      case MemoryType.memento:
        return 'No mementos found';
    }
  }

  String _getFilteredEmptyMessage(MemoryType filter) {
    switch (filter) {
      case MemoryType.story:
        return 'You haven\'t created any stories yet. Switch to "All" to see all your memories.';
      case MemoryType.moment:
        return 'You haven\'t created any moments yet. Switch to "All" to see all your memories.';
      case MemoryType.memento:
        return 'You haven\'t created any mementos yet. Switch to "All" to see all your memories.';
    }
  }
}


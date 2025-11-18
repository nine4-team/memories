import 'package:flutter/material.dart';

/// Skeleton loader for unified feed memory cards
/// 
/// Mirrors the unified card layout with placeholder elements
/// for thumbnail, title, metadata, and type chip.
class UnifiedFeedCardSkeleton extends StatelessWidget {
  const UnifiedFeedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail skeleton
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type chip skeleton
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title skeleton
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Snippet skeleton (optional, shown for some cards)
                  Container(
                    width: double.infinity * 0.85,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity * 0.6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Metadata skeleton
                  Container(
                    width: 120,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of skeleton loaders for initial load state
class UnifiedFeedSkeletonList extends StatelessWidget {
  final int count;
  
  const UnifiedFeedSkeletonList({
    super.key,
    this.count = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) => const UnifiedFeedCardSkeleton(),
    );
  }
}


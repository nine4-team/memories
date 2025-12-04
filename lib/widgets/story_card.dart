import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/widgets/memory_title_with_processing.dart';

/// Reusable card widget for displaying a Story in the timeline
/// 
/// Normalized layout: image on left, title/date/memory type on right.
/// Uses the same card container styles as MomentCard and MementoCard for
/// visual consistency.
class StoryCard extends ConsumerWidget {
  final TimelineMemory story;
  final VoidCallback onTap;
  final bool isOffline;

  const StoryCard({
    super.key,
    required this.story,
    required this.onTap,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    // Determine offline states
    final isPreviewOnlyOffline =
        isOffline && story.isPreviewOnly && !story.isDetailCachedLocally;
    final isQueuedOffline = story.isOfflineQueued;

    // Build semantic label with all relevant information
    // Format: "Story titled [title] recorded [absolute date]"
    final absoluteTime = _formatAbsoluteTimestamp(story.capturedAt, locale);
    final semanticLabel = StringBuffer('Story');
    if (story.displayTitle.isNotEmpty && story.displayTitle != 'Untitled Story') {
      semanticLabel.write(' titled ${story.displayTitle}');
    }
    semanticLabel.write(' recorded $absoluteTime');
    if (isQueuedOffline) {
      semanticLabel.write(', pending sync');
    }
    if (isPreviewOnlyOffline) {
      semanticLabel.write(', not available offline');
    }

    return Semantics(
      label: semanticLabel.toString(),
      button: true,
      hint: 'Double tap to view story details',
      child: Opacity(
        opacity: isPreviewOnlyOffline ? 0.5 : 1.0,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: _buildCardShape(context, isQueuedOffline, isPreviewOnlyOffline),
          child: InkWell(
            onTap: isPreviewOnlyOffline
                ? () => _showNotAvailableOfflineMessage(context)
                : onTap,
            borderRadius: BorderRadius.circular(12),
            // Ensure minimum 44px hit area for accessibility
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 44,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail section - placeholder icon for stories
                        _buildThumbnail(context, theme),
                        const SizedBox(width: 16),
                        // Content section
                        Expanded(
                          child: _buildContent(context, theme, locale),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Footer badges
                    _buildFooterBadges(context, isQueuedOffline, isPreviewOnlyOffline),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ShapeBorder _buildCardShape(
    BuildContext context,
    bool isQueuedOffline,
    bool isPreviewOnlyOffline,
  ) {
    if (isQueuedOffline) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300, width: 1),
      );
    }
    if (isPreviewOnlyOffline) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade400, width: 0.5),
      );
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildFooterBadges(
    BuildContext context,
    bool isQueuedOffline,
    bool isPreviewOnlyOffline,
  ) {
    final badges = <Widget>[];

    // Note: Processing and sync status indicators are now shown in the title area
    // via MemoryTitleWithProcessing widget. Footer badges are deprecated for these.
    // Only show "Not available offline" chip if needed.
    if (isPreviewOnlyOffline) {
      badges.add(_buildPreviewOnlyChip(context));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        ...badges.map((b) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: b,
            )),
      ],
    );
  }

  Widget _buildPreviewOnlyChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Not available offline',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade800,
            ),
      ),
    );
  }

  void _showNotAvailableOfflineMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This memory is not available offline yet.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ThemeData theme) {
    const thumbnailSize = 80.0;

    return Semantics(
      label: 'Story icon',
      image: true,
      child: Container(
        width: thumbnailSize,
        height: thumbnailSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            MemoryType.story.icon,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with processing indicator
        MemoryTitleWithProcessing.timeline(
          memory: story,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Date - shows actual date
        Semantics(
          label: 'Recorded ${_formatAbsoluteTimestamp(story.capturedAt, locale)}',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Calendar icon',
                excludeSemantics: true,
                child: Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _formatAbsoluteTimestamp(story.capturedAt, locale),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Location display
        if (story.memoryLocationData?.formattedLocation != null)
          Semantics(
            label: 'Location: ${story.memoryLocationData!.formattedLocation}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    story.memoryLocationData!.formattedLocation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Format absolute recording date: "Nov 3, 2025" (locale aware, date only)
  String _formatAbsoluteTimestamp(DateTime date, Locale locale) {
    final dateFormat = DateFormat('MMM d, y', locale.toString());
    return dateFormat.format(date);
  }
}


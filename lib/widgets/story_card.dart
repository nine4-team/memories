import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';

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

    if (isQueuedOffline) {
      badges.add(_buildSyncStatusChip(context));
    }

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

  Widget _buildSyncStatusChip(BuildContext context) {
    final status = story.offlineSyncStatus;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case OfflineSyncStatus.queued:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'Pending sync';
        break;
      case OfflineSyncStatus.syncing:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Syncing…';
        break;
      case OfflineSyncStatus.failed:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Sync failed';
        break;
      case OfflineSyncStatus.synced:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Synced';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
      ),
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
        // Title - single line, ellipsized
        Text(
          story.displayTitle,
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
        // Memory type badge
        Semantics(
          label: 'Story badge',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  MemoryType.story.icon,
                  size: 14,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Story',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Format absolute timestamp: "Nov 3, 2025 at 4:12 PM" (locale aware)
  String _formatAbsoluteTimestamp(DateTime date, Locale locale) {
    final dateFormat = DateFormat('MMM d, y', locale.toString());
    final timeFormat = DateFormat('h:mm a', locale.toString());
    return '${dateFormat.format(date)} at ${timeFormat.format(date)}';
  }
}


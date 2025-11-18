import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_moment.dart';

/// Reusable card widget for displaying a Story in the timeline
/// 
/// Shows only title and friendly timestamp, maintaining minimum tap target size
/// for accessibility. Uses the same card container styles as MomentCard for
/// visual consistency.
class StoryCard extends ConsumerWidget {
  final TimelineMoment story;
  final VoidCallback onTap;

  const StoryCard({
    super.key,
    required this.story,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    // Build semantic label with all relevant information
    // Format: "Story titled [title] recorded [absolute date], [relative time]"
    final absoluteTime = _formatAbsoluteTimestamp(story.capturedAt, locale);
    final relativeTime = _formatRelativeTimestamp(story.capturedAt);
    final semanticLabel = StringBuffer('Story');
    if (story.displayTitle.isNotEmpty && story.displayTitle != 'Untitled Story') {
      semanticLabel.write(' titled ${story.displayTitle}');
    }
    semanticLabel.write(' recorded $absoluteTime');
    if (relativeTime.isNotEmpty) {
      semanticLabel.write(', $relativeTime');
    }

    return Semantics(
      label: semanticLabel.toString(),
      button: true,
      hint: 'Double tap to view story details',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
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
                  // Friendly timestamp - shows relative time with absolute date fallback
                  Semantics(
                    label: 'Recorded ${_formatRelativeTimestamp(story.capturedAt).isNotEmpty ? _formatRelativeTimestamp(story.capturedAt) : _formatAbsoluteTimestamp(story.capturedAt, locale)}',
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
                          _formatRelativeTimestamp(story.capturedAt).isNotEmpty
                              ? _formatRelativeTimestamp(story.capturedAt)
                              : _formatAbsoluteTimestamp(story.capturedAt, locale),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  /// Format absolute timestamp: "Nov 3, 2025 at 4:12 PM" (locale aware)
  String _formatAbsoluteTimestamp(DateTime date, Locale locale) {
    final dateFormat = DateFormat('MMM d, y', locale.toString());
    final timeFormat = DateFormat('h:mm a', locale.toString());
    return '${dateFormat.format(date)} at ${timeFormat.format(date)}';
  }

  /// Format relative timestamp: "3 weeks ago" or empty if very recent
  /// Matches the pattern used in MomentMetadataSection for consistency
  String _formatRelativeTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Same day - show relative time within day
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}


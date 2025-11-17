import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/moment_detail.dart';

/// Widget displaying moment metadata: timestamp, location, and related memories
/// 
/// Renders only rows that have data, ensuring seamless layout collapse when
/// metadata is missing.
class MomentMetadataSection extends StatelessWidget {
  final MomentDetail moment;

  const MomentMetadataSection({
    super.key,
    required this.moment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = moment.locationData?.formattedLocation != null;
    final hasRelatedStories = moment.relatedStories.isNotEmpty;
    final hasRelatedMementos = moment.relatedMementos.isNotEmpty;
    final hasRelatedMemories = hasRelatedStories || hasRelatedMementos;

    // If no metadata to show, return empty widget
    if (!hasLocation && !hasRelatedMemories) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timestamp row (always shown)
        _buildTimestampRow(context, theme),
        // Location row (only if location data exists)
        if (hasLocation) ...[
          const SizedBox(height: 12),
          _buildLocationRow(context, theme),
        ],
        // Related memories section (only if related memories exist)
        if (hasRelatedMemories) ...[
          const SizedBox(height: 12),
          _buildRelatedMemoriesSection(context, theme),
        ],
      ],
    );
  }

  Widget _buildTimestampRow(BuildContext context, ThemeData theme) {
    final absoluteTime = _formatAbsoluteTimestamp(moment.capturedAt);
    final relativeTime = _formatRelativeTimestamp(moment.capturedAt);

    return Semantics(
      label: 'Captured $absoluteTime, $relativeTime',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  absoluteTime,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (relativeTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                relativeTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, ThemeData theme) {
    final locationText = moment.locationData!.formattedLocation!;

    return Semantics(
      label: 'Location: $locationText',
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedMemoriesSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Memories',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Story chips
            ...moment.relatedStories.map((storyId) => _buildMemoryChip(
                  context,
                  theme,
                  label: 'Story',
                  memoryId: storyId,
                  memoryType: 'story',
                )),
            // Memento chips
            ...moment.relatedMementos.map((mementoId) => _buildMemoryChip(
                  context,
                  theme,
                  label: 'Memento',
                  memoryId: mementoId,
                  memoryType: 'memento',
                )),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoryChip(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String memoryId,
    required String memoryType,
  }) {
    return Semantics(
      label: '$label: $memoryId',
      button: true,
      child: ActionChip(
        label: Text(label),
        avatar: Icon(
          memoryType == 'story' ? Icons.mic : Icons.bookmark,
          size: 16,
        ),
        onPressed: () {
          // TODO: Navigate to story/memento detail when routes are implemented
          // For now, show a placeholder snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label detail view coming soon'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Format absolute timestamp: "Nov 3, 2025 at 4:12 PM" (locale aware)
  String _formatAbsoluteTimestamp(DateTime date) {
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(date)} at ${timeFormat.format(date)}';
  }

  /// Format relative timestamp: "3 weeks ago" or empty if very recent
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


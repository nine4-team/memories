import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/memory_type.dart';

/// Widget displaying memory metadata: timestamp, location, and related memories
/// 
/// Renders only rows that have data, ensuring seamless layout collapse when
/// metadata is missing.
class MemoryMetadataSection extends StatelessWidget {
  final MemoryDetail memory;
  final VoidCallback? onDateTap;

  const MemoryMetadataSection({
    super.key,
    required this.memory,
    this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = memory.locationData?.formattedLocation != null;
    final hasRelatedStories = memory.relatedStories.isNotEmpty;
    final hasRelatedMementos = memory.relatedMementos.isNotEmpty;
    final hasRelatedMemories = hasRelatedStories || hasRelatedMementos;

    // Always show timestamp row (memoryDate is required)
    // Only hide if no location and no related memories (but timestamp is always shown)

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
    // Use memoryDate instead of capturedAt (memoryDate is required)
    final absoluteTime = _formatAbsoluteTimestamp(memory.memoryDate);
    final relativeTime = _formatRelativeTimestamp(memory.memoryDate);
    final isEditable = onDateTap != null;

    return Semantics(
      label: 'Date: $absoluteTime, $relativeTime',
      button: isEditable,
      child: InkWell(
        onTap: isEditable ? onDateTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
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
                if (isEditable) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
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
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, ThemeData theme) {
    final locationText = memory.locationData!.formattedLocation!;

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
            ...memory.relatedStories.map((storyId) => _buildMemoryChip(
                  context,
                  theme,
                  label: 'Story',
                  memoryId: storyId,
                  memoryType: 'story',
                )),
            // Memento chips
            ...memory.relatedMementos.map((mementoId) => _buildMemoryChip(
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
          memoryType == 'story' 
              ? MemoryType.story.icon 
              : memoryType == 'memento'
                  ? MemoryType.memento.icon
                  : MemoryType.moment.icon,
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
    // Convert UTC to local time for display
    final localDate = date.toLocal();
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(localDate)} at ${timeFormat.format(localDate)}';
  }

  /// Format relative timestamp: "3 weeks ago" or empty if very recent
  String _formatRelativeTimestamp(DateTime date) {
    // Convert UTC to local time for comparison
    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

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


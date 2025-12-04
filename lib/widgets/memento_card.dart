import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:memories/services/timeline_image_cache_service.dart';
import 'package:memories/widgets/memory_title_with_processing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable card widget for displaying a Memento in the timeline
///
/// Shows primary thumbnail from first asset, Memento badge, generated title fallback,
/// and friendly timestamp identical to Stories. Uses the same card container styles
/// as MomentCard and StoryCard for visual consistency.
class MementoCard extends ConsumerWidget {
  final TimelineMemory memento;
  final VoidCallback onTap;
  final bool isOffline;

  const MementoCard({
    super.key,
    required this.memento,
    required this.onTap,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    // Determine offline states
    final isPreviewOnlyOffline =
        isOffline && memento.isPreviewOnly && !memento.isDetailCachedLocally;
    final isQueuedOffline = memento.isOfflineQueued;

    // Build semantic label with all relevant information
    // Format: "Memento titled [title] captured [absolute date]"
    final absoluteTime = _formatAbsoluteTimestamp(memento.capturedAt, locale);
    final semanticLabel = StringBuffer('Memento');
    if (memento.displayTitle.isNotEmpty &&
        memento.displayTitle != 'Untitled Memento') {
      semanticLabel.write(' titled ${memento.displayTitle}');
    }
    semanticLabel.write(' captured $absoluteTime');
    if (memento.primaryMedia != null) {
      semanticLabel
          .write(', ${memento.primaryMedia!.isPhoto ? 'photo' : 'video'}');
    }
    if (isQueuedOffline) {
      semanticLabel.write(', pending sync');
    }
    if (isPreviewOnlyOffline) {
      semanticLabel.write(', not available offline');
    }

    return Semantics(
      label: semanticLabel.toString(),
      button: true,
      hint: 'Double tap to view memento details',
      child: Opacity(
        opacity: isPreviewOnlyOffline ? 0.5 : 1.0,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          color: theme.colorScheme.surface,
          shape:
              _buildCardShape(context, isQueuedOffline, isPreviewOnlyOffline),
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
                        // Thumbnail section
                        _buildThumbnail(context, supabase, imageCache),
                        const SizedBox(width: 16),
                        // Content section
                        Expanded(
                          child: _buildContent(context, theme, locale),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Footer badges
                    _buildFooterBadges(
                        context, isQueuedOffline, isPreviewOnlyOffline),
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

  /// Get memory type icon for this memento
  IconData _getMemoryTypeIcon() {
    final memoryType = MemoryTypeExtension.fromApiValue(memento.memoryType);
    return memoryType.icon;
  }

  Widget _buildThumbnail(BuildContext context, SupabaseClient supabase,
      TimelineImageCacheService imageCache) {
    const thumbnailSize = 80.0;
    final memoryTypeIcon = _getMemoryTypeIcon();

    if (memento.primaryMedia == null) {
      // Text-only badge
      return Semantics(
        label: 'Text-only memento, no media',
        image: true,
        child: Container(
          width: thumbnailSize,
          height: thumbnailSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(memoryTypeIcon, size: 32),
          ),
        ),
      );
    }

    final media = memento.primaryMedia!;
    final bucket = media.isPhoto ? 'memories-photos' : 'memories-videos';

    // Get signed URL from cache or generate new one
    final signedUrl = imageCache.getSignedUrl(
      supabase,
      bucket,
      media.url,
    );

    return FutureBuilder<String>(
      future: signedUrl,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Hero tag for transition animation to detail view
          final heroTag = 'memento_thumbnail_${memento.id}';
          return Semantics(
            label: media.isPhoto ? 'Photo thumbnail' : 'Video thumbnail',
            image: true,
            child: Hero(
              tag: heroTag,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      snapshot.data!,
                      width: thumbnailSize,
                      height: thumbnailSize,
                      fit: BoxFit.cover,
                      // Optimize image caching: cache at 2x resolution for retina displays
                      cacheWidth: (thumbnailSize * 2).toInt(),
                      cacheHeight: (thumbnailSize * 2).toInt(),
                      errorBuilder: (context, error, stackTrace) {
                        return Semantics(
                          label: 'Failed to load thumbnail',
                          child: Container(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: const Icon(Icons.broken_image),
                          ),
                        );
                      },
                    ),
                  ),
                  // Memory type icon overlay in upper right corner
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        memoryTypeIcon,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Video duration pill
                  if (media.isVideo)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Semantics(
                        label: 'Video',
                        excludeSemantics: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Semantics(
            label: 'Error loading thumbnail',
            child: Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline),
            ),
          );
        } else {
          return Semantics(
            label: 'Loading thumbnail',
            excludeSemantics: true,
            child: Container(
              width: thumbnailSize,
              height: thumbnailSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with processing indicator
        MemoryTitleWithProcessing.timeline(
          memory: memento,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Date - shows actual date
        Semantics(
          label:
              'Captured ${_formatAbsoluteTimestamp(memento.capturedAt, locale)}',
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
                _formatAbsoluteTimestamp(memento.capturedAt, locale),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Location display
        if (memento.memoryLocationData?.formattedLocation != null)
          Semantics(
            label: 'Location: ${memento.memoryLocationData!.formattedLocation}',
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
                    memento.memoryLocationData!.formattedLocation!,
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

  /// Format absolute capture date: "Nov 3, 2025" (locale aware, date only)
  String _formatAbsoluteTimestamp(DateTime date, Locale locale) {
    final dateFormat = DateFormat('MMM d, y', locale.toString());
    return dateFormat.format(date);
  }
}

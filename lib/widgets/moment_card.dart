import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:memories/services/timeline_image_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable card widget for displaying a Moment in the timeline
class MomentCard extends ConsumerWidget {
  final TimelineMoment moment;
  final VoidCallback onTap;

  const MomentCard({
    super.key,
    required this.moment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    // Build semantic label with all relevant information
    final semanticLabel = StringBuffer('Moment');
    if (moment.displayTitle.isNotEmpty && moment.displayTitle != 'Untitled Moment') {
      semanticLabel.write(' titled ${moment.displayTitle}');
    }
    semanticLabel.write(' captured ${_formatDate(moment.capturedAt)}');
    if (moment.primaryMedia != null) {
      semanticLabel.write(', ${moment.primaryMedia!.isPhoto ? 'photo' : 'video'}');
    }
    if (moment.snippetText != null && moment.snippetText!.isNotEmpty) {
      semanticLabel.write('. ${moment.snippetText}');
    }
    if (moment.tags.isNotEmpty) {
      semanticLabel.write('. Tags: ${moment.tags.join(', ')}');
    }

    return Semantics(
      label: semanticLabel.toString(),
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          // Ensure minimum 44px hit area
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 44,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Thumbnail section
                _buildThumbnail(context, supabase, imageCache),
                  const SizedBox(width: 16),
                  // Content section
                  Expanded(
                    child: _buildContent(context, theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, SupabaseClient supabase, TimelineImageCacheService imageCache) {
    const thumbnailSize = 80.0;

    if (moment.primaryMedia == null) {
      // Text-only badge
      return Semantics(
        label: 'Text-only moment, no media',
        image: true,
        child: Container(
          width: thumbnailSize,
          height: thumbnailSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.text_fields, size: 32),
          ),
        ),
      );
    }

    final media = moment.primaryMedia!;
    final bucket = media.isPhoto ? 'photos' : 'videos';
    
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
          final heroTag = 'moment_thumbnail_${moment.id}';
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

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title - use textTheme to respect system text scaling
        Text(
          moment.displayTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Snippet - use textTheme to respect system text scaling
        if (moment.snippetText != null && moment.snippetText!.isNotEmpty)
          Text(
            moment.snippetText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        // Metadata row
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date
            Semantics(
              label: 'Captured ${_formatRelativeDate(moment.capturedAt)}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatRelativeDate(moment.capturedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Tags (max 3)
            if (moment.tags.isNotEmpty)
              ...moment.tags.take(3).map((tag) => Semantics(
                    label: 'Tag: $tag',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        label: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return _formatDate(date);
    }
  }
}


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:memories/providers/memory_processing_status_provider.dart';
import 'package:memories/services/timeline_image_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable card widget for displaying a Moment in the timeline
class MomentCard extends ConsumerWidget {
  final TimelineMemory moment;
  final VoidCallback onTap;
  final bool isOffline;

  const MomentCard({
    super.key,
    required this.moment,
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
        isOffline && moment.isPreviewOnly && !moment.isDetailCachedLocally;
    final isQueuedOffline = moment.isOfflineQueued;

    // Build semantic label with all relevant information
    final absoluteTime = _formatAbsoluteTimestamp(moment.capturedAt, locale);
    final semanticLabel = StringBuffer('Moment');
    if (moment.displayTitle.isNotEmpty && moment.displayTitle != 'Untitled Moment') {
      semanticLabel.write(' titled ${moment.displayTitle}');
    }
    semanticLabel.write(' captured $absoluteTime');
    if (moment.primaryMedia != null) {
      semanticLabel.write(', ${moment.primaryMedia!.isPhoto ? 'photo' : 'video'}');
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
            // Ensure minimum 44px hit area
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

    // Show processing indicator for server-backed memories that are still processing
    if (!isQueuedOffline && moment.serverId != null) {
      badges.add(_buildProcessingIndicator(context));
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

  Widget _buildProcessingIndicator(BuildContext context) {
    // Only show for server-backed memories
    if (moment.serverId == null) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(
          memoryProcessingStatusStreamProvider(moment.serverId!),
        );

        return statusAsync.when(
          data: (status) {
            // Only show if processing is in progress
            if (status == null || !status.isInProgress) {
              return const SizedBox.shrink();
            }

            // Show a subtle processing indicator
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Processing',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade800,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSyncStatusChip(BuildContext context) {
    final status = moment.offlineSyncStatus;
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
          child: Center(
            child: Icon(MemoryType.moment.icon, size: 32),
          ),
        ),
      );
    }

    final media = moment.primaryMedia!;
    
    // Branch on local vs remote media
    if (media.isLocal) {
      // Local file path - use Image.file or video placeholder
      final path = media.url.replaceFirst('file://', '');
      final file = File(path);
      
      if (!file.existsSync()) {
        // File missing - show broken image placeholder
        return Semantics(
          label: 'Missing media file',
          child: Container(
            width: thumbnailSize,
            height: thumbnailSize,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image),
          ),
        );
      }
      
      // Hero tag for transition animation to detail view
      final heroTag = 'moment_thumbnail_${moment.id}';
      
      if (media.isPhoto) {
        return Semantics(
          label: 'Photo thumbnail',
          image: true,
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: thumbnailSize,
                height: thumbnailSize,
                fit: BoxFit.cover,
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
          ),
        );
      } else {
        // Video - show generic video chip
        return Semantics(
          label: 'Video thumbnail',
          image: true,
          child: Hero(
            tag: heroTag,
            child: Stack(
              children: [
                Container(
                  width: thumbnailSize,
                  height: thumbnailSize,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, size: 32),
                ),
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
      }
    }
    
    // Remote Supabase media - use signed URL
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

  Widget _buildContent(BuildContext context, ThemeData theme, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 8),
        // Date - shows actual date
        Semantics(
          label: 'Captured ${_formatAbsoluteTimestamp(moment.capturedAt, locale)}',
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
                _formatAbsoluteTimestamp(moment.capturedAt, locale),
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
          label: 'Moment badge',
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
                  MemoryType.moment.icon,
                  size: 14,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Moment',
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


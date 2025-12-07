import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:memories/services/timeline_image_cache_service.dart';
import 'package:memories/widgets/memory_title_with_processing.dart';

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
    final supabaseUrl = ref.read(supabaseUrlProvider);
    final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final accessToken =
        ref.read(supabaseClientProvider).auth.currentSession?.accessToken;

    // Determine offline states
    // Phase 1: Text-cached synced memories have isDetailCachedLocally=true but not isOfflineQueued
    final isTextCachedOffline =
        isOffline && moment.isDetailCachedLocally && !moment.isOfflineQueued;
    final isPreviewOnlyOffline =
        isOffline && moment.isPreviewOnly && !moment.isDetailCachedLocally;
    final isQueuedOffline = moment.isOfflineQueued;

    // Build semantic label with all relevant information
    final absoluteTime = _formatAbsoluteTimestamp(moment.capturedAt, locale);
    final semanticLabel = StringBuffer('Moment');
    if (moment.displayTitle.isNotEmpty &&
        moment.displayTitle != 'Untitled Moment') {
      semanticLabel.write(' titled ${moment.displayTitle}');
    }
    semanticLabel.write(' captured $absoluteTime');
    if (moment.primaryMedia != null) {
      semanticLabel
          .write(', ${moment.primaryMedia!.isPhoto ? 'photo' : 'video'}');
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
          shape:
              _buildCardShape(context, isQueuedOffline, isPreviewOnlyOffline),
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
                        _buildThumbnail(context, supabaseUrl, supabaseAnonKey,
                            imageCache, accessToken, isOffline),
                        const SizedBox(width: 16),
                        // Content section
                        Expanded(
                          child: _buildContent(context, theme, locale),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Footer badges
                    _buildFooterBadges(context, isQueuedOffline,
                        isPreviewOnlyOffline, isTextCachedOffline),
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
    bool isTextCachedOffline,
  ) {
    final badges = <Widget>[];

    // Note: Processing and sync status indicators are now shown in the title area
    // via MemoryTitleWithProcessing widget. Footer badges are deprecated for these.

    // Phase 1: Show "Media not available offline" for text-cached synced memories
    if (isTextCachedOffline) {
      badges.add(_buildMediaNotAvailableChip(context));
    }

    // Show "Not available offline" for preview-only memories (shouldn't happen after Phase 1)
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

  Widget _buildMediaNotAvailableChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            'Media offline',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
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

  /// Get memory type icon for this moment
  IconData _getMemoryTypeIcon() {
    final memoryType = MemoryTypeExtension.fromApiValue(moment.memoryType);
    return memoryType.icon;
  }

  Widget _buildThumbnail(
      BuildContext context,
      String supabaseUrl,
      String supabaseAnonKey,
      TimelineImageCacheService imageCache,
      String? accessToken,
      bool isOffline) {
    const thumbnailSize = 80.0;
    final memoryTypeIcon = _getMemoryTypeIcon();

    if (moment.primaryMedia == null) {
      // Text-only badge
      return _buildMemoryTypeFallback(
        context,
        thumbnailSize,
        memoryTypeIcon,
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
            child: Stack(
              children: [
                ClipRRect(
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
              ],
            ),
          ),
        );
      } else {
        // Video - show poster if available, otherwise generic video chip
        final posterPath = media.posterUrl?.replaceFirst('file://', '');
        final posterFile = posterPath != null ? File(posterPath) : null;
        final hasLocalPoster = posterFile != null && posterFile.existsSync();
        
        return Semantics(
          label: 'Video thumbnail',
          image: true,
          child: Hero(
            tag: heroTag,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasLocalPoster
                      ? Image.file(
                          posterFile,
                          width: thumbnailSize,
                          height: thumbnailSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: thumbnailSize,
                              height: thumbnailSize,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.videocam, size: 32),
                            );
                          },
                        )
                      : Container(
                          width: thumbnailSize,
                          height: thumbnailSize,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.videocam, size: 32),
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
    // If offline, show memory type icon instead of trying to load
    if (isOffline) {
      return _buildMemoryTypeFallback(
        context,
        thumbnailSize,
        memoryTypeIcon,
      );
    }

    // For videos, prefer poster URL if available, otherwise use video URL
    final isVideo = media.isVideo;
    final bucket = media.isPhoto ? 'memories-photos' : 'memories-videos';
    final urlToLoad = isVideo && media.posterUrl != null ? media.posterUrl! : media.url;
    final bucketForUrl = isVideo && media.posterUrl != null ? 'memories-photos' : bucket;

    // Get signed URL from cache or generate new one
    final signedUrl = imageCache.getSignedUrl(
      supabaseUrl,
      supabaseAnonKey,
      bucketForUrl,
      urlToLoad,
      accessToken: accessToken,
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
                      // Match offline decoding: no cacheWidth/height hints
                      errorBuilder: (context, error, stackTrace) {
                        return _buildMemoryTypeFallback(
                          context,
                          thumbnailSize,
                          memoryTypeIcon,
                          semanticsLabel: 'Preview unavailable',
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
          developer.log(
            '[MomentCard] Thumbnail failed '
            'memoryId=${moment.id} path=${media.url}',
            name: 'MomentCard',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return _buildMemoryTypeFallback(
            context,
            thumbnailSize,
            memoryTypeIcon,
            semanticsLabel: 'Preview unavailable',
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

  Widget _buildMemoryTypeFallback(
    BuildContext context,
    double size,
    IconData memoryTypeIcon, {
    String semanticsLabel = 'Text-only moment, no media',
  }) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
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

  Widget _buildContent(BuildContext context, ThemeData theme, Locale locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with processing indicator
        MemoryTitleWithProcessing.timeline(
          memory: moment,
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
              'Captured ${_formatAbsoluteTimestamp(moment.capturedAt, locale)}',
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
        // Location display
        if (moment.memoryLocationData?.formattedLocation != null)
          Semantics(
            label: 'Location: ${moment.memoryLocationData!.formattedLocation}',
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
                    moment.memoryLocationData!.formattedLocation!,
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

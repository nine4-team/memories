import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:video_player/video_player.dart';

/// Unified media item for strip
class _MediaItem {
  final bool isPhoto;
  final PhotoMedia? photo;
  final VideoMedia? video;
  final int index;

  _MediaItem({
    required this.isPhoto,
    this.photo,
    this.video,
    required this.index,
  });
}

/// Media strip widget displaying photos and videos in a horizontally scrolling list
///
/// Similar to MediaTray but for detail view with remote URLs.
/// Supports thumbnail selection to show larger preview.
class MediaStrip extends ConsumerStatefulWidget {
  final String memoryId;
  final List<PhotoMedia> photos;
  final List<VideoMedia> videos;
  final ValueChanged<int>? onThumbnailSelected;
  final int? selectedIndex;
  final ValueChanged<({bool isPhoto, String url})>? onMediaRemoved;

  const MediaStrip({
    super.key,
    required this.memoryId,
    required this.photos,
    required this.videos,
    this.onThumbnailSelected,
    this.selectedIndex,
    this.onMediaRemoved,
  });

  @override
  ConsumerState<MediaStrip> createState() => _MediaStripState();
}

class _MediaStripState extends ConsumerState<MediaStrip> {
  List<_MediaItem> _buildMediaList() {
    final items = <_MediaItem>[];
    int index = 0;

    // Combine photos and videos, sorted by their index
    final allMedia =
        <({bool isPhoto, int index, PhotoMedia? photo, VideoMedia? video})>[];

    for (final photo in widget.photos) {
      allMedia
          .add((isPhoto: true, index: photo.index, photo: photo, video: null));
    }

    for (final video in widget.videos) {
      allMedia
          .add((isPhoto: false, index: video.index, photo: null, video: video));
    }

    // Sort by index to maintain capture order
    allMedia.sort((a, b) => a.index.compareTo(b.index));

    // Build _MediaItem list
    for (final media in allMedia) {
      items.add(_MediaItem(
        isPhoto: media.isPhoto,
        photo: media.photo,
        video: media.video,
        index: index++,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _buildMediaList();

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final item = mediaItems[index];
          final isSelected = widget.selectedIndex == index;

          return _MediaThumbnail(
            memoryId: widget.memoryId,
            item: item,
            isSelected: isSelected,
            onTap: () => widget.onThumbnailSelected?.call(index),
            onRemoved: widget.onMediaRemoved != null
                ? () {
                    final media = item.isPhoto
                        ? (isPhoto: true, url: item.photo!.url)
                        : (isPhoto: false, url: item.video!.url);
                    widget.onMediaRemoved!(media);
                  }
                : null,
          );
        },
      ),
    );
  }
}

/// Media thumbnail for the strip
class _MediaThumbnail extends ConsumerStatefulWidget {
  final String memoryId;
  final _MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onRemoved;

  const _MediaThumbnail({
    required this.memoryId,
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.onRemoved,
  });

  @override
  ConsumerState<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends ConsumerState<_MediaThumbnail> {
  VideoPlayerController? _videoController;
  Future<String>? _videoPosterUrlFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.item.isPhoto) {
      _initializeVideo();
      _initializeVideoPosterUrl();
    }
  }

  @override
  void didUpdateWidget(_MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video changed, reset the cached Future
    if (!widget.item.isPhoto && !oldWidget.item.isPhoto) {
      final oldPosterUrl = oldWidget.item.video?.posterUrl;
      final newPosterUrl = widget.item.video?.posterUrl;
      if (oldPosterUrl != newPosterUrl) {
        _videoPosterUrlFuture = null;
        _initializeVideoPosterUrl();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final video = widget.item.video!;

    // Skip initialization for local videos (no poster URL available)
    if (video.isLocal) {
      return;
    }

    final supabaseUrl = ref.read(supabaseUrlProvider);
    final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final accessToken =
        ref.read(supabaseClientProvider).auth.currentSession?.accessToken;

    try {
      final posterUrl = video.posterUrl;
      if (posterUrl != null) {
        // Just load the poster for thumbnail - don't initialize video player
        await imageCache.getSignedUrlForDetailView(
          supabaseUrl,
          supabaseAnonKey,
          'memories-photos',
          posterUrl,
          accessToken: accessToken,
        );
      }
    } catch (e, stackTrace) {
      _logSignedUrlFailure(
        kind: 'video_poster_preload',
        path: video.posterUrl ?? video.url,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _initializeVideoPosterUrl() {
    final video = widget.item.video!;

    // Skip for local videos (no poster URL available)
    if (video.isLocal || video.posterUrl == null) {
      return;
    }

    // Cache the Future to avoid recreating it on every build
    if (_videoPosterUrlFuture == null) {
      final supabaseUrl = ref.read(supabaseUrlProvider);
      final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
      final imageCache = ref.read(timelineImageCacheServiceProvider);
      final accessToken =
          ref.read(supabaseClientProvider).auth.currentSession?.accessToken;

      _videoPosterUrlFuture = imageCache.getSignedUrlForDetailView(
        supabaseUrl,
        supabaseAnonKey,
        'memories-photos',
        video.posterUrl!,
        accessToken: accessToken,
      );
    }
  }

  void _logSignedUrlFailure({
    required String kind,
    required String path,
    required Object error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[MediaStrip] Failed to load $kind '
      'memoryId=${widget.memoryId} path=$path',
      name: 'MediaStrip',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final overlayBackgroundColor = theme.colorScheme.surface.withOpacity(0.8);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest,
          border: widget.isSelected
              ? Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.item.isPhoto
                  ? _buildPhotoThumbnail()
                  : _buildVideoThumbnail(),
            ),
            // Remove button (only show if onRemoved callback is provided)
            if (widget.onRemoved != null)
              Positioned(
                top: 2,
                right: 2,
                child: Semantics(
                  label: 'Remove ${widget.item.isPhoto ? 'photo' : 'video'}',
                  button: true,
                  child: GestureDetector(
                    onTap: widget.onRemoved,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: overlayBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: overlayColor,
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

  Widget _buildPhotoThumbnail() {
    final photo = widget.item.photo!;

    // Branch on local vs remote media
    if (photo.isLocal) {
      // Local file path - use Image.file
      final path = photo.url.replaceFirst('file://', '');
      final file = File(path);

      if (!file.existsSync()) {
        // File missing - show broken image placeholder
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image, size: 32),
          ),
        );
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.broken_image, size: 32),
            ),
          );
        },
      );
    }

    // Remote Supabase media - use signed URL
    final supabaseUrl = ref.read(supabaseUrlProvider);
    final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final accessToken =
        ref.read(supabaseClientProvider).auth.currentSession?.accessToken;

    return FutureBuilder<String>(
      future: imageCache.getSignedUrlForDetailView(
        supabaseUrl,
        supabaseAnonKey,
        'memories-photos',
        photo.url,
        accessToken: accessToken,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logSignedUrlFailure(
            kind: 'photo_thumbnail',
            path: photo.url,
            error: snapshot.error ?? Exception('Unknown photo thumbnail error'),
            stackTrace: snapshot.stackTrace,
          );
          return Container(
            width: 100,
            height: 100,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.broken_image, size: 32),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            width: 100,
            height: 100,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return Image.network(
          snapshot.data!,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.broken_image, size: 32),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoThumbnail() {
    final video = widget.item.video!;
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final overlayBackgroundColor = theme.colorScheme.surface.withOpacity(0.8);

    // Branch on local vs remote media
    if (video.isLocal) {
      // Local video - show placeholder (no poster available for local videos)
      return Stack(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.videocam, size: 32),
            ),
          ),
          // Video badge
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: overlayBackgroundColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 16,
                color: overlayColor,
              ),
            ),
          ),
        ],
      );
    }

    // Remote Supabase media - use signed URL for poster
    // The Future is cached in _videoPosterUrlFuture to avoid recreating it on every build

    return Stack(
      children: [
        // Video poster or placeholder
        if (video.posterUrl != null && _videoPosterUrlFuture != null)
          FutureBuilder<String>(
            future: _videoPosterUrlFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _logSignedUrlFailure(
                  kind: 'video_poster',
                  path: video.posterUrl!,
                  error: snapshot.error ??
                      Exception('Unknown video poster thumbnail error'),
                  stackTrace: snapshot.stackTrace,
                );
                return Container(
                  width: 100,
                  height: 100,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.videocam, size: 32),
                  ),
                );
              }

              if (snapshot.hasData) {
                return Image.network(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.videocam, size: 32),
                      ),
                    );
                  },
                );
              }
              return Container(
                width: 100,
                height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          )
        else
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.videocam, size: 32),
            ),
          ),
        // Video badge
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: overlayBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.play_circle_outline,
              size: 16,
              color: overlayColor,
            ),
          ),
        ),
      ],
    );
  }
}

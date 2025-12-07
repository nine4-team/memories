import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';

/// Widget for displaying and managing media attachments
///
/// Shows thumbnails for photos and videos with remove controls.
/// Handles both existing media URLs (from Supabase Storage) and new media paths (local files).
class MediaTray extends ConsumerWidget {
  /// List of photo file paths (new media)
  final List<String> photoPaths;

  /// List of video file paths (new media)
  final List<String> videoPaths;

  /// List of generated video poster file paths aligned with [videoPaths]
  final List<String?> videoPosterPaths;

  /// List of existing photo URLs (from Supabase Storage)
  final List<String> existingPhotoUrls;

  /// List of existing video URLs (from Supabase Storage)
  final List<String> existingVideoUrls;

  /// List of existing video poster URLs aligned with [existingVideoUrls]
  final List<String?> existingVideoPosterUrls;

  /// Callback when a photo should be removed (new media)
  final ValueChanged<int> onPhotoRemoved;

  /// Callback when a video should be removed (new media)
  final ValueChanged<int> onVideoRemoved;

  /// Callback when an existing photo should be removed
  final ValueChanged<int>? onExistingPhotoRemoved;

  /// Callback when an existing video should be removed
  final ValueChanged<int>? onExistingVideoRemoved;

  /// Whether photo limit has been reached
  final bool canAddPhoto;

  /// Whether video limit has been reached
  final bool canAddVideo;

  const MediaTray({
    super.key,
    required this.photoPaths,
    required this.videoPaths,
    this.videoPosterPaths = const [],
    required this.onPhotoRemoved,
    required this.onVideoRemoved,
    this.existingPhotoUrls = const [],
    this.existingVideoUrls = const [],
    this.existingVideoPosterUrls = const [],
    this.onExistingPhotoRemoved,
    this.onExistingVideoRemoved,
    required this.canAddPhoto,
    required this.canAddVideo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPhotos = existingPhotoUrls.length + photoPaths.length;
    final totalVideos = existingVideoUrls.length + videoPaths.length;
    final hasMedia = totalPhotos > 0 || totalVideos > 0;

    if (!hasMedia) {
      return const SizedBox.shrink();
    }

    // Combine existing photos, new photos, existing videos, and new videos
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: totalPhotos + totalVideos,
        itemBuilder: (context, index) {
          // Existing photos come first
          if (index < existingPhotoUrls.length) {
            return _MediaThumbnail(
              url: existingPhotoUrls[index],
              isVideo: false,
              isExisting: true,
              onRemoved: onExistingPhotoRemoved != null
                  ? () => onExistingPhotoRemoved!(index)
                  : null,
            );
          }
          // New photos come next
          else if (index < existingPhotoUrls.length + photoPaths.length) {
            final photoIndex = index - existingPhotoUrls.length;
            return _MediaThumbnail(
              filePath: photoPaths[photoIndex],
              isVideo: false,
              isExisting: false,
              onRemoved: () => onPhotoRemoved(photoIndex),
            );
          }
          // Existing videos come next
          else if (index <
              existingPhotoUrls.length +
                  photoPaths.length +
                  existingVideoUrls.length) {
            final existingVideoIndex =
                index - existingPhotoUrls.length - photoPaths.length;
            return _MediaThumbnail(
              url: existingVideoUrls[existingVideoIndex],
              isVideo: true,
              isExisting: true,
              posterUrl: existingVideoPosterUrls.length > existingVideoIndex
                  ? existingVideoPosterUrls[existingVideoIndex]
                  : null,
              onRemoved: onExistingVideoRemoved != null
                  ? () => onExistingVideoRemoved!(existingVideoIndex)
                  : null,
            );
          }
          // New videos come last
          else {
            final videoIndex = index -
                existingPhotoUrls.length -
                photoPaths.length -
                existingVideoUrls.length;
            return _MediaThumbnail(
              filePath: videoPaths[videoIndex],
              isVideo: true,
              isExisting: false,
              posterFilePath: videoPosterPaths.length > videoIndex
                  ? videoPosterPaths[videoIndex]
                  : null,
              onRemoved: () => onVideoRemoved(videoIndex),
            );
          }
        },
      ),
    );
  }
}

class _MediaThumbnail extends ConsumerStatefulWidget {
  final String? filePath; // Local file path (for new media)
  final String? url; // Storage path from Supabase Storage (for existing media)
  final bool isVideo;
  final bool
      isExisting; // Whether this is existing media (URL) or new media (file path)
  final VoidCallback? onRemoved;
  final String? posterFilePath;
  final String? posterUrl;

  const _MediaThumbnail({
    this.filePath,
    this.url,
    required this.isVideo,
    required this.isExisting,
    this.onRemoved,
    this.posterFilePath,
    this.posterUrl,
  }) : assert(
          (filePath != null && url == null) ||
              (filePath == null && url != null),
          'Either filePath or url must be provided, but not both',
        );

  @override
  ConsumerState<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends ConsumerState<_MediaThumbnail> {
  VideoPlayerController? _videoController;
  Future<String>? _posterUrlFuture;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
      _initializePosterFuture();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVideo &&
        widget.isExisting &&
        oldWidget.posterUrl != widget.posterUrl) {
      _posterUrlFuture = null;
      _initializePosterFuture();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // For thumbnails, we don't load video players - just show placeholders
      // This avoids distortion and performance issues
      if (widget.isExisting) {
        // Existing videos (online) - show placeholder, don't load video
        return;
      } else if (!widget.isExisting && widget.filePath != null) {
        // New video from file path - can show video player for local preview
        _videoController = VideoPlayerController.file(File(widget.filePath!));
        await _videoController!.initialize();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Handle error - show placeholder
    }
  }

  void _initializePosterFuture() {
    if (!widget.isVideo || !widget.isExisting) {
      return;
    }
    if (widget.posterUrl == null) {
      _posterUrlFuture = null;
      return;
    }
    if (_posterUrlFuture != null) {
      return;
    }
    final supabaseUrl = ref.read(supabaseUrlProvider);
    final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final accessToken =
        ref.read(supabaseClientProvider).auth.currentSession?.accessToken;

    _posterUrlFuture = imageCache.getSignedUrlForDetailView(
      supabaseUrl,
      supabaseAnonKey,
      'memories-photos',
      widget.posterUrl!,
      accessToken: accessToken,
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final overlayBackgroundColor = theme.colorScheme.surface.withOpacity(0.8);

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        children: [
          // Media preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.isVideo ? _buildVideoPreview() : _buildPhotoPreview(),
          ),
          // Remove button (only show if onRemoved callback is provided)
          if (widget.onRemoved != null)
            Positioned(
              top: 2,
              right: 2,
              child: Semantics(
                label: 'Remove ${widget.isVideo ? 'video' : 'photo'}',
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
          // Video badge
          if (widget.isVideo)
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
      ),
    );
  }

  Widget _buildPhotoPreview() {
    try {
      if (widget.isExisting && widget.url != null) {
        // Existing photo from storage path - need to get signed URL
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
            widget.url!,
            accessToken: accessToken,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return Container(
                width: 100,
                height: 100,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.broken_image),
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
                  width: 100,
                  height: 100,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image),
                  ),
                );
              },
            );
          },
        );
      } else if (!widget.isExisting && widget.filePath != null) {
        // New photo from file path
        return Image.file(
          File(widget.filePath!),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image),
            );
          },
        );
      } else {
        return Container(
          width: 100,
          height: 100,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image),
          ),
        );
      }
    } catch (e) {
      return Container(
        width: 100,
        height: 100,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.broken_image),
        ),
      );
    }
  }

  Widget _buildVideoPreview() {
    final theme = Theme.of(context);

    // For existing videos (online), show poster if available
    if (widget.isExisting) {
      if (_posterUrlFuture != null) {
        return FutureBuilder<String>(
          future: _posterUrlFuture!,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.videocam, size: 32),
                    ),
                  );
                },
              );
            }
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      }
      // No poster URL available, show placeholder
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.videocam, size: 32),
        ),
      );
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return SizedBox(
      width: 100,
      height: 100,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }
}

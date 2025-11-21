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

  /// List of existing photo URLs (from Supabase Storage)
  final List<String> existingPhotoUrls;

  /// List of existing video URLs (from Supabase Storage)
  final List<String> existingVideoUrls;

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
    required this.onPhotoRemoved,
    required this.onVideoRemoved,
    this.existingPhotoUrls = const [],
    this.existingVideoUrls = const [],
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
          else if (index < existingPhotoUrls.length + photoPaths.length + existingVideoUrls.length) {
            final existingVideoIndex = index - existingPhotoUrls.length - photoPaths.length;
            return _MediaThumbnail(
              url: existingVideoUrls[existingVideoIndex],
              isVideo: true,
              isExisting: true,
              onRemoved: onExistingVideoRemoved != null
                  ? () => onExistingVideoRemoved!(existingVideoIndex)
                  : null,
            );
          }
          // New videos come last
          else {
            final videoIndex = index - existingPhotoUrls.length - photoPaths.length - existingVideoUrls.length;
            return _MediaThumbnail(
              filePath: videoPaths[videoIndex],
              isVideo: true,
              isExisting: false,
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
  final bool isExisting; // Whether this is existing media (URL) or new media (file path)
  final VoidCallback? onRemoved;

  const _MediaThumbnail({
    this.filePath,
    this.url,
    required this.isVideo,
    required this.isExisting,
    this.onRemoved,
  }) : assert(
          (filePath != null && url == null) || (filePath == null && url != null),
          'Either filePath or url must be provided, but not both',
        );

  @override
  ConsumerState<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends ConsumerState<_MediaThumbnail> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.isExisting && widget.url != null) {
        // Existing video from storage path - need to get signed URL
        final supabase = ref.read(supabaseClientProvider);
        final imageCache = ref.read(timelineImageCacheServiceProvider);
        final signedUrl = await imageCache.getSignedUrlForDetailView(
          supabase,
          'memories-videos', // Videos are stored in memories-videos bucket
          widget.url!,
        );
        _videoController = VideoPlayerController.networkUrl(Uri.parse(signedUrl));
      } else if (!widget.isExisting && widget.filePath != null) {
        // New video from file path
        _videoController = VideoPlayerController.file(File(widget.filePath!));
      } else {
        return;
      }
      await _videoController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle error - show placeholder
    }
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
              top: 4,
              right: 4,
              child: Semantics(
                label: 'Remove ${widget.isVideo ? 'video' : 'photo'}',
                button: true,
                child: Material(
                  color: overlayBackgroundColor,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: Icon(Icons.close, size: 18, color: overlayColor),
                    onPressed: widget.onRemoved,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
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
        final supabase = ref.read(supabaseClientProvider);
        final imageCache = ref.read(timelineImageCacheServiceProvider);
        
        return FutureBuilder<String>(
          future: imageCache.getSignedUrlForDetailView(
            supabase,
            'memories-photos',
            widget.url!,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Icon(Icons.broken_image),
              );
            }
            
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image),
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
        return const Center(
          child: Icon(Icons.broken_image),
        );
      }
    } catch (e) {
      return const Center(
        child: Icon(Icons.broken_image),
      );
    }
  }

  Widget _buildVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }
}

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
  final List<PhotoMedia> photos;
  final List<VideoMedia> videos;
  final ValueChanged<int>? onThumbnailSelected;
  final int? selectedIndex;

  const MediaStrip({
    super.key,
    required this.photos,
    required this.videos,
    this.onThumbnailSelected,
    this.selectedIndex,
  });

  @override
  ConsumerState<MediaStrip> createState() => _MediaStripState();
}

class _MediaStripState extends ConsumerState<MediaStrip> {
  List<_MediaItem> _buildMediaList() {
    final items = <_MediaItem>[];
    int index = 0;

    // Combine photos and videos, sorted by their index
    final allMedia = <({bool isPhoto, int index, PhotoMedia? photo, VideoMedia? video})>[];

    for (final photo in widget.photos) {
      allMedia.add((isPhoto: true, index: photo.index, photo: photo, video: null));
    }

    for (final video in widget.videos) {
      allMedia.add((isPhoto: false, index: video.index, photo: null, video: video));
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
            item: item,
            isSelected: isSelected,
            onTap: () => widget.onThumbnailSelected?.call(index),
          );
        },
      ),
    );
  }
}

/// Media thumbnail for the strip
class _MediaThumbnail extends ConsumerStatefulWidget {
  final _MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _MediaThumbnail({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  ConsumerState<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends ConsumerState<_MediaThumbnail> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (!widget.item.isPhoto) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    try {
      final posterUrl = widget.item.video!.posterUrl;
      if (posterUrl != null) {
        // Just load the poster for thumbnail - don't initialize video player
        await imageCache.getSignedUrlForDetailView(
          supabase,
          'memories-photos',
          posterUrl,
        );
      }
    } catch (e) {
      // Handle error - show placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.item.isPhoto
              ? _buildPhotoThumbnail()
              : _buildVideoThumbnail(),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail() {
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    return FutureBuilder<String>(
      future: imageCache.getSignedUrlForDetailView(
        supabase,
        'memories-photos',
        widget.item.photo!.url,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.broken_image, size: 32),
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
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final overlayBackgroundColor = theme.colorScheme.surface.withOpacity(0.8);

    return Stack(
      children: [
        // Video poster or placeholder
        if (widget.item.video!.posterUrl != null)
          FutureBuilder<String>(
            future: imageCache.getSignedUrlForDetailView(
              supabase,
              'memories-photos',
              widget.item.video!.posterUrl!,
            ),
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


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:video_player/video_player.dart';

/// Unified media item for preview
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

/// Large media preview widget showing selected photo or video
class MediaPreview extends ConsumerStatefulWidget {
  final List<PhotoMedia> photos;
  final List<VideoMedia> videos;
  final int? selectedIndex;

  const MediaPreview({
    super.key,
    required this.photos,
    required this.videos,
    this.selectedIndex,
  });

  @override
  ConsumerState<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends ConsumerState<MediaPreview> {
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

  void _openLightbox(BuildContext context, List<_MediaItem> mediaItems, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaLightbox(
          mediaItems: mediaItems,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _buildMediaList();

    if (widget.selectedIndex == null || widget.selectedIndex! < 0 || widget.selectedIndex! >= mediaItems.length) {
      return const SizedBox.shrink();
    }

    final selectedItem = mediaItems[widget.selectedIndex!];

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => _openLightbox(context, mediaItems, widget.selectedIndex!),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: selectedItem.isPhoto
              ? _PhotoPreview(photo: selectedItem.photo!)
              : _VideoPreview(video: selectedItem.video!),
        ),
      ),
    );
  }
}

/// Photo preview
class _PhotoPreview extends ConsumerWidget {
  final PhotoMedia photo;

  const _PhotoPreview({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Branch on local vs remote media
    if (photo.isLocal) {
      final path = photo.url.replaceFirst('file://', '');
      final file = File(path);
      
      if (!file.existsSync()) {
        return Container(
          color: Colors.white,
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        );
      }
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white,
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 64,
                ),
              ),
            );
          },
        ),
      );
    }
    
    // Remote Supabase media
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    return FutureBuilder<String>(
      future: imageCache.getSignedUrlForDetailView(
        supabase,
        'memories-photos',
        photo.url,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 64,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.white,
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 64,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Video preview
class _VideoPreview extends ConsumerStatefulWidget {
  final VideoMedia video;

  const _VideoPreview({required this.video});

  @override
  ConsumerState<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    // Branch on local vs remote media
    if (widget.video.isLocal) {
      final path = widget.video.url.replaceFirst('file://', '');
      final file = File(path);
      
      if (!file.existsSync()) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
        return;
      }
      
      try {
        _controller = VideoPlayerController.file(file);
        await _controller!.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
      }
      return;
    }
    
    // Remote Supabase media
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    try {
      final videoUrl = await imageCache.getSignedUrlForDetailView(
        supabase,
        'memories-videos',
        widget.video.url,
      );

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video player or poster
        if (_isInitialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (!widget.video.isLocal && widget.video.posterUrl != null)
          FutureBuilder<String?>(
            future: () {
              final supabase = ref.read(supabaseClientProvider);
              final imageCache = ref.read(timelineImageCacheServiceProvider);
              return imageCache.getSignedUrlForDetailView(
                supabase,
                'memories-photos',
                widget.video.posterUrl!,
              );
            }(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
          )
        else
          const Center(
            child: Icon(
              Icons.videocam,
              color: Colors.grey,
              size: 64,
            ),
          ),
        // Play/pause overlay
        if (_isInitialized && _controller != null)
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        // Video duration indicator
        if (widget.video.duration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(widget.video.duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Full-screen lightbox for viewing media with pinch/zoom/pan support
class _MediaLightbox extends ConsumerStatefulWidget {
  final List<_MediaItem> mediaItems;
  final int initialIndex;

  const _MediaLightbox({
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  ConsumerState<_MediaLightbox> createState() => _MediaLightboxState();
}

class _MediaLightboxState extends ConsumerState<_MediaLightbox> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView for swiping through media
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.mediaItems.length,
            itemBuilder: (context, index) {
              final item = widget.mediaItems[index];
              return item.isPhoto
                  ? _LightboxPhotoSlide(photo: item.photo!)
                  : _LightboxVideoSlide(video: item.video!);
            },
          ),
          // Close button and page indicator
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator
                  if (widget.mediaItems.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.mediaItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
          ),
          // Bottom indicator dots
          if (widget.mediaItems.length > 1)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.mediaItems.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lightbox photo slide with pinch/zoom/pan support
class _LightboxPhotoSlide extends ConsumerStatefulWidget {
  final PhotoMedia photo;

  const _LightboxPhotoSlide({required this.photo});

  @override
  ConsumerState<_LightboxPhotoSlide> createState() => _LightboxPhotoSlideState();
}

class _LightboxPhotoSlideState extends ConsumerState<_LightboxPhotoSlide> {
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      setState(() {
        _isZoomed = false;
      });
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.0);
      setState(() {
        _isZoomed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 3.0,
        child: Center(
          child: () {
            // Branch on local vs remote media
            if (widget.photo.isLocal) {
              final path = widget.photo.url.replaceFirst('file://', '');
              final file = File(path);
              
              if (!file.existsSync()) {
                return const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                );
              }
              
              return Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  );
                },
              );
            }
            
            // Remote Supabase media
            final supabase = ref.read(supabaseClientProvider);
            final imageCache = ref.read(timelineImageCacheServiceProvider);
            
            return FutureBuilder<String>(
              future: imageCache.getSignedUrlForDetailView(
                supabase,
                'memories-photos',
                widget.photo.url,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator(
                    color: Colors.white,
                  );
                }

                return Image.network(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 64,
                      ),
                    );
                  },
                );
              },
            );
          }(),
        ),
      ),
    );
  }
}

/// Lightbox video slide
class _LightboxVideoSlide extends ConsumerStatefulWidget {
  final VideoMedia video;

  const _LightboxVideoSlide({required this.video});

  @override
  ConsumerState<_LightboxVideoSlide> createState() => _LightboxVideoSlideState();
}

class _LightboxVideoSlideState extends ConsumerState<_LightboxVideoSlide> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    // Branch on local vs remote media
    if (widget.video.isLocal) {
      final path = widget.video.url.replaceFirst('file://', '');
      final file = File(path);
      
      if (!file.existsSync()) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
        return;
      }
      
      try {
        _controller = VideoPlayerController.file(file);
        await _controller!.initialize();
        
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
      }
      return;
    }
    
    // Remote Supabase media
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    try {
      final videoUrl = await imageCache.getSignedUrlForDetailView(
        supabase,
        'memories-videos',
        widget.video.url,
      );

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video player or poster
        if (_isInitialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (!widget.video.isLocal && widget.video.posterUrl != null)
          FutureBuilder<String?>(
            future: () {
              final supabase = ref.read(supabaseClientProvider);
              final imageCache = ref.read(timelineImageCacheServiceProvider);
              return imageCache.getSignedUrlForDetailView(
                supabase,
                'memories-photos',
                widget.video.posterUrl!,
              );
            }(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Center(
                  child: Image.network(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
          )
        else
          const Center(
            child: Icon(
              Icons.videocam,
              color: Colors.white,
              size: 64,
            ),
          ),
        // Play/pause overlay
        if (_isInitialized && _controller != null)
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        // Video duration indicator
        if (widget.video.duration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(widget.video.duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}


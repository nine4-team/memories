import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:video_player/video_player.dart';

/// Unified media item for carousel
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

/// Media carousel widget displaying photos and videos in a swipeable PageView
///
/// Supports:
/// - Swipeable carousel with mixed photo/video slides
/// - Pinch-to-zoom and double-tap zoom for photos
/// - Inline video playback with manual controls
/// - Full-screen lightbox overlay
/// - Retry handling for failed media loads
class MediaCarousel extends ConsumerStatefulWidget {
  final List<PhotoMedia> photos;
  final List<VideoMedia> videos;
  final String? heroTag; // Optional hero tag for first photo transition

  const MediaCarousel({
    super.key,
    required this.photos,
    required this.videos,
    this.heroTag,
  });

  @override
  ConsumerState<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends ConsumerState<MediaCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showLightbox = false;
  int _lightboxIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  void _openLightbox(int index) {
    setState(() {
      _lightboxIndex = index;
      _showLightbox = true;
    });
  }

  void _closeLightbox() {
    setState(() {
      _showLightbox = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _buildMediaList();

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label:
          'Media carousel, ${mediaItems.length} ${mediaItems.length == 1 ? 'item' : 'items'}',
      hint: 'Swipe left or right to navigate, tap to open full screen',
      child: Stack(
        children: [
          // Main carousel
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: mediaItems.length,
              itemBuilder: (context, index) {
                final item = mediaItems[index];
                return _MediaSlide(
                  item: item,
                  heroTag: index == 0 ? widget.heroTag : null,
                  onTap: () => _openLightbox(index),
                );
              },
            ),
          ),
          // Page indicators
          if (mediaItems.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Semantics(
                label: 'Page ${_currentPage + 1} of ${mediaItems.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    mediaItems.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Lightbox overlay
          if (_showLightbox)
            _LightboxOverlay(
              mediaItems: mediaItems,
              initialIndex: _lightboxIndex,
              onClose: _closeLightbox,
            ),
        ],
      ),
    );
  }
}

/// Individual media slide (photo or video)
class _MediaSlide extends ConsumerStatefulWidget {
  final _MediaItem item;
  final String? heroTag;
  final VoidCallback onTap;

  const _MediaSlide({
    required this.item,
    this.heroTag,
    required this.onTap,
  });

  @override
  ConsumerState<_MediaSlide> createState() => _MediaSlideState();
}

class _MediaSlideState extends ConsumerState<_MediaSlide> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    if (widget.item.isPhoto) {
      return _PhotoSlide(
        photo: widget.item.photo!,
        heroTag: widget.heroTag,
        onTap: widget.onTap,
        onError: (error) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        },
        onRetry: () {
          setState(() {
            _hasError = false;
            _errorMessage = null;
          });
        },
        hasError: _hasError,
        errorMessage: _errorMessage,
      );
    } else {
      return _VideoSlide(
        video: widget.item.video!,
        onTap: widget.onTap,
        onError: (error) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        },
        onRetry: () {
          setState(() {
            _hasError = false;
            _errorMessage = null;
          });
        },
        hasError: _hasError,
        errorMessage: _errorMessage,
      );
    }
  }
}

/// Photo slide with zoom support
class _PhotoSlide extends ConsumerStatefulWidget {
  final PhotoMedia photo;
  final String? heroTag;
  final VoidCallback onTap;
  final ValueChanged<String> onError;
  final VoidCallback onRetry;
  final bool hasError;
  final String? errorMessage;

  const _PhotoSlide({
    required this.photo,
    this.heroTag,
    required this.onTap,
    required this.onError,
    required this.onRetry,
    required this.hasError,
    this.errorMessage,
  });

  @override
  ConsumerState<_PhotoSlide> createState() => _PhotoSlideState();
}

class _PhotoSlideState extends ConsumerState<_PhotoSlide> {
  final TransformationController _transformationController =
      TransformationController();
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
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: Container(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 3.0,
            child: FutureBuilder<String>(
              future: imageCache.getSignedUrlForDetailView(
                supabase,
                'memories-photos',
                widget.photo.url,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError || widget.hasError) {
                  final errorDetails = snapshot.hasError
                      ? 'Error: ${snapshot.error}, Photo URL: ${widget.photo.url}'
                      : widget.errorMessage ?? 'Failed to load image';

                  debugPrint(
                      '[MediaCarousel] ✗ Photo slide error: $errorDetails');
                  if (snapshot.hasError) {
                    debugPrint(
                        '[MediaCarousel]   Error object: ${snapshot.error}');
                  }
                  developer.log(
                    'Photo slide error: $errorDetails',
                    name: 'MediaCarousel',
                    error: snapshot.error,
                  );

                  return _ErrorPlaceholder(
                    message: widget.errorMessage ?? 'Failed to load image',
                    onRetry: widget.onRetry,
                    onError: widget.onError,
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                }

                final signedUrl = snapshot.data!;
                debugPrint('[MediaCarousel] Loading image from signed URL');
                debugPrint('[MediaCarousel]   Photo URL: ${widget.photo.url}');
                debugPrint(
                    '[MediaCarousel]   Signed URL: ${signedUrl.substring(0, 80)}...');
                developer.log(
                  'Loading image from signed URL for photo: ${widget.photo.url}',
                  name: 'MediaCarousel',
                );

                final imageWidget = Image.network(
                  signedUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('[MediaCarousel] ✗ Image.network error');
                    debugPrint(
                        '[MediaCarousel]   Photo URL: ${widget.photo.url}');
                    debugPrint('[MediaCarousel]   Signed URL: $signedUrl');
                    debugPrint('[MediaCarousel]   Error: $error');
                    developer.log(
                      'Image.network error for photo URL: ${widget.photo.url}, signed URL: $signedUrl, error: $error',
                      name: 'MediaCarousel',
                      error: error,
                      stackTrace: stackTrace,
                    );

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onError('Failed to load image: $error');
                    });
                    return _ErrorPlaceholder(
                      message: 'Failed to load image',
                      onRetry: widget.onRetry,
                      onError: widget.onError,
                    );
                  },
                );

                if (widget.heroTag != null) {
                  return Hero(
                    tag: widget.heroTag!,
                    child: imageWidget,
                  );
                }

                return imageWidget;
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Video slide with inline playback
class _VideoSlide extends ConsumerStatefulWidget {
  final VideoMedia video;
  final VoidCallback onTap;
  final ValueChanged<String> onError;
  final VoidCallback onRetry;
  final bool hasError;
  final String? errorMessage;

  const _VideoSlide({
    required this.video,
    required this.onTap,
    required this.onError,
    required this.onRetry,
    required this.hasError,
    this.errorMessage,
  });

  @override
  ConsumerState<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends ConsumerState<_VideoSlide> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

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
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    try {
      // Get signed URL for video
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
          _hasError = false;
        });

        // Listen for errors
        _controller!.addListener(() {
          if (_controller!.value.hasError && mounted) {
            setState(() {
              _hasError = true;
            });
            widget.onError(
                'Video playback error: ${_controller!.value.errorDescription}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        widget.onError('Failed to initialize video: $e');
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
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    if (widget.hasError || _hasError) {
      return Container(
        color: Colors.black,
        child: _ErrorPlaceholder(
          message: widget.errorMessage ?? 'Failed to load video',
          onRetry: () {
            widget.onRetry();
            _initializeVideo();
          },
          onError: widget.onError,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video player or poster
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              FutureBuilder<String?>(
                future: widget.video.posterUrl != null
                    ? imageCache.getSignedUrlForDetailView(
                        supabase,
                        'memories-photos',
                        widget.video.posterUrl!,
                      )
                    : Future.value(null),
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
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Error placeholder with retry button
class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ValueChanged<String> onError;

  const _ErrorPlaceholder({
    required this.message,
    required this.onRetry,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen lightbox overlay
class _LightboxOverlay extends StatefulWidget {
  final List<_MediaItem> mediaItems;
  final int initialIndex;
  final VoidCallback onClose;

  const _LightboxOverlay({
    required this.mediaItems,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<_LightboxOverlay> createState() => _LightboxOverlayState();
}

class _LightboxOverlayState extends State<_LightboxOverlay> {
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
    return Semantics(
      label:
          'Full-screen media viewer, ${_currentIndex + 1} of ${widget.mediaItems.length}',
      hint: 'Swipe to navigate, double-tap to zoom, tap close button to exit',
      child: Material(
        color: Colors.black.withOpacity(0.95),
        child: Stack(
          children: [
            // Backdrop with blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
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
                return _LightboxMediaSlide(item: item);
              },
            ),
            // Close button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page indicator
                    if (widget.mediaItems.length > 1)
                      Semantics(
                        label:
                            'Page ${_currentIndex + 1} of ${widget.mediaItems.length}',
                        child: Container(
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
                      ),
                    // Close button
                    Semantics(
                      label: 'Close full-screen viewer',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: widget.onClose,
                        tooltip: 'Close',
                      ),
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
      ),
    );
  }
}

/// Lightbox media slide (photo or video)
class _LightboxMediaSlide extends ConsumerStatefulWidget {
  final _MediaItem item;

  const _LightboxMediaSlide({required this.item});

  @override
  ConsumerState<_LightboxMediaSlide> createState() =>
      _LightboxMediaSlideState();
}

class _LightboxMediaSlideState extends ConsumerState<_LightboxMediaSlide> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (!widget.item.isPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVideo();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    try {
      final videoUrl = await imageCache.getSignedUrlForDetailView(
        supabase,
        'memories-videos',
        widget.item.video!.url,
      );

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Handle error silently in lightbox
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
    if (widget.item.isPhoto) {
      return _LightboxPhotoSlide(photo: widget.item.photo!);
    } else {
      return _LightboxVideoSlide(
        video: widget.item.video!,
        controller: _controller,
        isInitialized: _isInitialized,
        isPlaying: _isPlaying,
        onTogglePlayPause: _togglePlayPause,
      );
    }
  }
}

/// Lightbox photo slide with zoom
class _LightboxPhotoSlide extends ConsumerStatefulWidget {
  final PhotoMedia photo;

  const _LightboxPhotoSlide({required this.photo});

  @override
  ConsumerState<_LightboxPhotoSlide> createState() =>
      _LightboxPhotoSlideState();
}

class _LightboxPhotoSlideState extends ConsumerState<_LightboxPhotoSlide> {
  final TransformationController _transformationController =
      TransformationController();
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
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 3.0,
        child: Center(
          child: FutureBuilder<String>(
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
          ),
        ),
      ),
    );
  }
}

/// Lightbox video slide
class _LightboxVideoSlide extends ConsumerWidget {
  final VideoMedia video;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool isPlaying;
  final VoidCallback onTogglePlayPause;

  const _LightboxVideoSlide({
    required this.video,
    required this.controller,
    required this.isInitialized,
    required this.isPlaying,
    required this.onTogglePlayPause,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);

    return Stack(
      children: [
        // Video player or poster
        if (isInitialized && controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: VideoPlayer(controller!),
            ),
          )
        else
          FutureBuilder<String?>(
            future: video.posterUrl != null
                ? imageCache.getSignedUrlForDetailView(
                    supabase,
                    'memories-photos',
                    video.posterUrl!,
                  )
                : Future.value(null),
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
          ),
        // Play/pause overlay
        if (isInitialized && controller != null)
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTogglePlayPause,
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

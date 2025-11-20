import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/memory_detail_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';
import 'package:memories/providers/main_navigation_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/widgets/media_strip.dart';
import 'package:memories/widgets/media_preview.dart';
import 'package:memories/widgets/memory_metadata_section.dart';
import 'package:memories/widgets/rich_text_content.dart';
import 'package:memories/widgets/sticky_audio_player.dart';

/// Memory detail screen showing full memory content
/// 
/// Displays title, description, media strip with preview, and metadata in a scrollable
/// layout with app bar and skeleton loaders while loading.
class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String memoryId;
  final String? heroTag; // Optional hero tag for transition animation

  const MemoryDetailScreen({
    super.key,
    required this.memoryId,
    this.heroTag,
  });

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  int? _selectedMediaIndex;

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(memoryDetailNotifierProvider(widget.memoryId));
    final connectivityService = ref.read(connectivityServiceProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Edit icon in app bar - disabled when offline
          if (detailState.memory != null)
            FutureBuilder<bool>(
              future: connectivityService.isOnline(),
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? false;
                final memoryType = detailState.memory!.memoryType;
                final editLabel = memoryType == 'story' 
                    ? 'Edit story' 
                    : memoryType == 'memento'
                        ? 'Edit memento'
                        : 'Edit moment';
                return Semantics(
                  label: editLabel,
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: isOnline
                        ? () => _handleEdit(context, ref, detailState.memory!)
                        : () => _showOfflineTooltip(context, 'Edit requires internet connection'),
                    tooltip: isOnline ? 'Edit' : 'Edit unavailable offline',
                  ),
                );
              },
            ),
          // Share icon in app bar - disabled when offline or viewing cached data
          FutureBuilder<bool>(
            future: connectivityService.isOnline(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              final canShare = isOnline && 
                  detailState.memory != null && 
                  !detailState.isFromCache;
              final memoryType = detailState.memory?.memoryType ?? 'moment';
              final shareLabel = memoryType == 'story' 
                  ? 'Share story' 
                  : memoryType == 'memento'
                      ? 'Share memento'
                      : 'Share moment';
              return Semantics(
                label: shareLabel,
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: canShare
                      ? () => _handleShare(context, ref, detailState.memory!)
                      : null,
                  tooltip: canShare 
                      ? 'Share' 
                      : detailState.isFromCache
                          ? 'Share unavailable for cached content'
                          : 'Share unavailable offline',
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(context, detailState, ref),
          // Floating action button for delete
          if (detailState.memory != null)
            _buildFloatingActions(context, ref, detailState.memory!),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MemoryDetailViewState state,
    WidgetRef ref,
  ) {
    switch (state.state) {
      case MemoryDetailState.initial:
      case MemoryDetailState.loading:
        return _buildLoadingState(context);
      case MemoryDetailState.error:
        return _buildErrorState(context, state.errorMessage ?? 'Unknown error', ref);
      case MemoryDetailState.loaded:
        return _buildLoadedState(
          context,
          state.memory!,
          isFromCache: state.isFromCache,
        );
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Title skeleton - matches headlineMedium style
              Container(
                width: double.infinity,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Description skeleton - multiple lines with varying widths
              ...List.generate(4, (index) {
                final width = index == 0 
                    ? double.infinity 
                    : index == 3 
                        ? 120.0 
                        : double.infinity * (0.85 - (index * 0.1));
                return Padding(
                  padding: EdgeInsets.only(bottom: index < 3 ? 8 : 0),
                  child: Container(
                    width: width,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              // Media carousel skeleton - aspect ratio placeholder with shimmer effect
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Metadata skeleton - timestamp row
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 180,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Metadata skeleton - location row (optional)
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String errorMessage,
    WidgetRef ref,
  ) {
    // Inline error block within scrollable content
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Error block with retry button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Failed to load memory',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    MemoryDetail memory, {
    bool isFromCache = false,
  }) {
    final isStory = memory.memoryType == 'story';
    final hasMedia = memory.photos.isNotEmpty || memory.videos.isNotEmpty;
    
    return CustomScrollView(
      slivers: [
        // Offline banner if viewing cached data
        if (isFromCache)
          SliverToBoxAdapter(
            child: _buildOfflineBanner(context),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Title section - handles empty title via displayTitle
              Text(
                memory.displayTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              // Tags underneath title
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memory.tags.map((tag) => Chip(
                    label: Text(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 16),
            ]),
          ),
        ),
        
        // Sticky audio player for Stories (only if Story)
        if (isStory)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyAudioPlayerDelegate(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StickyAudioPlayer(
                  audioUrl: null, // TODO: Add audioUrl when available in memory_detail
                  duration: null, // TODO: Add duration when available in memory_detail
                  storyId: memory.id,
                ),
              ),
            ),
          ),
        
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Story-specific layout: narrative text after audio player
              if (isStory) ...[
                // Narrative text (uses displayText which prefers processed_text)
                RichTextContent(
                  text: memory.displayText,
                ),
              ] else ...[
                // Memory layout: description → media strip → media preview
                // Rich text description with markdown support and "Read more" functionality
                // Handles empty/absent description gracefully (returns SizedBox.shrink)
                RichTextContent(
                  text: memory.displayText,
                ),
                // Media strip - horizontally scrolling thumbnails
                if (hasMedia) ...[
                  const SizedBox(height: 24),
                  MediaStrip(
                    photos: memory.photos,
                    videos: memory.videos,
                    selectedIndex: _selectedMediaIndex,
                    onThumbnailSelected: (index) {
                      setState(() {
                        _selectedMediaIndex = index;
                      });
                    },
                  ),
                  // Media preview - larger preview of selected thumbnail
                  if (_selectedMediaIndex != null) ...[
                    const SizedBox(height: 16),
                    MediaPreview(
                      photos: memory.photos,
                      videos: memory.videos,
                      selectedIndex: _selectedMediaIndex,
                    ),
                  ],
                ],
              ],
              
              const SizedBox(height: 24),
              // Metadata section: timestamp, location, and related memories
              MemoryMetadataSection(memory: memory),
            ]),
          ),
        ),
      ],
    );
  }

  /// Build offline banner explaining limitations
  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached content. Some features may be unavailable offline.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build floating action button for delete
  Widget _buildFloatingActions(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) {
    final connectivityService = ref.read(connectivityServiceProvider);
    
    return FutureBuilder<bool>(
      future: connectivityService.isOnline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        final memoryType = memory.memoryType;
        final deleteLabel = memoryType == 'story' 
            ? 'Delete story' 
            : memoryType == 'memento'
                ? 'Delete memento'
                : 'Delete moment';
        
        return Positioned(
          bottom: 16,
          right: 16,
          child: Semantics(
            label: deleteLabel,
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: isOnline
                  ? () => _showDeleteConfirmation(context, ref, memory)
                  : () => _showOfflineTooltip(context, 'Delete requires internet connection'),
              tooltip: isOnline ? 'Delete' : 'Delete unavailable offline',
            ),
          ),
        );
      },
    );
  }


  /// Handle share action
  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final notifier = ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);

    try {
      // Track share attempt
      analytics.trackMemoryShare(memory.id, shareToken: memory.publicShareToken);

      // Get share link
      final shareLink = await notifier.getShareLink();

      if (shareLink == null) {
        // Share link unavailable
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sharing unavailable. Try again later.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show OS share sheet
      if (context.mounted) {
        await Share.share(
          shareLink,
          subject: memory.displayTitle,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle edit action
  void _handleEdit(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    analytics.trackMemoryDetailEdit(memory.id);

    // Load memory data into capture state for editing
    final captureNotifier = ref.read(captureStateNotifierProvider.notifier);
    
    // Extract existing media URLs
    final existingPhotoUrls = memory.photos.map((p) => p.url).toList();
    final existingVideoUrls = memory.videos.map((v) => v.url).toList();
    
    captureNotifier.loadMemoryForEdit(
      memoryId: memory.id,
      captureType: memory.memoryType,
      inputText: memory.inputText, // Use inputText for editing (raw user text)
      tags: memory.tags,
      latitude: memory.locationData?.latitude,
      longitude: memory.locationData?.longitude,
      locationStatus: memory.locationData?.status,
      existingPhotoUrls: existingPhotoUrls,
      existingVideoUrls: existingVideoUrls,
    );

    // Pop back to main navigation shell, then switch to capture tab
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Switch to capture tab in main navigation
    ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
    // Refresh detail view after switching (in case user navigates back)
    ref.read(memoryDetailNotifierProvider(memory.id).notifier).refresh();
  }

  /// Show delete confirmation bottom sheet
  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delete "${memory.displayTitle}"?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              memory.memoryType == 'story'
                  ? 'This action cannot be undone. The story and all its content will be permanently deleted.'
                  : memory.memoryType == 'memento'
                      ? 'This action cannot be undone. The memento and all its media will be permanently deleted.'
                      : 'This action cannot be undone. The moment and all its media will be permanently deleted.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Show loading feedback immediately
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Deleting...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    await _handleDelete(context, ref, memory);
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Handle delete action with optimistic UI removal
  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final notifier = ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);
    final isStory = memory.memoryType == 'story';
    
    // Get unified feed controller for current selected types
    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    final selectedTypes = tabState.valueOrNull ?? {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };
    final unifiedFeedController = ref.read(unifiedFeedControllerProvider(selectedTypes).notifier);

    // Track delete action
    analytics.trackMemoryDetailDelete(memory.id);

    try {
      // Optimistically remove from unified feed
      unifiedFeedController.removeMemory(memory.id);

      // Delete from backend
      final success = await notifier.deleteMemory();

      if (!context.mounted) return;

      if (success) {
        final deleteMessage = isStory 
            ? 'Story deleted' 
            : memory.memoryType == 'memento'
                ? 'Memento deleted'
                : 'Moment deleted';
        
        // Refresh unified feed to ensure consistency (memory is gone from DB)
        unifiedFeedController.refresh();
        
        // Show success message first (will be visible briefly before pop)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteMessage),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Pop detail screen immediately after showing message
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Navigate to timeline screen
        ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();
      } else {
        // Refresh unified feed to restore the memory if delete failed
        unifiedFeedController.refresh();
        final errorMessage = isStory 
            ? 'Failed to delete story. Please try again.'
            : memory.memoryType == 'memento'
                ? 'Failed to delete memento. Please try again.'
                : 'Failed to delete memory. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[MemoryDetailScreen] Error in _handleDelete: $e');
      debugPrint('[MemoryDetailScreen] Stack trace: $stackTrace');
      
      // Check if the error indicates the memory was actually deleted
      final errorString = e.toString().toLowerCase();
      final mightBeDeleted = errorString.contains('not found') || 
                            errorString.contains('does not exist') ||
                            errorString.contains('already deleted');
      
      if (mightBeDeleted) {
        // Memory might have been deleted despite the error - navigate away
        debugPrint('[MemoryDetailScreen] Error suggests memory was deleted, navigating away');
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        // Navigate to timeline screen
        ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();
      } else {
        // Refresh unified feed to restore the memory
        unifiedFeedController.refresh();
        
        if (!context.mounted) return;
        
        final errorMessage = isStory 
            ? 'Failed to delete story: ${e.toString()}'
            : memory.memoryType == 'memento'
                ? 'Failed to delete memento: ${e.toString()}'
                : 'Failed to delete memory: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show offline tooltip/banner
  void _showOfflineTooltip(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Delegate for sticky audio player header
class _StickyAudioPlayerDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyAudioPlayerDelegate({required this.child});

  @override
  double get minExtent => 100;

  @override
  double get maxExtent => 100;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickyAudioPlayerDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}


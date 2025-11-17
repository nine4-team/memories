import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:memories/models/moment_detail.dart';
import 'package:memories/providers/moment_detail_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/widgets/media_carousel.dart';
import 'package:memories/widgets/moment_metadata_section.dart';
import 'package:memories/widgets/rich_text_content.dart';

/// Moment detail screen showing full moment content
/// 
/// Displays title, description, media carousel, and metadata in a scrollable
/// layout with app bar and skeleton loaders while loading.
class MomentDetailScreen extends ConsumerWidget {
  final String momentId;
  final String? heroTag; // Optional hero tag for transition animation

  const MomentDetailScreen({
    super.key,
    required this.momentId,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(momentDetailNotifierProvider(momentId));
    final connectivityService = ref.read(connectivityServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detailState.moment?.displayTitle ?? 'Memory',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Share icon in app bar - disabled when offline or viewing cached data
          FutureBuilder<bool>(
            future: connectivityService.isOnline(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              final canShare = isOnline && 
                  detailState.moment != null && 
                  !detailState.isFromCache;
              return Semantics(
                label: 'Share moment',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: canShare
                      ? () => _handleShare(context, ref, detailState.moment!)
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
          _buildBody(context, detailState, ref, heroTag),
          // Floating action buttons for edit/delete
          if (detailState.moment != null)
            _buildFloatingActions(context, ref, detailState.moment!),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MomentDetailViewState state,
    WidgetRef ref,
    String? heroTag,
  ) {
    switch (state.state) {
      case MomentDetailState.initial:
      case MomentDetailState.loading:
        return _buildLoadingState(context);
      case MomentDetailState.error:
        return _buildErrorState(context, state.errorMessage ?? 'Unknown error', ref);
      case MomentDetailState.loaded:
        return _buildLoadedState(
          context,
          state.moment!,
          heroTag,
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
                            'Failed to load moment',
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
                          ref.read(momentDetailNotifierProvider(momentId).notifier).refresh();
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
    MomentDetail moment,
    String? heroTag, {
    bool isFromCache = false,
  }) {
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
              // Title section - handles empty title via displayTitle ("Untitled Moment")
              Text(
                moment.displayTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              // Rich text description with markdown support and "Read more" functionality
              // Handles empty/absent description gracefully (returns SizedBox.shrink)
              RichTextContent(
                text: moment.textDescription,
              ),
              const SizedBox(height: 24),
              // Media carousel with swipeable PageView, zoom, and lightbox
              if (moment.photos.isNotEmpty || moment.videos.isNotEmpty)
                MediaCarousel(
                  photos: moment.photos,
                  videos: moment.videos,
                  heroTag: heroTag,
                ),
              const SizedBox(height: 24),
              // Metadata section: timestamp, location, and related memories
              MomentMetadataSection(moment: moment),
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

  /// Build floating action buttons for edit and delete
  Widget _buildFloatingActions(
    BuildContext context,
    WidgetRef ref,
    MomentDetail moment,
  ) {
    final connectivityService = ref.read(connectivityServiceProvider);
    
    return FutureBuilder<bool>(
      future: connectivityService.isOnline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        
        return Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              Semantics(
                label: 'Edit moment',
                button: true,
                child: FloatingActionButton(
                  heroTag: 'edit_moment_${moment.id}',
                  mini: true,
                  onPressed: isOnline
                      ? () => _handleEdit(context, ref, moment)
                      : () => _showOfflineTooltip(context, 'Edit requires internet connection'),
                  tooltip: isOnline ? 'Edit' : 'Edit unavailable offline',
                  child: const Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 8),
              // Delete button
              Semantics(
                label: 'Delete moment',
                button: true,
                child: FloatingActionButton(
                  heroTag: 'delete_moment_${moment.id}',
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  onPressed: isOnline
                      ? () => _showDeleteConfirmation(context, ref, moment)
                      : () => _showOfflineTooltip(context, 'Delete requires internet connection'),
                  tooltip: isOnline ? 'Delete' : 'Delete unavailable offline',
                  child: const Icon(Icons.delete),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handle share action
  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    MomentDetail moment,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final notifier = ref.read(momentDetailNotifierProvider(momentId).notifier);

    try {
      // Track share attempt
      analytics.trackMomentShare(moment.id, shareToken: moment.publicShareToken);

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
          subject: moment.displayTitle,
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
    MomentDetail moment,
  ) {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    analytics.trackMomentDetailEdit(moment.id);

    // TODO: Navigate to edit modal/route when edit functionality is implemented
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show delete confirmation bottom sheet
  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    MomentDetail moment,
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
              'Delete "${moment.displayTitle}"?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. The moment and all its media will be permanently deleted.',
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
                    await _handleDelete(context, ref, moment);
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
    MomentDetail moment,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final notifier = ref.read(momentDetailNotifierProvider(momentId).notifier);
    final timelineNotifier = ref.read(timelineFeedNotifierProvider.notifier);

    // Track delete action
    analytics.trackMomentDetailDelete(moment.id);

    try {
      // Optimistically remove from timeline
      timelineNotifier.removeMoment(moment.id);

      // Delete from backend
      final success = await notifier.deleteMoment();

      if (success) {
        // Pop detail screen and show success message
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Moment deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Refresh timeline to restore the moment if delete failed
        timelineNotifier.refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete moment. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Refresh timeline to restore the moment
      timelineNotifier.refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete moment: $e'),
            duration: const Duration(seconds: 3),
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


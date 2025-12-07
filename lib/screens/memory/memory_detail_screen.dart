import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/memory_processing_status.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/memory_detail_provider.dart';
import 'package:memories/providers/offline_memory_detail_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/providers/memory_timeline_update_bus_provider.dart';
import 'package:memories/providers/main_navigation_provider.dart';
import 'package:memories/providers/memory_processing_status_provider.dart';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/shared_preferences_local_memory_preview_store.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_image_cache_provider.dart';
import 'package:memories/widgets/media_strip.dart';
import 'package:memories/widgets/media_preview.dart';
import 'package:memories/widgets/memory_metadata_section.dart';
import 'package:memories/widgets/memory_title_with_processing.dart';
import 'package:memories/widgets/rich_text_content.dart';
import 'package:memories/widgets/sticky_audio_player.dart';

/// Memory detail screen showing full memory content
///
/// Displays title, description, media strip with preview, and metadata in a scrollable
/// layout with app bar and skeleton loaders while loading.
class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String memoryId;
  final String? heroTag; // Optional hero tag for transition animation
  final bool isOfflineQueued; // Whether this memory is a queued offline item
  final String? fallbackServerId; // Server ID to use when falling back online

  const MemoryDetailScreen({
    super.key,
    required this.memoryId,
    this.heroTag,
    this.isOfflineQueued = false,
    this.fallbackServerId,
  });

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  int? _selectedMediaIndex;
  bool _loggedMissingSelection = false;
  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _ensureMediaSelection(MemoryDetail memory) {
    final totalMedia = memory.photos.length + memory.videos.length;
    final selectedIndex = _selectedMediaIndex;

    if (totalMedia == 0) {
      if (selectedIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedMediaIndex = null;
          });
        });
      }
      return;
    }

    if (selectedIndex == null || selectedIndex >= totalMedia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedMediaIndex = 0;
        });
        developer.log(
          '[MemoryDetailScreen] Auto-selected first media '
          'memoryId=${memory.id} totalMedia=$totalMedia previousIndex=$selectedIndex',
          name: 'MemoryDetailScreen',
        );
      });
    }
  }

  void _logMissingMediaSelection(String memoryId, int mediaCount) {
    if (_loggedMissingSelection || mediaCount <= 0) {
      return;
    }
    _loggedMissingSelection = true;
    developer.log(
      '[MemoryDetailScreen] Media selection missing '
      'memoryId=$memoryId mediaCount=$mediaCount',
      name: 'MemoryDetailScreen',
    );
  }

  Widget _buildMediaPlaceholder({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewContent(
    BuildContext context,
    MemoryDetail memory,
  ) {
    final totalMedia = memory.photos.length + memory.videos.length;
    if (_selectedMediaIndex == null ||
        _selectedMediaIndex! < 0 ||
        _selectedMediaIndex! >= totalMedia) {
      _logMissingMediaSelection(memory.id, totalMedia);
      return _buildMediaPlaceholder(
        context: context,
        icon: Icons.photo_library_outlined,
        title: 'Select a thumbnail',
        message: 'Choose a photo or video to preview it here.',
      );
    }

    return MediaPreview(
      memoryId: memory.id,
      photos: memory.photos,
      videos: memory.videos,
      selectedIndex: _selectedMediaIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Route to offline provider for queued items, online provider for synced items
    final connectivityService = ref.read(connectivityServiceProvider);

    // For offline queued items, use offline provider
    if (widget.isOfflineQueued) {
      return _buildOfflineDetailScreen(context, connectivityService);
    }

    // For online/synced items, use existing online provider
    final detailState =
        ref.watch(memoryDetailNotifierProvider(widget.memoryId));
    return _buildOnlineDetailScreen(context, detailState, connectivityService);
  }

  /// Build detail screen for offline queued memories
  Widget _buildOfflineDetailScreen(
    BuildContext context,
    ConnectivityService connectivityService,
  ) {
    final detailAsync =
        ref.watch(offlineMemoryDetailNotifierProvider(widget.memoryId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Edit icon - enabled for offline queued items (Phase 4)
          if (detailAsync.hasValue)
            Builder(
              builder: (context) {
                final memory = detailAsync.value!;
                final memoryType = memory.memoryType;
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
                    onPressed: () => _handleEditOffline(context, ref, memory),
                    tooltip: 'Edit',
                  ),
                );
              },
            ),
          // Share icon - disabled for offline queued items
          Builder(
            builder: (context) {
              final memoryType = detailAsync.value?.memoryType ?? 'moment';
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
                  onPressed: null,
                  tooltip: 'Share available after this memory syncs',
                  color: Colors.grey,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          detailAsync.when(
            data: (memory) {
              return Column(
                children: [
                  // Offline queued status banner
                  FutureBuilder<OfflineSyncStatus>(
                    future: _getOfflineSyncStatus(ref, widget.memoryId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return _buildOfflineQueuedBanner(
                            context, snapshot.data!);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Expanded(
                    child: _buildLoadedState(
                      context,
                      memory,
                      isFromCache: true, // Mark as cached to disable share
                    ),
                  ),
                ],
              );
            },
            loading: () => _buildLoadingState(context),
            error: (error, stackTrace) => _buildOfflineErrorState(
              context,
              error.toString(),
              ref,
              connectivityService,
            ),
          ),
          // Floating action button for delete - disabled for offline queued items
          if (detailAsync.hasValue)
            _buildFloatingActions(context, ref, detailAsync.value!),
        ],
      ),
    );
  }

  /// Get offline sync status for a queued memory
  Future<OfflineSyncStatus> _getOfflineSyncStatus(
    WidgetRef ref,
    String localId,
  ) async {
    final queueService = ref.read(offlineMemoryQueueServiceProvider);

    // Find in unified queue
    final queuedMemory = await queueService.getByLocalId(localId);
    if (queuedMemory != null) {
      return _mapQueueStatusToOfflineSyncStatus(queuedMemory.status);
    }

    // Default to queued if not found
    return OfflineSyncStatus.queued;
  }

  /// Map queue status string to OfflineSyncStatus enum
  OfflineSyncStatus _mapQueueStatusToOfflineSyncStatus(String status) {
    switch (status) {
      case 'queued':
        return OfflineSyncStatus.queued;
      case 'syncing':
        return OfflineSyncStatus.syncing;
      case 'failed':
        return OfflineSyncStatus.failed;
      case 'completed':
        return OfflineSyncStatus.synced;
      default:
        return OfflineSyncStatus.queued;
    }
  }

  /// Build processing status banner for server-backed memories
  Widget _buildProcessingStatusBanner(
    BuildContext context,
    WidgetRef ref,
    String memoryId,
  ) {
    final statusAsync =
        ref.watch(memoryProcessingStatusStreamProvider(memoryId));

    return statusAsync.when(
      data: (status) {
        // Only show if processing is in progress
        if (status == null || !status.isInProgress) {
          return const SizedBox.shrink();
        }

        String message;
        Color background;
        Color textColor;

        switch (status.state) {
          case MemoryProcessingState.scheduled:
            message = 'Processing scheduled...';
            background = Colors.blue.shade50;
            textColor = Colors.blue.shade900;
            break;
          case MemoryProcessingState.processing:
            // Check metadata for phase information
            final phase = status.phase;
            if (phase != null) {
              switch (phase) {
                case 'title':
                case 'title_generation':
                  message = 'Generating title...';
                  break;
                case 'text':
                case 'text_processing':
                  message = 'Processing text...';
                  break;
                case 'narrative':
                case 'narrative_generation':
                  message = 'Generating narrative...';
                  break;
                default:
                  message = 'Processing memory...';
              }
            } else {
              message = 'Processing memory...';
            }
            background = Colors.blue.shade50;
            textColor = Colors.blue.shade900;
            break;
          case MemoryProcessingState.failed:
            message = 'Processing failed. We\'ll retry automatically.';
            background = Colors.red.shade50;
            textColor = Colors.red.shade900;
            break;
          case MemoryProcessingState.complete:
            return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            border: Border(
              bottom: BorderSide(color: textColor.withOpacity(0.25)),
            ),
          ),
          child: Row(
            children: [
              if (status.state == MemoryProcessingState.processing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              else if (status.state == MemoryProcessingState.scheduled)
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: textColor,
                )
              else
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: textColor,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor,
                      ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Build offline queued status banner
  Widget _buildOfflineQueuedBanner(
    BuildContext context,
    OfflineSyncStatus status,
  ) {
    late final String title;
    late final String subtitle;
    late final Color background;
    late final Color textColor;

    switch (status) {
      case OfflineSyncStatus.queued:
        title = 'Pending sync';
        subtitle = 'This memory will upload automatically when you\'re online.';
        background = Colors.orange.shade50;
        textColor = Colors.orange.shade900;
        break;
      case OfflineSyncStatus.syncing:
        title = 'Syncing...';
        subtitle = 'We\'re uploading this memory in the background.';
        background = Colors.blue.shade50;
        textColor = Colors.blue.shade900;
        break;
      case OfflineSyncStatus.failed:
        title = 'Sync failed';
        subtitle = 'We\'ll retry automatically. You can also try again later.';
        background = Colors.red.shade50;
        textColor = Colors.red.shade900;
        break;
      case OfflineSyncStatus.synced:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: textColor.withOpacity(0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  /// Build detail screen for online/synced memories
  Widget _buildOnlineDetailScreen(
    BuildContext context,
    MemoryDetailViewState detailState,
    ConnectivityService connectivityService,
  ) {
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
                        : () => _showOfflineTooltip(
                            context, 'Edit requires internet connection'),
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
          Column(
            children: [
              // Processing status banner for server-backed memories
              if (detailState.memory != null)
                _buildProcessingStatusBanner(
                    context, ref, detailState.memory!.id),
              Expanded(
                child: _buildBody(context, detailState, ref),
              ),
            ],
          ),
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
        return _buildErrorState(
            context, state.errorMessage ?? 'Unknown error', ref);
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.3),
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

  /// Build error state specifically for offline queued memory errors
  Widget _buildOfflineErrorState(
    BuildContext context,
    String errorMessage,
    WidgetRef ref,
    ConnectivityService connectivityService,
  ) {
    // Check if this is the "Offline queued memory not found" error
    final isOfflineQueuedNotFound =
        errorMessage.contains('Offline queued memory not found');
    final hasFallbackServer = widget.fallbackServerId != null;
    // Only claim memory synced if we have a fallback server ID
    // Otherwise, the queue entry is missing but memory hasn't synced
    final title = isOfflineQueuedNotFound && hasFallbackServer
        ? 'Memory Already Synced'
        : 'Offline Memory Unavailable';
    final description = isOfflineQueuedNotFound && hasFallbackServer
        ? 'This memory has already synced to the server. Refresh the timeline to see the updated version.'
        : 'We couldn’t load this queued memory while offline. You can retry the offline request or head back to the timeline.';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
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
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isOfflineQueuedNotFound) {
                            _popToTimelineAndRefresh(ref);
                          } else {
                            ref.invalidate(
                              offlineMemoryDetailNotifierProvider(
                                widget.memoryId,
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isOfflineQueuedNotFound
                              ? Icons.arrow_back
                              : Icons.refresh,
                        ),
                        label: Text(
                          isOfflineQueuedNotFound
                              ? 'Go Back to Timeline'
                              : 'Retry Offline',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ),
                    if (!isOfflineQueuedNotFound)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Timeline'),
                        ),
                      ),
                    if (hasFallbackServer)
                      FutureBuilder<bool>(
                        future: connectivityService.isOnline(),
                        builder: (context, snapshot) {
                          if (snapshot.data == true) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _openServerDetailFromOffline,
                                  icon: const Icon(Icons.cloud_download),
                                  label: const Text('Try Loading from Server'),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
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

  void _popToTimelineAndRefresh(WidgetRef ref) {
    if (!mounted) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final tabState = ref.read(unifiedFeedTabNotifierProvider);
    tabState.whenData((selectedTypes) {
      ref.read(unifiedFeedControllerProvider(selectedTypes).notifier).refresh();
    });
  }

  void _openServerDetailFromOffline() {
    final serverId = widget.fallbackServerId;
    if (serverId == null || !mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MemoryDetailScreen(
          memoryId: serverId,
          heroTag: widget.heroTag,
          isOfflineQueued: false,
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String errorMessage,
    WidgetRef ref,
  ) {
    // If memory was deleted (e.g., user navigated to a deleted memory), navigate away
    if (errorMessage == 'Memory has been deleted') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          // Pop detail screen if we can
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Navigate to timeline screen
          ref
              .read(mainNavigationTabNotifierProvider.notifier)
              .switchToTimeline();
        }
      });
      // Return empty container while navigating
      return const SizedBox.shrink();
    }

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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
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
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(
                                  memoryDetailNotifierProvider(widget.memoryId)
                                      .notifier)
                              .refresh();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
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
    final hasRelatedMemories =
        memory.relatedStories.isNotEmpty || memory.relatedMementos.isNotEmpty;
    final memoryLocationLabel = ref.watch(captureStateNotifierProvider.select(
      (state) =>
          state.editingMemoryId == memory.id ? state.memoryLocationLabel : null,
    ));
    _ensureMediaSelection(memory);

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
              // Title section - editable when tapped
              _buildTitleWidget(context, ref, memory),
              // Tags underneath title
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memory.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              MemoryMetadataSection(
                memory: memory,
                memoryLocationLabel: memoryLocationLabel,
                showRelatedMemories: false,
              ),
            ]),
          ),
        ),

        // Sticky audio player for Stories (only if Story has audio)
        // Only show audio player if the story actually has audio data
        if (isStory &&
            memory.audioPath != null &&
            memory.audioPath!.isNotEmpty) ...[
          Builder(
            builder: (context) {
              developer.log(
                '[MemoryDetailScreen] Creating audio player for story '
                'id=${memory.id} audioPath=${memory.audioPath} '
                'audioDuration=${memory.audioDuration}',
                name: 'MemoryDetailScreen',
              );
              return _StoryAudioPlayerSliver(
                audioPath: memory.audioPath,
                audioDuration: memory.audioDuration,
                storyId: memory.id,
              );
            },
          ),
        ],

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
                // Memory layout: description ? media strip ? media preview
                // Rich text description with markdown support and "Read more" functionality
                // Handles empty/absent description gracefully (returns SizedBox.shrink)
                RichTextContent(
                  text: memory.displayText,
                ),
                if (hasRelatedMemories) ...[
                  const SizedBox(height: 24),
                  MemoryMetadataSection(
                    memory: memory,
                    memoryLocationLabel: memoryLocationLabel,
                    showTimestamp: false,
                    showLocation: false,
                  ),
                ],
                // Media strip - horizontally scrolling thumbnails
                const SizedBox(height: 24),
                if (hasMedia) ...[
                  MediaStrip(
                    memoryId: memory.id,
                    photos: memory.photos,
                    videos: memory.videos,
                    selectedIndex: _selectedMediaIndex,
                    onThumbnailSelected: (index) {
                      setState(() {
                        _selectedMediaIndex = index;
                      });
                    },
                    onMediaRemoved: (media) => _handleMediaRemoval(
                      context,
                      ref,
                      memory,
                      media.url,
                      media.isPhoto,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMediaPreviewContent(context, memory),
                  const SizedBox(height: 24),
                ] else ...[
                  // Show different message for text-cached memories (media not available offline)
                  if (isFromCache && !widget.isOfflineQueued)
                    _buildMediaPlaceholder(
                      context: context,
                      icon: Icons.cloud_off_outlined,
                      title: 'Media not available offline',
                      message:
                          'Photos and videos require an internet connection to view.',
                    )
                  else
                    _buildMediaPlaceholder(
                      context: context,
                      icon: Icons.burst_mode_outlined,
                      title: 'No photos or videos yet',
                      message: 'Add media from the edit screen to see it here.',
                    ),
                  const SizedBox(height: 24),
                ],
              ],
            ]),
          ),
        ),
      ],
    );
  }

  /// Build offline banner explaining limitations
  /// Shows different messages for queued memories vs text-cached synced memories
  Widget _buildOfflineBanner(BuildContext context) {
    // For text-cached synced memories (not queued), show media limitation message
    if (!widget.isOfflineQueued) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.blue.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: Colors.blue.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Text available offline. Media requires internet connection.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    // For queued memories, show sync status (existing behavior)
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
    final memoryType = memory.memoryType;
    final deleteLabel = memoryType == 'story'
        ? 'Delete story'
        : memoryType == 'memento'
            ? 'Delete memento'
            : 'Delete moment';

    // For offline queued memories, delete is always available (local operation)
    if (widget.isOfflineQueued) {
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
            onPressed: () =>
                _showDeleteConfirmationForQueued(context, ref, memory),
            tooltip: 'Delete',
          ),
        ),
      );
    }

    // For server-backed memories, require online connection
    final connectivityService = ref.read(connectivityServiceProvider);

    return FutureBuilder<bool>(
      future: connectivityService.isOnline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

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
                  : () => _showOfflineTooltip(
                      context, 'Delete requires internet connection'),
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
    final notifier =
        ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);

    try {
      // Track share attempt
      analytics.trackMemoryShare(memory.id,
          shareToken: memory.publicShareToken);

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

  /// Handle edit action for offline queued memories
  void _handleEditOffline(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail detail,
  ) {
    final captureNotifier = ref.read(captureStateNotifierProvider.notifier);

    // Extract local file paths from file:// URLs
    final photoPaths =
        detail.photos.map((p) => p.url.replaceFirst('file://', '')).toList();
    final videoPaths =
        detail.videos.map((v) => v.url.replaceFirst('file://', '')).toList();
    final videoPosterPaths = detail.videos
        .map((v) => v.posterUrl?.replaceFirst('file://', ''))
        .toList();

    // Determine memory type
    final memoryType = MemoryTypeExtension.fromApiValue(detail.memoryType);

    captureNotifier.loadOfflineMemoryForEdit(
      localId: detail.id,
      memoryType: memoryType,
      inputText: detail.displayText,
      tags: detail.tags,
      existingPhotoPaths: photoPaths,
      existingVideoPaths: videoPaths,
      existingVideoPosterPaths: videoPosterPaths,
      latitude: detail.locationData?.latitude,
      longitude: detail.locationData?.longitude,
      locationStatus: detail.locationData?.status,
      capturedAt: detail.capturedAt,
      memoryDate: detail.memoryDate,
    );

    // Load memory location data (where event happened) if available
    if (detail.memoryLocationData != null) {
      captureNotifier.setMemoryLocationFromData(detail.memoryLocationData);
    }

    // Navigate to capture screen as usual
    Navigator.of(context).pop();
    ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
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
    final existingVideoPosterUrls =
        memory.videos.map((v) => v.posterUrl).toList();

    captureNotifier.loadMemoryForEdit(
      memoryId: memory.id,
      captureType: memory.memoryType,
      inputText:
          memory.displayText, // Use displayText to fall back to processed text
      tags: memory.tags,
      latitude: memory.locationData?.latitude,
      longitude: memory.locationData?.longitude,
      locationStatus: memory.locationData?.status,
      existingPhotoUrls: existingPhotoUrls,
      existingVideoUrls: existingVideoUrls,
      existingVideoPosterUrls: existingVideoPosterUrls,
      memoryDate: memory.memoryDate,
    );

    // Load memory location data (where event happened) if available
    if (memory.memoryLocationData != null) {
      captureNotifier.setMemoryLocationFromData(memory.memoryLocationData);
    }

    // Pop back to main navigation shell, then switch to capture tab
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Switch to capture tab in main navigation
    ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
    // Refresh detail view after switching (in case user navigates back)
    ref.read(memoryDetailNotifierProvider(memory.id).notifier).refresh();
  }

  /// Show delete confirmation bottom sheet for queued memories
  void _showDeleteConfirmationForQueued(
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
                  ? 'This action cannot be undone. The unsynced story and all its content will be permanently deleted.'
                  : memory.memoryType == 'memento'
                      ? 'This action cannot be undone. The unsynced memento and all its media will be permanently deleted.'
                      : 'This action cannot be undone. The unsynced moment and all its media will be permanently deleted.',
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
                    await _handleDeleteQueuedMemory(context, ref, memory);
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

  /// Handle delete action for queued offline memories
  Future<void> _handleDeleteQueuedMemory(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final queueService = ref.read(offlineMemoryQueueServiceProvider);
    final previewStore = ref.read(localMemoryPreviewStoreProvider);

    // Track delete action
    analytics.trackMemoryDetailDelete(memory.id);

    // Capture navigator and scaffold messenger before async operation
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final canPop = navigator.canPop();

    try {
      // For offline queued memories, memory.id is the localId
      final localId = memory.id;
      debugPrint(
          '[MemoryDetailScreen] Deleting offline queued memory with localId: $localId');

      // Get the queued memory to check for serverId before removing
      final queuedMemory = await queueService.getByLocalId(localId);
      final serverMemoryId = queuedMemory?.serverMemoryId;

      // Remove from unified queue (handles all memory types)
      // This emits a QueueChangeType.removed event that will update the feed
      await queueService.remove(localId);

      // Also purge matching preview index entries by serverId to prevent ghost cards
      // This prevents the preview index from re-adding the deleted memory when _fetchPage runs
      if (serverMemoryId != null) {
        debugPrint(
            '[MemoryDetailScreen] Purging preview index entry for serverId: $serverMemoryId');
        await previewStore.removePreviewByServerId(serverMemoryId);
      }

      // Also directly remove from unified feed as a backup to ensure immediate removal
      // This prevents ghost cards if the queue-change event is delayed or missed
      final unifiedFeedController = ref.read(unifiedFeedProvider.notifier);
      unifiedFeedController.removeMemory(localId);
      debugPrint(
          '[MemoryDetailScreen] Removed memory $localId from unified feed and preview index');

      final deleteMessage = memory.memoryType == 'story'
          ? 'Story deleted'
          : memory.memoryType == 'memento'
              ? 'Memento deleted'
              : 'Moment deleted';

      // Switch to timeline tab
      ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();

      // Pop detail screen
      if (canPop) {
        navigator.pop();
      }

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(deleteMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint(
          '[MemoryDetailScreen] Error deleting offline queued memory: $e');
      // Handle error
      if (!context.mounted) return;

      final errorMessage = memory.memoryType == 'story'
          ? 'Failed to delete story. Please try again.'
          : memory.memoryType == 'memento'
              ? 'Failed to delete memento. Please try again.'
              : 'Failed to delete memory. Please try again.';

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle delete action with optimistic UI removal
  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) async {
    final analytics = ref.read(timelineAnalyticsServiceProvider);
    final notifier =
        ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);
    final isStory = memory.memoryType == 'story';

    // Track delete action
    analytics.trackMemoryDetailDelete(memory.id);

    // Capture navigator and scaffold messenger before async operation
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final canPop = navigator.canPop();

    try {
      // Also remove any queued entries with matching serverId
      // This handles the case where a synced memory still has a queued entry
      final queueService = ref.read(offlineMemoryQueueServiceProvider);
      final queuedMemories = await queueService.getAllQueued();
      for (final queued in queuedMemories) {
        if (queued.serverMemoryId == memory.id) {
          await queueService.remove(queued.localId);
        }
      }

      // Delete from backend
      final success = await notifier.deleteMemory();

      debugPrint('[MemoryDetailScreen] Delete result: success=$success');

      if (success) {
        debugPrint(
            '[MemoryDetailScreen] Deletion succeeded, navigating to timeline');
        final deleteMessage = isStory
            ? 'Story deleted'
            : memory.memoryType == 'memento'
                ? 'Memento deleted'
                : 'Moment deleted';

        // Emit deleted event so timeline can remove the memory
        final bus = ref.read(memoryTimelineUpdateBusProvider);
        bus.emitDeleted(memory.id);

        // Switch to timeline tab (doesn't need context)
        ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();
        debugPrint('[MemoryDetailScreen] Switched to timeline tab');

        // Pop detail screen using captured navigator
        if (canPop) {
          navigator.pop();
          debugPrint('[MemoryDetailScreen] Popped detail screen');
        } else {
          debugPrint('[MemoryDetailScreen] Cannot pop - no route to pop');
        }

        // Show success message using captured scaffold messenger
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(deleteMessage),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('[MemoryDetailScreen] Deletion failed, success=false');
        // Delete failed - memory should still be in feed

        if (context.mounted) {
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
        // Memory might have been deleted despite the error - emit deleted event
        debugPrint(
            '[MemoryDetailScreen] Error suggests memory was deleted, emitting deleted event');
        final bus = ref.read(memoryTimelineUpdateBusProvider);
        bus.emitDeleted(memory.id);

        // Navigate away
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Navigate to timeline screen
        ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();
      } else {
        // Delete failed - memory should still be in feed

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

  /// Build title widget - editable when edit icon is tapped
  Widget _buildTitleWidget(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) {
    final theme = Theme.of(context);

    // If editing, show TextField with save/cancel buttons
    if (_isEditingTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLength: 200,
            autofocus: true,
            onSubmitted: (value) {
              _handleSaveTitle(context, ref, memory, value);
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _handleCancelTitleEdit(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _handleSaveTitle(
                  context,
                  ref,
                  memory,
                  _titleController.text,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      );
    }

    // If not editing, show title with edit icon button right next to it
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MemoryTitleWithProcessing.detail(
            memory: memory,
            isOfflineQueued: widget.isOfflineQueued,
            offlineSyncStatus: widget.isOfflineQueued
                ? OfflineSyncStatus.queued
                : OfflineSyncStatus.synced,
            serverIdOverride: widget.isOfflineQueued ? null : memory.id,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Edit title',
          button: true,
          child: InkWell(
            onTap: () => _handleEditTitle(context, ref, memory),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.edit,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Handle title editing - enter edit mode
  Future<void> _handleEditTitle(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
  ) async {
    // Check if online (required for editing)
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    if (!isOnline) {
      _showOfflineTooltip(
          context, 'Editing title requires internet connection');
      return;
    }

    // Enter edit mode
    setState(() {
      _isEditingTitle = true;
      // Initialize with current title (not displayTitle, as we want to edit the actual title field)
      // If title is empty, use empty string (will fall back to generated_title or "Untitled..." after save)
      _titleController.text = memory.title;
    });
  }

  /// Handle saving title edit
  Future<void> _handleSaveTitle(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
    String newTitle,
  ) async {
    // Trim the title
    final trimmedTitle = newTitle.trim();

    // Show loading indicator
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Updating title...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Update via provider
      final notifier =
          ref.read(memoryDetailNotifierProvider(memory.id).notifier);
      // Pass null if empty, otherwise pass trimmed title
      await notifier.updateMemoryTitle(
        trimmedTitle.isEmpty ? null : trimmedTitle,
      );

      // Exit edit mode
      setState(() {
        _isEditingTitle = false;
      });

      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Title updated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update title: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle canceling title edit
  void _handleCancelTitleEdit() {
    setState(() {
      _isEditingTitle = false;
      _titleController.clear();
    });
  }

  /// Handle media removal with confirmation dialog
  Future<void> _handleMediaRemoval(
    BuildContext context,
    WidgetRef ref,
    MemoryDetail memory,
    String mediaUrl,
    bool isPhoto,
  ) async {
    // Check if online (required for media removal)
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    if (!isOnline) {
      _showOfflineTooltip(
          context, 'Removing media requires internet connection');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${isPhoto ? 'Photo' : 'Video'}?'),
        content: Text(
          'Are you sure you want to remove this ${isPhoto ? 'photo' : 'video'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Removing media...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Remove media via provider
      final notifier =
          ref.read(memoryDetailNotifierProvider(memory.id).notifier);
      await notifier.removeMedia(mediaUrl, isPhoto);

      // Update selected index if needed (if we removed the selected media)
      final totalMedia = memory.photos.length + memory.videos.length;
      if (_selectedMediaIndex != null &&
          _selectedMediaIndex! >= totalMedia - 1) {
        // If we removed the last item or beyond, adjust selection
        setState(() {
          final newTotal = totalMedia - 1;
          _selectedMediaIndex = newTotal > 0 ? newTotal - 1 : null;
        });
      }

      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${isPhoto ? 'Photo' : 'Video'} removed'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to remove media: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Widget that fetches signed audio URL and passes it to StickyAudioPlayer
class _StoryAudioPlayer extends ConsumerWidget {
  final String? audioPath;
  final double? audioDuration;
  final String storyId;
  final ValueChanged<double>? onHeightChanged;

  const _StoryAudioPlayer({
    required this.audioPath,
    this.audioDuration,
    required this.storyId,
    this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Debug logging to diagnose audio playback issues
    developer.log(
      '[MemoryDetailScreen._StoryAudioPlayer] Building audio player '
      'storyId=$storyId audioPath=$audioPath audioDuration=$audioDuration',
      name: 'MemoryDetailScreen',
    );

    // If no audio path, show placeholder
    if (audioPath == null || audioPath!.isEmpty) {
      developer.log(
        '[MemoryDetailScreen._StoryAudioPlayer] No audio path - showing placeholder',
        name: 'MemoryDetailScreen',
      );
      return StickyAudioPlayer(
        audioUrl: null,
        duration: audioDuration,
        storyId: storyId,
        onHeightChanged: onHeightChanged,
      );
    }

    // Check if this is a local file path (for offline queued items)
    if (audioPath!.startsWith('file://')) {
      // For local files, pass the path directly
      return StickyAudioPlayer(
        audioUrl: audioPath,
        duration: audioDuration,
        storyId: storyId,
        onHeightChanged: onHeightChanged,
      );
    }

    // Fetch signed URL for remote Supabase Storage audio
    final supabaseUrl = ref.read(supabaseUrlProvider);
    final supabaseAnonKey = ref.read(supabaseAnonKeyProvider);
    final supabaseClient = ref.read(supabaseClientProvider);
    final imageCache = ref.read(timelineImageCacheServiceProvider);
    final accessToken = supabaseClient.auth.currentSession?.accessToken;

    developer.log(
      '[MemoryDetailScreen._StoryAudioPlayer] Fetching signed URL for '
      'bucket=stories-audio path=$audioPath',
      name: 'MemoryDetailScreen',
    );

    return FutureBuilder<String>(
      future: imageCache.getSignedUrlForDetailView(
        supabaseUrl,
        supabaseAnonKey,
        'stories-audio',
        audioPath!,
        accessToken: accessToken,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // If error fetching signed URL, show placeholder
          developer.log(
            '[MemoryDetailScreen._StoryAudioPlayer] Error fetching audio signed URL '
            'storyId=$storyId path=$audioPath error=${snapshot.error}',
            name: 'MemoryDetailScreen',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return StickyAudioPlayer(
            audioUrl: null,
            duration: audioDuration,
            storyId: storyId,
            onHeightChanged: onHeightChanged,
          );
        }

        if (!snapshot.hasData) {
          // Loading state - show placeholder while fetching URL
          developer.log(
            '[MemoryDetailScreen._StoryAudioPlayer] Still loading signed URL...',
            name: 'MemoryDetailScreen',
          );
          return StickyAudioPlayer(
            audioUrl: null,
            duration: audioDuration,
            storyId: storyId,
            onHeightChanged: onHeightChanged,
          );
        }

        // Success - pass signed URL to player
        developer.log(
          '[MemoryDetailScreen._StoryAudioPlayer] Successfully fetched signed URL, '
          'passing to StickyAudioPlayer',
          name: 'MemoryDetailScreen',
        );
        return StickyAudioPlayer(
          audioUrl: snapshot.data,
          duration: audioDuration,
          storyId: storyId,
          onHeightChanged: onHeightChanged,
        );
      },
    );
  }
}

class _StoryAudioPlayerSliver extends ConsumerStatefulWidget {
  final String? audioPath;
  final double? audioDuration;
  final String storyId;

  const _StoryAudioPlayerSliver({
    required this.audioPath,
    required this.audioDuration,
    required this.storyId,
  });

  @override
  ConsumerState<_StoryAudioPlayerSliver> createState() =>
      _StoryAudioPlayerSliverState();
}

class _StoryAudioPlayerSliverState
    extends ConsumerState<_StoryAudioPlayerSliver> {
  static const double _minHeight = 80.0;
  static const double _maxHeight = 200.0;

  double _currentHeight = _minHeight;

  void _handleHeightChanged(double height) {
    final clampedHeight = height.isFinite && height > 0
        ? height.clamp(_minHeight, _maxHeight)
        : _minHeight;
    if ((clampedHeight - _currentHeight).abs() > 0.5) {
      setState(() {
        _currentHeight = clampedHeight.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyAudioPlayerDelegate(
        height: _currentHeight,
        child: _StoryAudioPlayer(
          audioPath: widget.audioPath,
          audioDuration: widget.audioDuration,
          storyId: widget.storyId,
          onHeightChanged: _handleHeightChanged,
        ),
      ),
    );
  }
}

/// Delegate for sticky audio player header
class _StickyAudioPlayerDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyAudioPlayerDelegate({required this.child, required this.height});

  // Height matches the measured player height to keep layoutExtent == paintExtent.
  // The player reports its intrinsic size (placeholder ~60px, error state ~120px),
  // which allows the pinned header to avoid overlapping the story text.
  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The child (StickyAudioPlayer) already has its own padding and styling
    // We just need to constrain the height and provide a background
    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyAudioPlayerDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

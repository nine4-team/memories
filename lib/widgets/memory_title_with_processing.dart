import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/memory_processing_status.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/providers/memory_processing_status_provider.dart';
import 'package:memories/providers/memory_timeline_update_bus_provider.dart';

/// Widget that displays a memory title with processing/offline indicators.
///
/// Shared between timeline preview cards and the memory detail screen so the
/// title area feels consistent everywhere.
class MemoryTitleWithProcessing extends ConsumerStatefulWidget {
  final MemoryTitleDescriptor descriptor;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool emitTimelineUpdateOnComplete;

  MemoryTitleWithProcessing.timeline({
    super.key,
    required TimelineMemory memory,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.emitTimelineUpdateOnComplete = true,
  }) : descriptor = MemoryTitleDescriptor.fromTimelineMemory(memory);

  MemoryTitleWithProcessing.detail({
    super.key,
    required MemoryDetail memory,
    bool isOfflineQueued = false,
    OfflineSyncStatus offlineSyncStatus = OfflineSyncStatus.synced,
    String? serverIdOverride,
    this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  })  : descriptor = MemoryTitleDescriptor.fromMemoryDetail(
          memory,
          isOfflineQueued: isOfflineQueued,
          offlineSyncStatus: offlineSyncStatus,
          serverIdOverride: serverIdOverride,
        ),
        emitTimelineUpdateOnComplete = false;

  @override
  ConsumerState<MemoryTitleWithProcessing> createState() =>
      _MemoryTitleWithProcessingState();
}

class _MemoryTitleWithProcessingState
    extends ConsumerState<MemoryTitleWithProcessing> {
  @override
  Widget build(BuildContext context) {
    final descriptor = widget.descriptor;

    if (descriptor.shouldShowOfflineIndicator) {
      return _buildOfflineSyncIndicator(context, descriptor.offlineSyncStatus);
    }

    final serverId = descriptor.serverId;
    if (serverId == null || serverId.isEmpty) {
      return _buildTitleText(context, descriptor.displayTitle);
    }

    final provider = memoryProcessingStatusStreamProvider(serverId);

    ref.listen<AsyncValue<MemoryProcessingStatus?>>(
      provider,
      (previous, next) {
        final prevState = previous?.maybeWhen(
          data: (status) => status?.state,
          orElse: () => null,
        );
        final nextState = next.maybeWhen(
          data: (status) => status?.state,
          orElse: () => null,
        );

        if (widget.emitTimelineUpdateOnComplete &&
            prevState != MemoryProcessingState.complete &&
            nextState == MemoryProcessingState.complete) {
          ref.read(memoryTimelineUpdateBusProvider).emitUpdated(serverId);
        }
      },
    );

    final statusAsync = ref.watch(provider);

    return statusAsync.when(
      data: (status) => _buildServerBackedTitle(context, descriptor, status),
      loading: () => _buildTitleText(context, descriptor.displayTitle),
      error: (_, __) => _buildTitleText(context, descriptor.displayTitle),
    );
  }

  Widget _buildOfflineSyncIndicator(
    BuildContext context,
    OfflineSyncStatus status,
  ) {
    String label;
    Color color;

    switch (status) {
      case OfflineSyncStatus.queued:
        label = 'Pending sync';
        color = Colors.orange.shade800;
        break;
      case OfflineSyncStatus.syncing:
        label = 'Syncing…';
        color = Colors.blue.shade800;
        break;
      case OfflineSyncStatus.failed:
        label = 'Sync failed';
        color = Colors.red.shade800;
        break;
      case OfflineSyncStatus.synced:
        // Synced – fall through to regular title rendering.
        return _buildTitleText(context, widget.descriptor.displayTitle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: (widget.style ?? Theme.of(context).textTheme.titleMedium)
                ?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          ),
        ),
      ],
    );
  }

  Widget _buildServerBackedTitle(
    BuildContext context,
    MemoryTitleDescriptor descriptor,
    MemoryProcessingStatus? status,
  ) {
    final isProcessing = status != null &&
        (status.state == MemoryProcessingState.scheduled ||
            status.state == MemoryProcessingState.processing);
    final shouldShowSpinner = isProcessing && !descriptor.hasGeneratedTitle;

    if (shouldShowSpinner) {
      return _buildProcessingIndicator(context);
    }

    return _buildTitleText(context, descriptor.displayTitle);
  }

  Widget _buildProcessingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Generating title…',
            style: (widget.style ?? Theme.of(context).textTheme.titleMedium)
                ?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleText(BuildContext context, String title) {
    return Text(
      title,
      style: widget.style ??
          Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

class MemoryTitleDescriptor {
  final String rawTitle;
  final String displayTitle;
  final String? serverId;
  final bool isOfflineQueued;
  final bool hasGeneratedTitle;
  final OfflineSyncStatus offlineSyncStatus;

  const MemoryTitleDescriptor({
    required this.rawTitle,
    required this.displayTitle,
    required this.serverId,
    required this.isOfflineQueued,
    required this.offlineSyncStatus,
    this.hasGeneratedTitle = false,
  });

  factory MemoryTitleDescriptor.fromTimelineMemory(TimelineMemory memory) {
    return MemoryTitleDescriptor(
      rawTitle: memory.title,
      displayTitle: memory.displayTitle,
      serverId: memory.serverId,
      isOfflineQueued: memory.isOfflineQueued,
      offlineSyncStatus: memory.offlineSyncStatus,
      hasGeneratedTitle: memory.hasGeneratedTitle,
    );
  }

  factory MemoryTitleDescriptor.fromMemoryDetail(
    MemoryDetail memory, {
    bool isOfflineQueued = false,
    OfflineSyncStatus offlineSyncStatus = OfflineSyncStatus.synced,
    String? serverIdOverride,
  }) {
    return MemoryTitleDescriptor(
      rawTitle: memory.title,
      displayTitle: memory.displayTitle,
      serverId: serverIdOverride ?? memory.id,
      isOfflineQueued: isOfflineQueued,
      offlineSyncStatus: offlineSyncStatus,
      hasGeneratedTitle: memory.hasGeneratedTitle,
    );
  }

  bool get shouldShowOfflineIndicator =>
      isOfflineQueued && offlineSyncStatus != OfflineSyncStatus.synced;
}

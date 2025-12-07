import 'package:memories/models/queued_memory.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_detail.dart';

/// Adapter service that converts queued offline memories (QueuedMemory)
/// into TimelineMemory instances for the unified feed.
///
/// Key responsibilities:
/// - Mark entries as offline queued and locally detailed
/// - Use localId as the primary identifier until serverId is known
/// - Populate basic card fields (title/snippet, capturedAt, type)
/// - Avoid full-media caching logic: we only surface whatever local paths exist
class OfflineQueueToTimelineAdapter {
  /// Convert a QueuedMemory to a TimelineMemory
  ///
  /// Unified method that handles all memory types (moments, mementos, stories).
  /// For stories, considers audioPath as potential primary media.
  static TimelineMemory fromQueuedMemory(QueuedMemory queued) {
    // Map queue status to OfflineSyncStatus
    final offlineSyncStatus = _mapStatusToOfflineSyncStatus(queued.status);

    // Prefer curated title, fall back to a generated one from input text
    final title = (queued.title != null && queued.title!.trim().isNotEmpty)
        ? queued.title!.trim()
        : _generateTitleFromInputText(queued.inputText, queued.memoryType);
    final snippet = _generateSnippetFromInputText(queued.inputText);

    // Use memoryDate if available, otherwise fall back to capturedAt
    final effectiveDate =
        queued.memoryDate ?? queued.capturedAt ?? queued.createdAt;
    final year = effectiveDate.year;
    final season = _getSeason(effectiveDate.month);
    final month = effectiveDate.month;
    final day = effectiveDate.day;

    // Determine primary media if available
    PrimaryMedia? primaryMedia;
    if (queued.photoPaths.isNotEmpty) {
      primaryMedia = PrimaryMedia(
        type: 'photo',
        url: queued.photoPaths.first, // Local file path
        index: 0,
        source: MediaSource.localFile,
      );
    } else if (queued.videoPaths.isNotEmpty) {
      String? posterUrl;
      if (queued.videoPosterPaths.isNotEmpty &&
          queued.videoPosterPaths.first != null &&
          queued.videoPosterPaths.first!.isNotEmpty) {
        final rawPoster = queued.videoPosterPaths.first!;
        posterUrl =
            rawPoster.startsWith('file://') ? rawPoster : 'file://$rawPoster';
      }
      primaryMedia = PrimaryMedia(
        type: 'video',
        url: queued.videoPaths.first, // Local file path
        index: 0,
        source: MediaSource.localFile,
        posterUrl: posterUrl,
      );
    } else if (queued.memoryType == 'story' && queued.audioPath != null) {
      // For stories, audio can be considered primary media
      primaryMedia = PrimaryMedia(
        type:
            'video', // Use video type for audio (or create audio type if needed)
        url: queued.audioPath!,
        index: 0,
        source: MediaSource.localFile,
      );
    }

    return TimelineMemory(
      id: queued.localId, // Use localId as primary id
      userId: '', // Not available for queued items
      title: title,
      inputText: queued.inputText,
      processedText: null, // Not available for queued items (LLM hasn't run)
      generatedTitle: null, // Not available for queued items
      tags: List.from(queued.tags),
      memoryType: queued.memoryType,
      capturedAt: queued.capturedAt ?? queued.createdAt,
      createdAt: queued.createdAt,
      memoryDate: effectiveDate,
      year: year,
      season: season,
      month: month,
      day: day,
      primaryMedia: primaryMedia,
      snippetText: snippet,
      memoryLocationData: queued.memoryLocationData != null
          ? MemoryLocationData.fromJson(
              queued.memoryLocationData as Map<String, dynamic>,
            )
          : null,
      isOfflineQueued: true,
      isPreviewOnly: false,
      isDetailCachedLocally: true, // Queue has full detail
      localId: queued.localId,
      serverId: queued.serverMemoryId, // May be null if not yet synced
      offlineSyncStatus: offlineSyncStatus,
    );
  }

  /// Map queue status string to OfflineSyncStatus enum
  static OfflineSyncStatus _mapStatusToOfflineSyncStatus(String status) {
    switch (status.toLowerCase()) {
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

  /// Generate a title from input text
  static String _generateTitleFromInputText(
      String? inputText, String memoryType) {
    if (inputText != null && inputText.trim().isNotEmpty) {
      // Use first 60 characters of text
      final trimmed = inputText.trim();
      if (trimmed.length <= 60) {
        return trimmed;
      }
      return '${trimmed.substring(0, 60)}...';
    }
    // Fallback to untitled based on memory type
    switch (memoryType.toLowerCase()) {
      case 'story':
        return 'Untitled Story';
      case 'memento':
        return 'Untitled Memento';
      case 'moment':
      default:
        return 'Untitled Moment';
    }
  }

  /// Generate a snippet from input text
  static String? _generateSnippetFromInputText(String? inputText) {
    if (inputText == null || inputText.trim().isEmpty) {
      return null;
    }
    final trimmed = inputText.trim();
    if (trimmed.length <= 200) {
      return trimmed;
    }
    return '${trimmed.substring(0, 200)}...';
  }

  /// Get season from month
  static String _getSeason(int month) {
    switch (month) {
      case 12:
      case 1:
      case 2:
        return 'Winter';
      case 3:
      case 4:
      case 5:
        return 'Spring';
      case 6:
      case 7:
      case 8:
        return 'Summer';
      case 9:
      case 10:
      case 11:
        return 'Fall';
      default:
        return 'Unknown';
    }
  }
}

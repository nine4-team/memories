import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/timeline_memory.dart';

/// Adapter service that converts LocalMemoryPreview rows into TimelineMemory
/// entries suitable for rendering in the timeline when the app is offline.
///
/// Key responsibilities:
/// - Mark entries as preview-only when offline
/// - Ensure they appear in the correct order alongside queued offline memories
/// - Make it clear to the UI that full detail is not available offline in Phase 1
class PreviewIndexToTimelineAdapter {
  /// Convert a LocalMemoryPreview to a TimelineMemory
  static TimelineMemory fromPreview(LocalMemoryPreview preview) {
    // Extract date components from capturedAt
    final year = preview.capturedAt.year;
    final season = _getSeason(preview.capturedAt.month);
    final month = preview.capturedAt.month;
    final day = preview.capturedAt.day;

    return TimelineMemory(
      id: preview.serverId,
      userId: '', // Not available in preview
      title: preview.titleOrFirstLine,
      inputText: null, // Not available in preview
      processedText: null, // Not available in preview
      generatedTitle: null, // Not available in preview
      tags: const [], // Not available in preview
      memoryType: preview.memoryType.apiValue,
      capturedAt: preview.capturedAt,
      createdAt: preview.capturedAt, // Use capturedAt as fallback
      year: year,
      season: season,
      month: month,
      day: day,
      primaryMedia: null, // Not available in preview
      snippetText: preview.titleOrFirstLine, // Use title as snippet
      isOfflineQueued: false,
      isPreviewOnly: !preview.isDetailCachedLocally,
      isDetailCachedLocally: preview.isDetailCachedLocally,
      localId: null, // Preview entries don't have local IDs
      serverId: preview.serverId,
      offlineSyncStatus: OfflineSyncStatus.synced, // Preview entries are from synced memories
    );
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


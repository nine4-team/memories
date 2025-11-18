import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'queue_status_provider.g.dart';

/// Provider that watches queue status for UI display
/// 
/// Includes moments, mementos, and stories in the queue status.
/// Note: Mementos are stored in the same queue as moments (OfflineQueueService),
/// so they are included in the moment queue counts.
@riverpod
Future<QueueStatusData> queueStatus(QueueStatusRef ref) async {
  final momentQueueService = ref.watch(offlineQueueServiceProvider);
  final storyQueueService = ref.watch(offlineStoryQueueServiceProvider);
  
  // Get moment queue status
  final momentQueued = await momentQueueService.getByStatus('queued');
  final momentSyncing = await momentQueueService.getByStatus('syncing');
  final momentFailed = await momentQueueService.getByStatus('failed');
  
  // Get story queue status
  final storyQueued = await storyQueueService.getByStatus('queued');
  final storySyncing = await storyQueueService.getByStatus('syncing');
  final storyFailed = await storyQueueService.getByStatus('failed');
  
  // Combine counts
  final queuedCount = momentQueued.length + storyQueued.length;
  final syncingCount = momentSyncing.length + storySyncing.length;
  final failedCount = momentFailed.length + storyFailed.length;
  
  return QueueStatusData(
    queuedCount: queuedCount,
    syncingCount: syncingCount,
    failedCount: failedCount,
    totalCount: queuedCount + syncingCount + failedCount,
  );
}

/// Data class for queue status
class QueueStatusData {
  final int queuedCount;
  final int syncingCount;
  final int failedCount;
  final int totalCount;

  const QueueStatusData({
    required this.queuedCount,
    required this.syncingCount,
    required this.failedCount,
    required this.totalCount,
  });

  bool get hasItems => totalCount > 0;
  bool get hasQueued => queuedCount > 0;
  bool get hasSyncing => syncingCount > 0;
  bool get hasFailed => failedCount > 0;
  
  /// Get the primary status to display
  String get primaryStatus {
    if (hasFailed) return 'Needs Attention';
    if (hasSyncing) return 'Syncing';
    if (hasQueued) return 'Queued';
    return '';
  }
}


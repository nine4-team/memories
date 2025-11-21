import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'queue_status_provider.g.dart';

/// Provider that watches queue status for UI display
/// 
/// Includes moments, mementos, and stories in the queue status.
/// All memory types are stored in the unified OfflineMemoryQueueService.
@riverpod
Future<QueueStatusData> queueStatus(QueueStatusRef ref) async {
  final queueService = ref.watch(offlineMemoryQueueServiceProvider);
  
  // Get queue status for all memory types
  final queued = await queueService.getByStatus('queued');
  final syncing = await queueService.getByStatus('syncing');
  final failed = await queueService.getByStatus('failed');
  
  return QueueStatusData(
    queuedCount: queued.length,
    syncingCount: syncing.length,
    failedCount: failed.length,
    totalCount: queued.length + syncing.length + failed.length,
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


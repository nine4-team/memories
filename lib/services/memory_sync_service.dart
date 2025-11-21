import 'dart:async';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_sync_service.g.dart';

/// Event emitted when a queued memory successfully syncs to the server
class SyncCompleteEvent {
  final String localId;
  final String serverId;
  final MemoryType memoryType;

  SyncCompleteEvent({
    required this.localId,
    required this.serverId,
    required this.memoryType,
  });
}

/// Service for syncing queued memories (moments, mementos, and stories) to the server
/// 
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the unified offline memory queue.
@riverpod
MemorySyncService memorySyncService(MemorySyncServiceRef ref) {
  final queueService = ref.watch(offlineMemoryQueueServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final saveService = ref.watch(memorySaveServiceProvider);
  
  return MemorySyncService(
    queueService,
    connectivityService,
    saveService,
  );
}

class MemorySyncService {
  final OfflineMemoryQueueService _queueService;
  final ConnectivityService _connectivityService;
  final MemorySaveService _saveService;
  
  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  final _syncCompleteController = StreamController<SyncCompleteEvent>.broadcast();

  MemorySyncService(
    this._queueService,
    this._connectivityService,
    this._saveService,
  );

  /// Stream of sync completion events
  Stream<SyncCompleteEvent> get syncCompleteStream =>
      _syncCompleteController.stream;

  /// Start automatic sync when connectivity is restored
  void startAutoSync() {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (isOnline) {
        if (isOnline && !_isSyncing) {
          syncQueuedMemories();
        }
      },
    );

    // Also sync periodically (every 30 seconds) when online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isSyncing) {
        _connectivityService.isOnline().then((isOnline) {
          if (isOnline) {
            syncQueuedMemories();
          }
        });
      }
    });
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopAutoSync();
    _syncCompleteController.close();
  }

  /// Manually trigger sync of all queued memories (moments, mementos, and stories)
  Future<void> syncQueuedMemories() async {
    if (_isSyncing) return;
    
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) return;

    _isSyncing = true;
    
    try {
      await _syncQueuedMemories();
    } finally {
      _isSyncing = false;
    }
  }

  /// Unified sync method for all queued memories
  /// 
  /// Handles moments, mementos, and stories from the unified queue.
  Future<void> _syncQueuedMemories() async {
    // Get all queued items
    final queued = await _queueService.getByStatus('queued');
    final failed = await _queueService.getByStatus('failed');

    // Process queued items first, then retry failed ones
    final memoriesToSync = [...queued, ...failed];

    for (final queuedMemory in memoriesToSync) {
      try {
        // Update status to syncing
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'syncing',
            lastRetryAt: DateTime.now(),
          ),
        );

        // Convert to CaptureState and save
        final state = queuedMemory.toCaptureState();
        final result = await _saveService.saveMemory(state: state);

        // Mark as completed and remove from queue
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'completed',
            serverMemoryId: result.memoryId,
          ),
        );

        // Emit sync completion event
        final memoryType = MemoryTypeExtension.fromApiValue(queuedMemory.memoryType);
        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: queuedMemory.localId,
            serverId: result.memoryId,
            memoryType: memoryType,
          ),
        );

        // Remove from queue after successful sync
        await _queueService.remove(queuedMemory.localId);
      } catch (e) {
        // Update retry count and mark as failed if max retries reached
        final newRetryCount = queuedMemory.retryCount + 1;
        final maxRetries = 3;

        if (newRetryCount >= maxRetries) {
          await _queueService.update(
            queuedMemory.copyWith(
              status: 'failed',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        } else {
          // Retry later with exponential backoff
          await _queueService.update(
            queuedMemory.copyWith(
              status: 'queued',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
              lastRetryAt: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  /// Sync a specific queued memory by local ID
  Future<void> syncMemory(String localId) async {
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw Exception('Device is offline');
    }

    final queuedMemory = await _queueService.getByLocalId(localId);
    if (queuedMemory == null) {
      throw Exception('Memory not found in queue: $localId');
    }

    try {
      await _queueService.update(
        queuedMemory.copyWith(
          status: 'syncing',
          lastRetryAt: DateTime.now(),
        ),
      );

      final state = queuedMemory.toCaptureState();
      final result = await _saveService.saveMemory(state: state);

      await _queueService.update(
        queuedMemory.copyWith(
          status: 'completed',
          serverMemoryId: result.memoryId,
        ),
      );

      // Emit sync completion event
      final memoryType = MemoryTypeExtension.fromApiValue(queuedMemory.memoryType);
      _syncCompleteController.add(
        SyncCompleteEvent(
          localId: queuedMemory.localId,
          serverId: result.memoryId,
          memoryType: memoryType,
        ),
      );

      await _queueService.remove(queuedMemory.localId);
    } catch (e) {
      final newRetryCount = queuedMemory.retryCount + 1;
      await _queueService.update(
        queuedMemory.copyWith(
          status: newRetryCount >= 3 ? 'failed' : 'queued',
          retryCount: newRetryCount,
          errorMessage: e.toString(),
          lastRetryAt: DateTime.now(),
        ),
      );
      rethrow;
    }
  }
}


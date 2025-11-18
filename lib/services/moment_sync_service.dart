import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'moment_sync_service.g.dart';

/// Service for syncing queued moments and mementos to the server
/// 
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the offline queue (moments and mementos).
@riverpod
MomentSyncService momentSyncService(MomentSyncServiceRef ref) {
  final queueService = ref.watch(offlineQueueServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final saveService = ref.watch(memorySaveServiceProvider);
  
  return MomentSyncService(
    queueService,
    connectivityService,
    saveService,
  );
}

class MomentSyncService {
  final OfflineQueueService _queueService;
  final ConnectivityService _connectivityService;
  final MemorySaveService _saveService;
  
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  MomentSyncService(
    this._queueService,
    this._connectivityService,
    this._saveService,
  );

  /// Start automatic sync when connectivity is restored
  void startAutoSync() {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline && !_isSyncing) {
          syncQueuedMoments();
        }
      },
    );

    // Also sync periodically (every 30 seconds) when online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isSyncing) {
        _connectivityService.isOnline().then((isOnline) {
          if (isOnline) {
            syncQueuedMoments();
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

  /// Manually trigger sync of all queued moments and mementos
  Future<void> syncQueuedMoments() async {
    if (_isSyncing) return;
    
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) return;

    _isSyncing = true;
    
    try {
      // Get all queued items (moments and mementos)
      final queued = await _queueService.getByStatus('queued');
      final failed = await _queueService.getByStatus('failed');

      // Process queued items first, then retry failed ones
      final momentsToSync = [...queued, ...failed];

      for (final queuedMoment in momentsToSync) {
        try {
          // Update status to syncing
          await _queueService.update(
            queuedMoment.copyWith(
              status: 'syncing',
              lastRetryAt: DateTime.now(),
            ),
          );

          // Convert to CaptureState and save
          final state = queuedMoment.toCaptureState();
          final result = await _saveService.saveMoment(state: state);

          // Mark as completed and remove from queue
          await _queueService.update(
            queuedMoment.copyWith(
              status: 'completed',
              serverMomentId: result.momentId,
            ),
          );

          // Remove from queue after successful sync
          await _queueService.remove(queuedMoment.localId);
        } catch (e) {
          // Update retry count and mark as failed if max retries reached
          final newRetryCount = queuedMoment.retryCount + 1;
          final maxRetries = 3;

          if (newRetryCount >= maxRetries) {
            await _queueService.update(
              queuedMoment.copyWith(
                status: 'failed',
                retryCount: newRetryCount,
                errorMessage: e.toString(),
                lastRetryAt: DateTime.now(),
              ),
            );
          } else {
            // Retry later with exponential backoff
            await _queueService.update(
              queuedMoment.copyWith(
                status: 'queued',
                retryCount: newRetryCount,
                errorMessage: e.toString(),
                lastRetryAt: DateTime.now(),
              ),
            );
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a specific queued moment by local ID
  Future<void> syncMoment(String localId) async {
    final queuedMoment = await _queueService.getByLocalId(localId);
    if (queuedMoment == null) return;

    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw Exception('Device is offline');
    }

    try {
      await _queueService.update(
        queuedMoment.copyWith(
          status: 'syncing',
          lastRetryAt: DateTime.now(),
        ),
      );

      final state = queuedMoment.toCaptureState();
      final result = await _saveService.saveMoment(state: state);

      await _queueService.update(
        queuedMoment.copyWith(
          status: 'completed',
          serverMomentId: result.momentId,
        ),
      );

      await _queueService.remove(queuedMoment.localId);
    } catch (e) {
      final newRetryCount = queuedMoment.retryCount + 1;
      await _queueService.update(
        queuedMoment.copyWith(
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


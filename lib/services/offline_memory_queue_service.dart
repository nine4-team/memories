import 'dart:async';
import 'dart:convert';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/models/queue_change_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

part 'offline_memory_queue_service.g.dart';

const String _queueKey = 'queued_memories';

/// Service for managing offline queue of all memory types (moments, mementos, and stories)
/// 
/// Unified service that replaces OfflineQueueService and OfflineStoryQueueService.
/// All memory types are stored in a single queue since they share the same save pipeline.
/// The memory type is tracked via the QueuedMemory.memoryType field.
@riverpod
OfflineMemoryQueueService offlineMemoryQueueService(OfflineMemoryQueueServiceRef ref) {
  return OfflineMemoryQueueService();
}

class OfflineMemoryQueueService {
  final _changeController = StreamController<QueueChangeEvent>.broadcast();
  
  /// Stream of queue change events
  Stream<QueueChangeEvent> get changeStream => _changeController.stream;
  
  /// Dispose resources
  void dispose() {
    _changeController.close();
  }

  /// Get all queued memories from storage
  Future<List<QueuedMemory>> _getAllMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_queueKey);
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => QueuedMemory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Handle corrupted JSON gracefully
      // Log error for debugging but don't crash
      return [];
    }
  }

  /// Save all memories to storage
  Future<void> _saveAllMemories(List<QueuedMemory> memories) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = memories.map((m) => m.toJson()).toList();
    await prefs.setString(_queueKey, jsonEncode(jsonList));
  }

  /// Add a memory to the queue
  /// 
  /// If a memory with the same localId already exists, it will be updated.
  Future<void> enqueue(QueuedMemory memory) async {
    final memories = await _getAllMemories();
    final isUpdate = memories.any((m) => m.localId == memory.localId);
    // Remove if already exists (update)
    memories.removeWhere((m) => m.localId == memory.localId);
    memories.add(memory);
    await _saveAllMemories(memories);
    
    // Emit change event
    _changeController.add(QueueChangeEvent(
      localId: memory.localId,
      memoryType: memory.memoryType,
      type: isUpdate ? QueueChangeType.updated : QueueChangeType.added,
    ));
  }

  /// Get all queued memories
  Future<List<QueuedMemory>> getAllQueued() async {
    return await _getAllMemories();
  }

  /// Get queued memories by status
  /// 
  /// Status values: 'queued', 'syncing', 'failed', 'completed'
  Future<List<QueuedMemory>> getByStatus(String status) async {
    final memories = await _getAllMemories();
    return memories.where((memory) => memory.status == status).toList();
  }

  /// Get a specific queued memory by local ID
  Future<QueuedMemory?> getByLocalId(String localId) async {
    final memories = await _getAllMemories();
    try {
      return memories.firstWhere((m) => m.localId == localId);
    } catch (e) {
      return null;
    }
  }

  /// Update a queued memory
  /// 
  /// This is equivalent to enqueue() for this implementation (emits updated event).
  Future<void> update(QueuedMemory memory) async {
    await enqueue(memory);
  }

  /// Remove a queued memory (after successful sync)
  Future<void> remove(String localId) async {
    final memories = await _getAllMemories();
    final memory = memories.firstWhere(
      (m) => m.localId == localId,
      orElse: () => throw StateError('Memory not found: $localId'),
    );
    final memoryType = memory.memoryType;
    memories.removeWhere((m) => m.localId == localId);
    await _saveAllMemories(memories);
    
    // Emit change event
    _changeController.add(QueueChangeEvent(
      localId: localId,
      memoryType: memoryType,
      type: QueueChangeType.removed,
    ));
  }

  /// Get count of queued memories
  Future<int> getCount() async {
    final memories = await _getAllMemories();
    return memories.length;
  }

  /// Get count by status
  /// 
  /// Status values: 'queued', 'syncing', 'failed', 'completed'
  Future<int> getCountByStatus(String status) async {
    final memories = await _getAllMemories();
    return memories.where((memory) => memory.status == status).length;
  }

  /// Generate a deterministic local ID
  /// 
  /// Uses UUID v4 for uniqueness across app restarts and upgrades.
  static String generateLocalId() {
    return const Uuid().v4();
  }
}


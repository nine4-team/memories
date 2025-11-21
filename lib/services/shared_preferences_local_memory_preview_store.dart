import 'dart:convert';
import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/local_memory_preview_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_preferences_local_memory_preview_store.g.dart';

const String _previewIndexKey = 'local_memory_preview_index';

/// SharedPreferences-based implementation of LocalMemoryPreviewStore
/// 
/// Stores preview entries in SharedPreferences as JSON, following the same
/// pattern as OfflineMemoryQueueService.
@riverpod
SharedPreferencesLocalMemoryPreviewStore localMemoryPreviewStore(
    LocalMemoryPreviewStoreRef ref) {
  return SharedPreferencesLocalMemoryPreviewStore();
}

class SharedPreferencesLocalMemoryPreviewStore
    implements LocalMemoryPreviewStore {
  /// Get all preview entries from storage
  Future<List<LocalMemoryPreview>> _getAllPreviews() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_previewIndexKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) =>
              LocalMemoryPreview.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Handle corrupted JSON gracefully
      return [];
    }
  }

  /// Save all preview entries to storage
  Future<void> _saveAllPreviews(List<LocalMemoryPreview> previews) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = previews.map((p) => p.toJson()).toList();
    await prefs.setString(_previewIndexKey, jsonEncode(jsonList));
  }

  @override
  Future<void> upsertPreviews(List<LocalMemoryPreview> previews) async {
    final existing = await _getAllPreviews();
    final existingMap = {
      for (var preview in existing) preview.serverId: preview
    };

    // Upsert: update existing or add new
    for (final preview in previews) {
      existingMap[preview.serverId] = preview;
    }

    await _saveAllPreviews(existingMap.values.toList());
  }

  @override
  Future<List<LocalMemoryPreview>> fetchPreviews({
    Set<MemoryType>? filters,
    int limit = 50,
  }) async {
    var previews = await _getAllPreviews();

    // Filter by memory type if specified
    if (filters != null && filters.isNotEmpty) {
      final filterSet = filters.map((t) => t.apiValue.toLowerCase()).toSet();
      previews = previews
          .where((p) => filterSet.contains(p.memoryType.apiValue.toLowerCase()))
          .toList();
    }

    // Sort by capturedAt descending (newest first)
    previews.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    // Apply limit
    if (previews.length > limit) {
      previews = previews.take(limit).toList();
    }

    return previews;
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_previewIndexKey);
  }
}


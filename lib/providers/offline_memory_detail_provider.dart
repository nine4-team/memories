import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/services/offline_memory_queue_service.dart';

part 'offline_memory_detail_provider.g.dart';

/// Provider for offline memory detail (queued items only)
///
/// [localId] is the local ID of the queued memory to fetch
/// This provider only works for queued offline memories stored in local queues.
/// It does not attempt to fetch remote details for preview-only entries.
@riverpod
class OfflineMemoryDetailNotifier extends _$OfflineMemoryDetailNotifier {
  @override
  Future<MemoryDetail> build(String localId) async {
    final queueService = ref.read(offlineMemoryQueueServiceProvider);

    // Find in unified queue
    final queuedMemory = await queueService.getByLocalId(localId);
    if (queuedMemory != null) {
      return _toDetailFromQueuedMemory(queuedMemory);
    }

    throw Exception('Offline queued memory not found: $localId');
  }

  /// Convert a QueuedMemory to MemoryDetail
  MemoryDetail _toDetailFromQueuedMemory(QueuedMemory queued) {
    final capturedAt = queued.capturedAt ?? queued.createdAt;

    // Convert photo paths to PhotoMedia
    final photos = queued.photoPaths.asMap().entries.where((entry) {
      // Filter out entries whose file no longer exists
      final path = entry.value.replaceFirst('file://', '');
      return File(path).existsSync();
    }).map((entry) {
      // Normalize path to file:// form for clarity
      final path = entry.value.replaceFirst('file://', '');
      final normalizedPath =
          path.startsWith('/') ? 'file://$path' : 'file:///$path';
      return PhotoMedia(
        url: normalizedPath,
        index: entry.key,
        caption: null,
        source: MediaSource.localFile,
      );
    }).toList();

    // Convert video paths to VideoMedia
    final videos = queued.videoPaths.asMap().entries.where((entry) {
      // Filter out entries whose file no longer exists
      final path = entry.value.replaceFirst('file://', '');
      return File(path).existsSync();
    }).map((entry) {
      // Normalize path to file:// form for clarity
      final path = entry.value.replaceFirst('file://', '');
      final normalizedPath =
          path.startsWith('/') ? 'file://$path' : 'file:///$path';
      return VideoMedia(
        url: normalizedPath,
        index: entry.key,
        duration: null,
        posterUrl: null,
        caption: null,
        source: MediaSource.localFile,
      );
    }).toList();

    // Create location data if available
    LocationData? locationData;
    if (queued.latitude != null && queued.longitude != null) {
      locationData = LocationData(
        latitude: queued.latitude,
        longitude: queued.longitude,
        status: queued.locationStatus,
        city: null, // Not available for queued items
        state: null, // Not available for queued items
      );
    }

    // Generate title from input text if needed
    final title =
        _generateTitleFromInputText(queued.inputText, queued.memoryType);

    // For stories, convert local audio path to file:// URL format
    String? audioPath;
    if (queued.memoryType == 'story' && queued.audioPath != null) {
      final path = queued.audioPath!.replaceFirst('file://', '');
      audioPath = path.startsWith('/') ? 'file://$path' : 'file:///$path';
    }

    return MemoryDetail(
      id: queued.localId,
      userId: '', // Not available for queued items until sync
      title: title,
      inputText: queued.inputText,
      processedText: null, // Not available for queued items (LLM hasn't run)
      generatedTitle: null, // Not available for queued items
      tags: List.from(queued.tags),
      memoryType: queued.memoryType,
      capturedAt: capturedAt,
      createdAt: queued.createdAt,
      updatedAt:
          queued.createdAt, // Use createdAt as updatedAt for queued items
      publicShareToken: null, // Not available for queued items
      locationData: locationData,
      photos: photos,
      videos: videos,
      relatedStories: [], // Not available for queued items
      relatedMementos: [], // Not available for queued items
      audioPath: audioPath,
      audioDuration: queued.audioDuration,
    );
  }

  /// Generate a title from input text
  /// Falls back to appropriate "Untitled" text based on memory type
  String _generateTitleFromInputText(String? inputText, String memoryType) {
    if (inputText != null && inputText.trim().isNotEmpty) {
      // Use first line or first 50 characters as title
      final lines = inputText.trim().split('\n');
      final firstLine = lines.first.trim();
      if (firstLine.isNotEmpty) {
        return firstLine.length > 50
            ? '${firstLine.substring(0, 50)}...'
            : firstLine;
      }
    }

    // Fallback to appropriate "Untitled" text
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
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_cache_service.g.dart';

/// Service for managing audio file cache and lifecycle
/// 
/// Handles:
/// - Storing audio files in a cache directory with durability guarantees
/// - Cleaning up temporary files on cancel/discard flows
/// - Reusing audio files when retries occur (no duplicate recordings)
/// - Managing file lifecycle to prevent storage leaks
@riverpod
AudioCacheService audioCacheService(AudioCacheServiceRef ref) {
  return AudioCacheService();
}

class AudioCacheService {
  /// Cache directory for audio files
  Directory? _cacheDir;
  
  /// Map of capture session IDs to audio file paths
  /// Used to track and reuse audio files for retries
  final Map<String, String> _sessionAudioPaths = {};
  
  /// Initialize cache directory
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) {
      return _cacheDir!;
    }
    
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/audio_cache');
    
    // Ensure directory exists
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    
    return _cacheDir!;
  }

  /// Store audio file from plugin-provided reference
  /// 
  /// [sourcePath] is the path provided by the dictation plugin
  /// [sessionId] is a unique identifier for this capture session (used for retries)
  /// [metadata] optional metadata (duration, locale, timestamp)
  /// 
  /// Returns the cached file path that should be used for queueing/upload
  /// 
  /// Throws [AudioCacheException] if storage fails
  Future<String> storeAudioFile({
    required String sourcePath,
    required String sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw AudioCacheException('Source audio file does not exist: $sourcePath');
      }

      final cacheDir = await _getCacheDir();
      
      // Generate deterministic filename based on session ID
      // This ensures retries reuse the same file (no duplicates)
      final fileName = '${sessionId}.m4a';
      final cachedPath = '${cacheDir.path}/$fileName';
      final cachedFile = File(cachedPath);

      // Copy source file to cache (or reuse if already exists)
      if (await cachedFile.exists()) {
        // File already exists for this session - reuse it (retry scenario)
        return cachedPath;
      }

      // Copy source file to cache
      await sourceFile.copy(cachedPath);
      
      // Store mapping for cleanup tracking
      _sessionAudioPaths[sessionId] = cachedPath;

      return cachedPath;
    } catch (e) {
      throw AudioCacheException('Failed to store audio file: $e');
    }
  }

  /// Get cached audio file path for a session
  /// 
  /// Returns null if no audio file exists for this session
  String? getAudioPath(String sessionId) {
    return _sessionAudioPaths[sessionId];
  }

  /// Check if audio file exists for a session
  Future<bool> hasAudioFile(String sessionId) async {
    final path = _sessionAudioPaths[sessionId];
    if (path == null) return false;
    
    final file = File(path);
    return await file.exists();
  }

  /// Clean up audio file for a session
  /// 
  /// Called when capture is cancelled or discarded
  /// [sessionId] is the capture session identifier
  /// [keepIfQueued] if true, keeps the file even if it's queued for upload
  Future<void> cleanupAudioFile({
    required String sessionId,
    bool keepIfQueued = false,
  }) async {
    final path = _sessionAudioPaths[sessionId];
    if (path == null) return;

    // If keepIfQueued is true, don't delete (file is needed for sync)
    if (keepIfQueued) {
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from tracking map
      _sessionAudioPaths.remove(sessionId);
    } catch (e) {
      // Log error but don't throw - cleanup failures shouldn't break the app
      // In production, you might want to log this to analytics
    }
  }

  /// Clean up all temporary audio files
  /// 
  /// Removes all cached audio files that aren't actively being used
  /// Useful for periodic cleanup or app shutdown
  Future<void> cleanupAllTemporaryFiles() async {
    try {
      final cacheDir = await _getCacheDir();
      if (!await cacheDir.exists()) return;

      final files = cacheDir.listSync();
      final activePaths = _sessionAudioPaths.values.toSet();

      for (final entity in files) {
        if (entity is File) {
          final path = entity.path;
          // Only delete files that aren't actively tracked
          if (!activePaths.contains(path)) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignore individual file deletion errors
            }
          }
        }
      }
    } catch (e) {
      // Log error but don't throw
    }
  }

  /// Clear all session tracking (but don't delete files)
  /// 
  /// Useful when resetting state without deleting cached files
  void clearSessionTracking() {
    _sessionAudioPaths.clear();
  }

  /// Get cache directory path (for debugging/monitoring)
  Future<String> getCacheDirectoryPath() async {
    final cacheDir = await _getCacheDir();
    return cacheDir.path;
  }

  /// Get total size of cached audio files (in bytes)
  /// 
  /// Useful for monitoring cache size
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDir();
      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      final files = cacheDir.listSync();
      
      for (final entity in files) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // Ignore errors reading file size
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}

/// Exception thrown by AudioCacheService
class AudioCacheException implements Exception {
  final String message;
  AudioCacheException(this.message);
  
  @override
  String toString() => 'AudioCacheException: $message';
}


import 'dart:io';
import 'dart:async';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'memory_save_service.g.dart';

/// Result of saving a memory
class MemorySaveResult {
  final String memoryId;
  final String? generatedTitle;
  final DateTime? titleGeneratedAt;
  final List<String> photoUrls;
  final List<String> videoUrls;
  final bool hasLocation;

  MemorySaveResult({
    required this.memoryId,
    this.generatedTitle,
    this.titleGeneratedAt,
    required this.photoUrls,
    required this.videoUrls,
    required this.hasLocation,
  });
}

/// Progress callback for save operations
typedef SaveProgressCallback = void Function({
  String? message,
  double? progress,
});

/// Service for saving memories to Supabase
@riverpod
MemorySaveService memorySaveService(MemorySaveServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final offlineMemoryQueueService = ref.watch(offlineMemoryQueueServiceProvider);
  return MemorySaveService(
    supabase,
    connectivityService,
    offlineMemoryQueueService,
  );
}

class MemorySaveService {
  final SupabaseClient _supabase;
  final ConnectivityService _connectivityService;
  final OfflineMemoryQueueService _offlineMemoryQueueService;
  static const String _photosBucket = 'memories-photos';
  static const String _videosBucket = 'memories-videos';
  static const int _maxRetries = 3;
  static const Duration _uploadTimeout = Duration(seconds: 30);

  MemorySaveService(
    this._supabase,
    this._connectivityService,
    this._offlineMemoryQueueService,
  );

  /// Save a memory with all its metadata
  ///
  /// This method:
  /// 1. Checks connectivity - queues if offline
  /// 2. Uploads photos and videos to Supabase Storage (with retry logic)
  /// 3. Creates the memory record in the database
  /// 4. Optionally generates a title if transcript is available
  ///
  /// Returns the saved memory ID and generated title (if any)
  /// Throws OfflineException if offline (caller should handle queueing)
  Future<MemorySaveResult> saveMemory({
    required CaptureState state,
    SaveProgressCallback? onProgress,
  }) async {
    // Check connectivity first
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw OfflineException(
          'Device is offline. Memory will be queued for sync.');
    }

    try {
      // Step 1: Upload media files
      onProgress?.call(message: 'Uploading media...', progress: 0.1);
      final photoUrls = <String>[];
      final videoUrls = <String>[];

      // Upload photos with retry logic
      for (int i = 0; i < state.photoPaths.length; i++) {
        final photoPath = state.photoPaths[i];
        final file = File(photoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;

        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage
                .from(_photosBucket)
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: false,
                    contentType: 'image/jpeg',
                  ),
                )
                .timeout(_uploadTimeout);

            publicUrl =
                _supabase.storage.from(_photosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              // Exponential backoff: 1s, 2s, 4s
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message:
                    'Retrying photo upload... (${i + 1}/${state.photoPaths.length})',
                progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception(
              'Failed to upload photo after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        photoUrls.add(publicUrl);

        onProgress?.call(
          message: 'Uploading photos... (${i + 1}/${state.photoPaths.length})',
          progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
        );
      }

      // Upload videos with retry logic
      for (int i = 0; i < state.videoPaths.length; i++) {
        final videoPath = state.videoPaths[i];
        final file = File(videoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;

        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage
                .from(_videosBucket)
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: false,
                    contentType: 'video/mp4',
                  ),
                )
                .timeout(_uploadTimeout);

            publicUrl =
                _supabase.storage.from(_videosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              // Exponential backoff: 1s, 2s, 4s
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message:
                    'Retrying video upload... (${i + 1}/${state.videoPaths.length})',
                progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception(
              'Failed to upload video after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        videoUrls.add(publicUrl);

        onProgress?.call(
          message: 'Uploading videos... (${i + 1}/${state.videoPaths.length})',
          progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
        );
      }

      // Step 2: Prepare location data
      String? locationWkt;
      if (state.latitude != null && state.longitude != null) {
        // Format as PostGIS Point WKT: POINT(longitude latitude)
        locationWkt = 'POINT(${state.longitude} ${state.latitude})';
      }

      // Step 3: Create memory record
      onProgress?.call(message: 'Saving memory...', progress: 0.7);
      final now = DateTime.now().toUtc();

      final momentData = {
        'user_id': _supabase.auth.currentUser?.id,
        'title': null, // Will be updated after title generation (now nullable)
        'input_text': state.inputText, // Canonical raw user text
        'processed_text':
            null, // LLM-processed text - stays NULL until processing completes
        'photo_urls': photoUrls,
        'video_urls': videoUrls,
        'tags': state.tags,
        'memory_type': state.memoryType.apiValue,
        'location_status': state.locationStatus,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'metadata_version': 1, // Current metadata schema version
      };

      // Add device_timestamp if capture started (when first asset or transcript began)
      if (state.captureStartTime != null) {
        momentData['device_timestamp'] =
            state.captureStartTime!.toUtc().toIso8601String();
      }

      // Add memory_date (required - use user-specified or fall back to now)
      final memoryDate = state.memoryDate ?? now;
      momentData['memory_date'] = memoryDate.toUtc().toIso8601String();

      // Add location if available (PostGIS geography format)
      if (locationWkt != null) {
        momentData['captured_location'] = locationWkt;
      }

      final response = await _supabase
          .from('memories')
          .insert(momentData)
          .select('id')
          .single();

      final memoryId = response['id'] as String;

      // Step 3.5: Create story_fields row if this is a story
      if (state.memoryType == MemoryType.story) {
        // Upload audio if available
        String? audioPath;
        if (state.audioPath != null) {
          try {
            final audioFile = File(state.audioPath!);
            if (await audioFile.exists()) {
              final audioFileName =
                  '${DateTime.now().millisecondsSinceEpoch}.m4a';
              final audioStoragePath =
                  'stories/audio/${_supabase.auth.currentUser?.id}/$memoryId/$audioFileName';

              await _supabase.storage.from('stories-audio').upload(
                    audioStoragePath,
                    audioFile,
                    fileOptions: const FileOptions(
                      upsert: false,
                      contentType: 'audio/m4a',
                    ),
                  );

              audioPath = audioStoragePath;
            }
          } catch (e) {
            // Audio upload failed, but continue with story creation
            // The story_fields row will be created without audio_path
          }
        }

        // Create story_fields row (no processing status here - handled by memory_processing_status)
        await _supabase.from('story_fields').insert({
          'memory_id': memoryId,
          'audio_path': audioPath,
        });
      }

      // Step 4: Insert memory_processing_status row if we have input_text to process
      // Processing will happen asynchronously via dispatcher
      final hasInputText = state.inputText?.trim().isNotEmpty == true;
      String? generatedTitle;

      if (hasInputText) {
        // Insert processing status row - dispatcher will pick this up
        try {
          await _supabase.from('memory_processing_status').insert({
            'memory_id': memoryId,
            'state': 'scheduled',
            'attempts': 0,
            'metadata': {
              'memory_type': state.memoryType.apiValue,
            },
          });
        } catch (e) {
          // Log but don't fail - processing status insert is best-effort
          // The dispatcher can still process the memory
          print('Warning: Failed to insert memory_processing_status: $e');
        }
      }

      // Use fallback title for now - will be updated when processing completes
      generatedTitle = _getFallbackTitle(state.memoryType);

      // Set fallback title immediately
      await _supabase.from('memories').update({
        'title': generatedTitle,
      }).eq('id', memoryId);

      onProgress?.call(message: 'Complete!', progress: 1.0);

      return MemorySaveResult(
        memoryId: memoryId,
        generatedTitle: generatedTitle,
        titleGeneratedAt: null, // Will be set when processing completes
        photoUrls: photoUrls,
        videoUrls: videoUrls,
        hasLocation: locationWkt != null,
      );
    } on OfflineException {
      rethrow;
    } catch (e) {
      final errorString = e.toString();

      // Handle storage quota errors
      if (errorString.contains('413') ||
          errorString.contains('quota') ||
          errorString.contains('limit')) {
        throw StorageQuotaException(
            'Storage limit reached. Please delete some memories.');
      }

      // Handle permission errors
      if (errorString.contains('403') || errorString.contains('permission')) {
        throw PermissionException(
            'Permission denied. Please check app settings.');
      }

      // Handle network errors
      if (errorString.contains('SocketException') ||
          errorString.contains('TimeoutException') ||
          errorString.contains('network')) {
        throw NetworkException(
            'Network error. Check your connection and try again.');
      }

      // Generic error
      throw SaveException('Failed to save memory: ${e.toString()}');
    }
  }

  /// Update an existing memory with new data
  ///
  /// This method:
  /// 1. Checks connectivity - throws OfflineException if offline
  /// 2. Uploads new photos and videos to Supabase Storage
  /// 3. Deletes removed media from Supabase Storage
  /// 4. Updates the memory record in the database
  /// 5. Optionally generates a new title if text changed
  ///
  /// Returns the updated memory ID
  /// Throws OfflineException if offline
  Future<MemorySaveResult> updateMemory({
    required String memoryId,
    required CaptureState state,
    SaveProgressCallback? onProgress,
  }) async {
    // Check connectivity first
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      throw OfflineException(
          'Device is offline. Please try again when connected.');
    }

    try {
      // Step 1: Upload new media files
      onProgress?.call(message: 'Uploading new media...', progress: 0.1);
      final newPhotoUrls = <String>[];
      final newVideoUrls = <String>[];

      // Upload new photos with retry logic
      for (int i = 0; i < state.photoPaths.length; i++) {
        final photoPath = state.photoPaths[i];
        final file = File(photoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;

        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage
                .from(_photosBucket)
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: false,
                    contentType: 'image/jpeg',
                  ),
                )
                .timeout(_uploadTimeout);

            publicUrl =
                _supabase.storage.from(_photosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message:
                    'Retrying photo upload... (${i + 1}/${state.photoPaths.length})',
                progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception(
              'Failed to upload photo after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        newPhotoUrls.add(publicUrl);
        onProgress?.call(
          message: 'Uploading photos... (${i + 1}/${state.photoPaths.length})',
          progress: 0.1 + (0.3 * (i + 1) / state.photoPaths.length),
        );
      }

      // Upload new videos with retry logic
      for (int i = 0; i < state.videoPaths.length; i++) {
        final videoPath = state.videoPaths[i];
        final file = File(videoPath);
        if (!await file.exists()) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final storagePath = '${_supabase.auth.currentUser?.id}/$fileName';

        // Retry upload with exponential backoff
        String? publicUrl;
        Exception? lastError;

        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            await _supabase.storage
                .from(_videosBucket)
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: false,
                    contentType: 'video/mp4',
                  ),
                )
                .timeout(_uploadTimeout);

            publicUrl =
                _supabase.storage.from(_videosBucket).getPublicUrl(storagePath);
            break; // Success, exit retry loop
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetries - 1) {
              final delay = Duration(seconds: 1 << attempt);
              await Future.delayed(delay);
              onProgress?.call(
                message:
                    'Retrying video upload... (${i + 1}/${state.videoPaths.length})',
                progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
              );
            }
          }
        }

        if (publicUrl == null) {
          throw Exception(
              'Failed to upload video after $_maxRetries attempts: ${lastError?.toString() ?? 'Unknown error'}');
        }

        newVideoUrls.add(publicUrl);
        onProgress?.call(
          message: 'Uploading videos... (${i + 1}/${state.videoPaths.length})',
          progress: 0.4 + (0.2 * (i + 1) / state.videoPaths.length),
        );
      }

      // Step 2: Delete removed media files
      onProgress?.call(message: 'Removing deleted media...', progress: 0.6);

      // Delete removed photos
      for (final photoUrl in state.deletedPhotoUrls) {
        try {
          // Extract storage path from public URL
          final uri = Uri.parse(photoUrl);
          final pathSegments = uri.pathSegments;
          // Find the bucket name and path
          final bucketIndex = pathSegments.indexOf(_photosBucket);
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from(_photosBucket).remove([storagePath]);
          }
        } catch (e) {
          // Log error but continue - deletion failure shouldn't block update
          print('Failed to delete photo: $photoUrl - $e');
        }
      }

      // Delete removed videos
      for (final videoUrl in state.deletedVideoUrls) {
        try {
          // Extract storage path from public URL
          final uri = Uri.parse(videoUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf(_videosBucket);
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from(_videosBucket).remove([storagePath]);
          }
        } catch (e) {
          // Log error but continue - deletion failure shouldn't block update
          print('Failed to delete video: $videoUrl - $e');
        }
      }

      // Step 3: Combine existing and new media URLs
      final allPhotoUrls = [...state.existingPhotoUrls, ...newPhotoUrls];
      final allVideoUrls = [...state.existingVideoUrls, ...newVideoUrls];

      // Step 4: Prepare location data
      String? locationWkt;
      if (state.latitude != null && state.longitude != null) {
        locationWkt = 'POINT(${state.longitude} ${state.latitude})';
      }

      // Step 5: Update memory record
      onProgress?.call(message: 'Updating memory...', progress: 0.7);
      final now = DateTime.now().toUtc();

      final updateData = <String, dynamic>{
        'input_text': state.inputText,
        'processed_text': null, // Clear processed text - will be regenerated
        'photo_urls': allPhotoUrls,
        'video_urls': allVideoUrls,
        'tags': state.tags,
        'location_status': state.locationStatus,
        'updated_at': now.toIso8601String(),
      };

      // Add memory_date (required - use user-specified or fall back to now)
      final memoryDate = state.memoryDate ?? now;
      updateData['memory_date'] = memoryDate.toUtc().toIso8601String();

      // Add location if available
      if (locationWkt != null) {
        updateData['captured_location'] = locationWkt;
      } else {
        // Clear location if not provided
        updateData['captured_location'] = null;
      }

      await _supabase.from('memories').update(updateData).eq('id', memoryId);

      // Step 6: Queue memory for processing if text changed
      // Processing will happen asynchronously via dispatcher
      final hasInputText = state.inputText?.trim().isNotEmpty == true;
      String? generatedTitle;

      if (hasInputText) {
        // Insert or update processing status row - dispatcher will pick this up
        try {
          // Check if processing status already exists
          final existingStatus = await _supabase
              .from('memory_processing_status')
              .select('memory_id')
              .eq('memory_id', memoryId)
              .maybeSingle();

          if (existingStatus == null) {
            // Insert new processing status
            await _supabase.from('memory_processing_status').insert({
              'memory_id': memoryId,
              'state': 'scheduled',
              'attempts': 0,
              'metadata': {
                'memory_type': state.memoryType.apiValue,
              },
            });
          } else {
            // Reset to scheduled state for reprocessing
            await _supabase
                .from('memory_processing_status')
                .update({
                  'state': 'scheduled',
                  'attempts': 0,
                  'last_error': null,
                  'last_error_at': null,
                  'metadata': {
                    'memory_type': state.memoryType.apiValue,
                  },
                })
                .eq('memory_id', memoryId);
          }
        } catch (e) {
          // Log but don't fail - processing status insert is best-effort
          print('Warning: Failed to update memory_processing_status: $e');
        }
      }

      // Use fallback title for now - will be updated when processing completes
      generatedTitle = _getFallbackTitle(state.memoryType);

      // Set fallback title immediately
      await _supabase.from('memories').update({
        'title': generatedTitle,
      }).eq('id', memoryId);

      onProgress?.call(message: 'Complete!', progress: 1.0);

      return MemorySaveResult(
        memoryId: memoryId,
        generatedTitle: generatedTitle,
        titleGeneratedAt: null, // Will be set when processing completes
        photoUrls: allPhotoUrls,
        videoUrls: allVideoUrls,
        hasLocation: locationWkt != null,
      );
    } on OfflineException {
      rethrow;
    } catch (e) {
      final errorString = e.toString();

      // Handle storage quota errors
      if (errorString.contains('413') ||
          errorString.contains('quota') ||
          errorString.contains('limit')) {
        throw StorageQuotaException(
            'Storage limit reached. Please delete some memories.');
      }

      // Handle permission errors
      if (errorString.contains('403') || errorString.contains('permission')) {
        throw PermissionException(
            'Permission denied. Please check app settings.');
      }

      // Handle network errors
      if (errorString.contains('SocketException') ||
          errorString.contains('TimeoutException') ||
          errorString.contains('network')) {
        throw NetworkException(
            'Network error. Check your connection and try again.');
      }

      // Generic error
      throw SaveException('Failed to update memory: ${e.toString()}');
    }
  }

  String _getFallbackTitle(MemoryType memoryType) {
    switch (memoryType) {
      case MemoryType.moment:
        return 'Untitled Moment';
      case MemoryType.story:
        return 'Untitled Story';
      case MemoryType.memento:
        return 'Untitled Memento';
    }
  }

  /// Update a queued offline memory with new data from capture state
  ///
  /// This method:
  /// - Updates the queue entry with new content (text, tags, media, location)
  /// - Preserves sync metadata (status, retry count, server IDs)
  /// - Does NOT perform connectivity checks
  /// - Does NOT call any Supabase RPC or write to online tables
  ///
  /// Used when editing a queued offline memory while offline.
  Future<void> updateQueuedMemory({
    required String localId,
    required CaptureState state,
  }) async {
    final existing = await _offlineMemoryQueueService.getByLocalId(localId);
    if (existing == null) {
      throw Exception('Queued memory not found: $localId');
    }

    final updated = existing.copyWithFromCaptureState(
      state: state,
      // Preserve sync metadata and timestamps
      createdAt: existing.createdAt,
      retryCount: existing.retryCount,
      status: existing.status,
      serverMemoryId: existing.serverMemoryId,
    );

    await _offlineMemoryQueueService.update(updated);
  }
}

/// Exception thrown when device is offline
class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when storage quota is exceeded
class StorageQuotaException implements Exception {
  final String message;
  StorageQuotaException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when permission is denied
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown for network errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Generic exception for save failures
class SaveException implements Exception {
  final String message;
  SaveException(this.message);

  @override
  String toString() => message;
}

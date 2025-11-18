import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/dictation_service.dart';
import 'package:memories/services/geolocation_service.dart';
import 'package:memories/services/audio_cache_service.dart';
import 'package:memories/providers/feature_flags_provider.dart';
import 'package:uuid/uuid.dart';

part 'capture_state_provider.g.dart';

/// Provider for dictation service
@riverpod
DictationService dictationService(DictationServiceRef ref) {
  // Watch feature flag (sync version)
  final useNewPlugin = ref.watch(useNewDictationPluginSyncProvider);
  final service = DictationService(useNewPlugin: useNewPlugin);
  ref.onDispose(() => service.dispose());
  return service;
}

/// Provider for geolocation service
@riverpod
GeolocationService geolocationService(GeolocationServiceRef ref) {
  return GeolocationService();
}

/// Provider for capture state
/// 
/// Manages the state of the unified capture sheet including:
/// - Memory type selection (Moment/Story/Memento)
/// - Dictation transcript
/// - Description text
/// - Media attachments (photos/videos)
/// - Tags
/// - Dictation status
@riverpod
class CaptureStateNotifier extends _$CaptureStateNotifier {
  @override
  CaptureState build() {
    return const CaptureState();
  }

  /// Set memory type
  void setMemoryType(MemoryType type) {
    state = state.copyWith(
      memoryType: type,
      hasUnsavedChanges: true,
    );
  }

  /// Stream subscriptions for dictation service
  StreamSubscription<String>? _transcriptSubscription;
  StreamSubscription<DictationStatus>? _statusSubscription;
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<String>? _errorSubscription;
  
  /// Timer for tracking elapsed duration during dictation
  Timer? _elapsedTimer;

  /// Cancel all stream subscriptions
  void _cancelSubscriptions() {
    _transcriptSubscription?.cancel();
    _statusSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _errorSubscription?.cancel();
    _transcriptSubscription = null;
    _statusSubscription = null;
    _audioLevelSubscription = null;
    _errorSubscription = null;
  }
  
  /// Cancel elapsed timer
  void _cancelElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }
  
  /// Get current locale string (e.g., 'en-US', 'es-ES')
  String _getCurrentLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return '${locale.languageCode}-${locale.countryCode}';
  }

  /// Start dictation
  Future<void> startDictation() async {
    final dictationService = ref.read(dictationServiceProvider);
    
    if (state.isDictating) {
      return;
    }

    // Cancel any existing subscriptions
    _cancelSubscriptions();

    // Generate session ID if not already set (for audio file tracking)
    // Reuse existing sessionId if available (retry scenario)
    final sessionId = state.sessionId ?? const Uuid().v4();

    // Get current locale for dictation
    final locale = _getCurrentLocale();
    
    // Reset waveform state and start elapsed timer
    final startTime = DateTime.now();
    state = state.copyWith(
      audioLevel: 0.0,
      errorMessage: null,
      sessionId: sessionId,
      elapsedDuration: Duration.zero,
      dictationLocale: locale,
      captureStartTime: startTime,
    );
    
    // Start elapsed timer (updates every second)
    _cancelElapsedTimer();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      state = state.copyWith(
        elapsedDuration: elapsed,
        hasUnsavedChanges: true,
      );
    });

    // Subscribe to status stream
    _statusSubscription = dictationService.statusStream.listen((status) {
      state = state.copyWith(
        isDictating: status == DictationStatus.listening || 
                     status == DictationStatus.starting,
        hasUnsavedChanges: true,
      );
    });

    // Subscribe to transcript updates (result stream)
    _transcriptSubscription = dictationService.transcriptStream.listen((transcript) {
      state = state.copyWith(
        inputText: transcript, // Populate inputText automatically
        hasUnsavedChanges: true,
      );
    });

    // Subscribe to audio level stream (for waveform)
    _audioLevelSubscription = dictationService.audioLevelStream.listen((level) {
      state = state.copyWith(
        audioLevel: level,
        hasUnsavedChanges: true,
      );
    });

    // Subscribe to error stream (permission errors, etc.)
    _errorSubscription = dictationService.errorStream.listen((error) {
      state = state.copyWith(
        errorMessage: error,
        hasUnsavedChanges: true,
      );
    });

    final started = await dictationService.start();
    if (!started) {
      _cancelElapsedTimer();
      state = state.copyWith(
        errorMessage: dictationService.errorMessage ?? 'Failed to start dictation',
        elapsedDuration: Duration.zero,
      );
      return;
    }

    state = state.copyWith(
      isDictating: true,
      hasUnsavedChanges: true,
    );
  }
  
  /// Cancel dictation (discard recording)
  Future<void> cancelDictation() async {
    if (!state.isDictating) {
      return;
    }

    final dictationService = ref.read(dictationServiceProvider);
    await dictationService.cancel();

    // Cancel subscriptions and timer
    _cancelSubscriptions();
    _cancelElapsedTimer();

    // Clean up audio file if it exists (cancel/discard flow)
    final sessionId = state.sessionId;
    if (sessionId != null) {
      final audioCacheService = ref.read(audioCacheServiceProvider);
      await audioCacheService.cleanupAudioFile(
        sessionId: sessionId,
        keepIfQueued: false, // Discarding, so don't keep
      );
    }

    // Reset state
    state = state.copyWith(
      isDictating: false,
      audioLevel: 0.0,
      elapsedDuration: Duration.zero,
      hasUnsavedChanges: true,
      clearAudio: true,
    );
  }

  /// Stop dictation
  Future<void> stopDictation() async {
    if (!state.isDictating) {
      return;
    }

    final dictationService = ref.read(dictationServiceProvider);
    final result = await dictationService.stop();

    // Cancel subscriptions and timer
    _cancelSubscriptions();
    _cancelElapsedTimer();

    // Extract audio metadata if available
    double? audioDuration;
    if (result.metadata != null) {
      audioDuration = (result.metadata!['duration'] as num?)?.toDouble();
    }

    // Store audio file in cache if available (task 4: audio persistence hooks)
    String? cachedAudioPath;
    final sessionId = state.sessionId;
    if (result.audioFilePath != null && sessionId != null) {
      try {
        final audioCacheService = ref.read(audioCacheServiceProvider);
        cachedAudioPath = await audioCacheService.storeAudioFile(
          sourcePath: result.audioFilePath!,
          sessionId: sessionId,
          metadata: {
            ...?result.metadata,
            'locale': state.dictationLocale,
            'captureStartTime': state.captureStartTime?.toIso8601String(),
          },
        );
      } catch (e) {
        // Log error but continue - audio caching failure shouldn't break the flow
        // In production, you might want to log this to analytics
        // For now, fall back to using the original path
        cachedAudioPath = result.audioFilePath;
      }
    } else {
      // No audio file or session ID, use original path if available
      cachedAudioPath = result.audioFilePath;
    }

    // Reset waveform state and store cached audio path
    state = state.copyWith(
      isDictating: false,
      inputText: result.transcript.isNotEmpty ? result.transcript : state.inputText,
      audioPath: cachedAudioPath,
      audioDuration: audioDuration,
      audioLevel: 0.0,
      // Keep elapsedDuration as final recording duration
      hasUnsavedChanges: true,
    );
  }

  /// Update input text
  void updateInputText(String? inputText) {
    state = state.copyWith(
      inputText: inputText,
      hasUnsavedChanges: true,
    );
  }

  /// Add photo path
  void addPhoto(String path) {
    if (!state.canAddPhoto) {
      return;
    }

    final updatedPhotos = [...state.photoPaths, path];
    state = state.copyWith(
      photoPaths: updatedPhotos,
      hasUnsavedChanges: true,
    );
  }

  /// Remove photo at index
  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) {
      return;
    }

    final updatedPhotos = List<String>.from(state.photoPaths);
    updatedPhotos.removeAt(index);
    state = state.copyWith(
      photoPaths: updatedPhotos,
      hasUnsavedChanges: true,
    );
  }

  /// Add video path
  void addVideo(String path) {
    if (!state.canAddVideo) {
      return;
    }

    final updatedVideos = [...state.videoPaths, path];
    state = state.copyWith(
      videoPaths: updatedVideos,
      hasUnsavedChanges: true,
    );
  }

  /// Remove video at index
  void removeVideo(int index) {
    if (index < 0 || index >= state.videoPaths.length) {
      return;
    }

    final updatedVideos = List<String>.from(state.videoPaths);
    updatedVideos.removeAt(index);
    state = state.copyWith(
      videoPaths: updatedVideos,
      hasUnsavedChanges: true,
    );
  }

  /// Add tag
  void addTag(String tag) {
    final trimmedTag = tag.trim().toLowerCase();
    if (trimmedTag.isEmpty) {
      return;
    }

    // Check if tag already exists (case-insensitive)
    if (state.tags.any((t) => t.toLowerCase() == trimmedTag)) {
      return;
    }

    final updatedTags = [...state.tags, trimmedTag];
    state = state.copyWith(
      tags: updatedTags,
      hasUnsavedChanges: true,
    );
  }

  /// Remove tag at index
  void removeTag(int index) {
    if (index < 0 || index >= state.tags.length) {
      return;
    }

    final updatedTags = List<String>.from(state.tags);
    updatedTags.removeAt(index);
    state = state.copyWith(
      tags: updatedTags,
      hasUnsavedChanges: true,
    );
  }

  /// Clear all state
  /// 
  /// [keepAudioIfQueued] if true, keeps audio file even if it's queued for upload
  /// Set to true when clearing state after successful queueing
  Future<void> clear({bool keepAudioIfQueued = false}) async {
    // Cancel subscriptions and timer
    _cancelSubscriptions();
    _cancelElapsedTimer();

    // Stop dictation if active (fire and forget)
    final dictationService = ref.read(dictationServiceProvider);
    if (state.isDictating) {
      dictationService.stop().then((_) {
        dictationService.clear();
      });
    } else {
      dictationService.clear();
    }

    // Clean up audio file (task 4: audio persistence hooks)
    final sessionId = state.sessionId;
    if (sessionId != null) {
      final audioCacheService = ref.read(audioCacheServiceProvider);
      await audioCacheService.cleanupAudioFile(
        sessionId: sessionId,
        keepIfQueued: keepAudioIfQueued,
      );
    }

    state = const CaptureState().copyWith(clearAudio: true);
  }

  /// Set error message
  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Capture location metadata
  /// 
  /// Attempts to get current position and updates state with location
  /// or location status (denied/unavailable)
  Future<void> captureLocation() async {
    final geolocationService = ref.read(geolocationServiceProvider);
    
    try {
      final position = await geolocationService.getCurrentPosition();
      final status = await geolocationService.getLocationStatus();
      
      if (position != null) {
        state = state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          locationStatus: status,
        );
      } else {
        state = state.copyWith(
          locationStatus: status,
        );
      }
    } catch (e) {
      // On error, mark as unavailable
      state = state.copyWith(
        locationStatus: 'unavailable',
      );
    }
  }

  /// Set captured timestamp
  void setCapturedAt(DateTime timestamp) {
    state = state.copyWith(capturedAt: timestamp);
  }

  /// Load existing moment data into capture state for editing
  /// 
  /// Preloads inputText, tags, location, and memory type from a MomentDetail
  /// Note: Media files (photos/videos) are not loaded as they're already uploaded
  /// and cannot be edited. Users can add new media during edit.
  void loadMomentForEdit({
    required String captureType,
    String? inputText,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationStatus,
  }) {
    final memoryType = MemoryTypeExtension.fromApiValue(captureType);
    
    state = state.copyWith(
      memoryType: memoryType,
      inputText: inputText,
      tags: tags ?? [],
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      hasUnsavedChanges: false, // Reset since we're loading existing data
    );
  }
}


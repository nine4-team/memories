import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/dictation_service.dart';
import 'package:memories/services/geolocation_service.dart';
import 'package:memories/services/audio_cache_service.dart';
import 'package:memories/services/location_lookup_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/feature_flags_provider.dart';
import 'package:uuid/uuid.dart';

part 'capture_state_provider.g.dart';

/// Provider for dictation service
///
/// Kept alive for the entire capture surface lifetime to ensure
/// stable lifecycle so mic events continue streaming.
///
/// CRITICAL: Read the feature flag with ref.read() instead of ref.watch()
/// to prevent the service from being recreated if the flag changes.
/// The flag should only be read once when the service is first created.
@Riverpod(keepAlive: true)
DictationService dictationService(DictationServiceRef ref) {
  // Read feature flag ONCE at creation (don't watch to avoid rebuilds)
  final useNewPlugin = ref.read(useNewDictationPluginSyncProvider);
  final service = DictationService(useNewPlugin: useNewPlugin);

  // Initialize immediately in background to pre-warm native layer
  service.ensureInitialized().catchError((e) {
    print('[dictationServiceProvider] Failed to initialize service: $e');
  });

  ref.onDispose(() => service.dispose());
  return service;
}

/// Provider for waveform controller
///
/// Manages waveform visualization state for dictation.
/// Kept alive for the capture surface lifetime.
@Riverpod(keepAlive: true)
WaveformController waveformController(WaveformControllerRef ref) {
  final controller = WaveformController();
  ref.onDispose(() => controller.dispose());
  return controller;
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
@Riverpod(keepAlive: true)
class CaptureStateNotifier extends _$CaptureStateNotifier {
  @override
  CaptureState build() {
    // Watch dictation service to keep it alive for the notifier's lifetime
    ref.watch(dictationServiceProvider);
    // Initialize with current date/time as default memory_date
    return CaptureState(memoryDate: DateTime.now());
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

  /// Text that existed before dictation started (preserved for appending)
  /// CRITICAL: This is used to append dictation text - dictation MUST NEVER overwrite existing text
  String? _textBeforeDictation;

  /// Local ID of queued memory being edited offline (null when not editing offline)
  String? _editingOfflineLocalId;

  /// Whether currently editing an offline queued memory
  bool get isEditingOffline => _editingOfflineLocalId != null;

  /// Local ID of the queued memory being edited (null when not editing offline)
  String? get editingOfflineLocalId => _editingOfflineLocalId;

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

    // CRITICAL: Preserve existing inputText so dictation can append to it
    // Dictation MUST NEVER overwrite existing text - it can only append
    _textBeforeDictation = state.inputText;

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
    // CRITICAL: Dictation MUST append to existing text, NEVER overwrite it
    // The dictation service sends incremental updates:
    // - Partial results: replace the previous partial result
    // - Final results: append to accumulated final results
    // We always combine preserved text + new dictation text
    _transcriptSubscription =
        dictationService.transcriptStream.listen((transcript) {
      // CRITICAL: Always append dictation text to preserved text, never overwrite
      // Get the text that existed before dictation started
      final preservedText = _textBeforeDictation?.trim() ?? '';
      
      // Determine if this is replacing a previous partial result
      // If the new transcript is shorter or different from the last one we saw,
      // and we've already set inputText, this might be a partial replacement
      // However, the service handles partial replacements internally, so we just
      // need to combine preserved text with the current transcript
      
      // CRITICAL: Always combine preserved text with dictation transcript
      // If preserved text exists, append dictation to it (with space)
      // If no preserved text, use dictation text directly
      // NEVER overwrite existing text - only append dictation results
      final combinedText = preservedText.isEmpty
          ? transcript
          : transcript.isEmpty
              ? preservedText
              : '$preservedText $transcript';

      // CRITICAL: Update state with combined text - this preserves existing text
      // and appends new dictation, never overwrites
      state = state.copyWith(
        inputText: combinedText.isEmpty ? null : combinedText,
        hasUnsavedChanges: true,
      );
    });

    // Subscribe to audio level stream (for waveform)
    final waveformController = ref.read(waveformControllerProvider);
    _audioLevelSubscription = dictationService.audioLevelStream.listen((level) {
      // Update waveform controller for plugin widgets
      waveformController.updateLevel(level);
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
        errorMessage:
            dictationService.errorMessage ?? 'Failed to start dictation',
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

    // Reset waveform controller
    final waveformController = ref.read(waveformControllerProvider);
    waveformController.reset();

    // Clean up audio file if it exists (cancel/discard flow)
    final sessionId = state.sessionId;
    if (sessionId != null) {
      final audioCacheService = ref.read(audioCacheServiceProvider);
      await audioCacheService.cleanupAudioFile(
        sessionId: sessionId,
        keepIfQueued: false, // Discarding, so don't keep
      );
    }

    // Restore original text (discard dictation changes) and clear preserved text
    final originalText = _textBeforeDictation;
    _textBeforeDictation = null;

    // Reset state
    state = state.copyWith(
      isDictating: false,
      audioLevel: 0.0,
      elapsedDuration: Duration.zero,
      inputText: originalText, // Restore text that existed before dictation
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

    // Reset waveform controller
    final waveformController = ref.read(waveformControllerProvider);
    waveformController.reset();

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

    // Clear preserved text for next dictation session
    // The current inputText already has the combined text from the transcript subscription
    // CRITICAL: The transcript subscription always appends to preserved text, never overwrites
    _textBeforeDictation = null;

    // Reset waveform state and store cached audio path
    // Keep current inputText (already contains preserved text + dictation transcript)
    state = state.copyWith(
      isDictating: false,
      // inputText already has the combined text from transcript subscription, don't overwrite
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

    // Clear offline editing state
    _editingOfflineLocalId = null;
    
    // Clear memory location data map (instance variable, not part of state)
    _memoryLocationDataMap = null;
    
    state = const CaptureState().copyWith(
      clearAudio: true,
      clearEditingMemoryId: true,
      clearOriginalEditingMemoryId: true,
    );
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

  /// Set memory date (user-specified date when memory occurred)
  void setMemoryDate(DateTime? date) {
    state = state.copyWith(
      memoryDate: date,
      hasUnsavedChanges: true,
    );
  }

  /// Set memory location label and optional coordinates
  /// 
  /// [label] is the user-visible location name (e.g., "Grandma's house", "Brooklyn, NY")
  /// [latitude] and [longitude] are optional coordinates
  void setMemoryLocationLabel({
    String? label,
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      memoryLocationLabel: label,
      memoryLocationLatitude: latitude,
      memoryLocationLongitude: longitude,
      hasUnsavedChanges: true,
    );

    // Update internal map if it exists, or create it
    if (_memoryLocationDataMap != null) {
      _memoryLocationDataMap!['display_name'] = label;
      _memoryLocationDataMap!['latitude'] = latitude;
      _memoryLocationDataMap!['longitude'] = longitude;
      _memoryLocationDataMap!['source'] = 'manual_update';
    } else if (label != null || latitude != null || longitude != null) {
      _memoryLocationDataMap = {
        'display_name': label,
        'latitude': latitude,
        'longitude': longitude,
        'source': 'manual_update',
      };
    }
  }

  /// Set memory location from MemoryLocationData object
  /// 
  /// Updates all memory location fields from a MemoryLocationData object,
  /// typically from reverse geocoding results.
  void setMemoryLocationFromData(MemoryLocationData? locationData) {
    if (locationData == null) {
      state = state.copyWith(
        memoryLocationLabel: null,
        memoryLocationLatitude: null,
        memoryLocationLongitude: null,
        hasUnsavedChanges: true,
      );
      return;
    }

    state = state.copyWith(
      memoryLocationLabel: locationData.displayName,
      memoryLocationLatitude: locationData.latitude,
      memoryLocationLongitude: locationData.longitude,
      hasUnsavedChanges: true,
    );
    
    // Store full location data in a map for saving to database
    // This includes city, state, country, provider, source
    _memoryLocationDataMap = locationData.toJson();
  }

  /// Internal storage for full memory location data (city, state, country, provider, source)
  /// This is used by MemorySaveService to save all fields to memory_location_data JSONB
  Map<String, dynamic>? _memoryLocationDataMap;

  /// Get full memory location data map for saving to database
  /// Returns the full location data including city, state, country, provider, source
  /// Falls back to constructing a minimal map from basic fields if full data not available
  Map<String, dynamic>? getMemoryLocationDataForSave() {
    if (_memoryLocationDataMap != null) {
      // Ensure the map is in sync with the state
      final map = Map<String, dynamic>.from(_memoryLocationDataMap!);
      if (state.memoryLocationLabel != null) {
        map['display_name'] = state.memoryLocationLabel;
      }
      if (state.memoryLocationLatitude != null) {
        map['latitude'] = state.memoryLocationLatitude;
      }
      if (state.memoryLocationLongitude != null) {
        map['longitude'] = state.memoryLocationLongitude;
      }
      return map;
    }
    
    // Fall back to constructing from basic fields
    if (state.memoryLocationLabel != null || 
        state.memoryLocationLatitude != null || 
        state.memoryLocationLongitude != null) {
      final map = <String, dynamic>{};
      if (state.memoryLocationLabel != null) {
        map['display_name'] = state.memoryLocationLabel;
      }
      if (state.memoryLocationLatitude != null) {
        map['latitude'] = state.memoryLocationLatitude;
      }
      if (state.memoryLocationLongitude != null) {
        map['longitude'] = state.memoryLocationLongitude;
      }
      return map;
    }
    
    return null;
  }

  /// Reverse geocode memory location coordinates
  /// 
  /// Calls the reverse geocoding service to get place information from coordinates.
  /// Only attempts if online and coordinates are available.
  /// Falls back gracefully if offline or the call fails.
  /// 
  /// Updates memory location with all fields from the geocoding result.
  Future<void> reverseGeocodeMemoryLocation() async {
    // Only proceed if we have coordinates
    if (state.memoryLocationLatitude == null || 
        state.memoryLocationLongitude == null) {
      return;
    }

    // Check connectivity
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();
    if (!isOnline) {
      // Fall back gracefully - don't update state
      return;
    }

    try {
      final locationLookupService = ref.read(locationLookupServiceProvider);
      final result = await locationLookupService.reverseGeocode(
        latitude: state.memoryLocationLatitude!,
        longitude: state.memoryLocationLongitude!,
      );

      if (result != null) {
        // Update state with full geocoded location data
        setMemoryLocationFromData(result);
      }
    } catch (e) {
      // Fall back gracefully - don't update state on error
      // The user can still manually set a location label
      print('Reverse geocoding failed: $e');
    }
  }

  /// Set input mode (dictation or type)
  /// Automatically stops dictation when switching to type mode
  Future<void> setInputMode(InputMode mode) async {
    // If switching to type mode and dictation is active, stop dictation first
    if (mode == InputMode.type && state.isDictating) {
      await stopDictation();
    }
    state = state.copyWith(inputMode: mode);
  }

  /// Load existing memory data into capture state for editing
  ///
  /// Preloads inputText, tags, location, memory type, existing media URLs, and memoryDate
  /// from a MemoryDetail. Sets editingMemoryId to track edit mode.
  /// 
  /// Note: Memory location data (where event happened) should be set separately via
  /// setMemoryLocationFromData() after calling this method.
  void loadMemoryForEdit({
    required String memoryId,
    required String captureType,
    String? inputText,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationStatus,
    List<String>? existingPhotoUrls,
    List<String>? existingVideoUrls,
    DateTime? memoryDate,
  }) {
    final memoryType = MemoryTypeExtension.fromApiValue(captureType);

    // Clear any previous memory location data map when starting a new edit session
    // It will be set again by setMemoryLocationFromData() if available
    _memoryLocationDataMap = null;

    state = state.copyWith(
      editingMemoryId: memoryId,
      originalEditingMemoryId: memoryId,
      memoryType: memoryType,
      inputText: inputText,
      tags: tags ?? [],
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      existingPhotoUrls: existingPhotoUrls ?? [],
      existingVideoUrls: existingVideoUrls ?? [],
      memoryDate: memoryDate,
      deletedPhotoUrls: const [],
      deletedVideoUrls: const [],
      hasUnsavedChanges: false, // Reset since we're loading existing data
    );
  }

  /// Load offline queued memory data into capture state for editing
  ///
  /// Preloads data from a queued offline memory (not yet synced to server).
  /// Sets _editingOfflineLocalId to track offline edit mode.
  /// Does NOT set editingMemoryId (that's for online edits only).
  void loadOfflineMemoryForEdit({
    required String localId,
    required MemoryType memoryType,
    required String? inputText,
    required List<String> tags,
    required List<String> existingPhotoPaths,
    required List<String> existingVideoPaths,
    double? latitude,
    double? longitude,
    String? locationStatus,
    DateTime? capturedAt,
    DateTime? memoryDate,
  }) {
    _editingOfflineLocalId = localId;

    state = state.copyWith(
      memoryType: memoryType,
      inputText: inputText,
      tags: tags,
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      existingPhotoUrls: existingPhotoPaths.map((p) => 'file://$p').toList(),
      existingVideoUrls: existingVideoPaths.map((p) => 'file://$p').toList(),
      captureStartTime: capturedAt,
      memoryDate: memoryDate,
      editingMemoryId: null, // Do NOT treat this as an online edit
      photoPaths: [], // Start with empty new photos
      videoPaths: [], // Start with empty new videos
      deletedPhotoUrls: const [],
      deletedVideoUrls: const [],
      hasUnsavedChanges: false, // Reset since we're loading existing data
    );
  }

  /// Clear offline editing state
  void clearOfflineEditing() {
    _editingOfflineLocalId = null;
  }

  /// Remove an existing photo URL (mark for deletion on save)
  void removeExistingPhoto(int index) {
    if (index < 0 || index >= state.existingPhotoUrls.length) {
      return;
    }

    final updatedExisting = List<String>.from(state.existingPhotoUrls);
    final removedUrl = updatedExisting.removeAt(index);
    final updatedDeleted = [...state.deletedPhotoUrls, removedUrl];

    state = state.copyWith(
      existingPhotoUrls: updatedExisting,
      deletedPhotoUrls: updatedDeleted,
      hasUnsavedChanges: true,
    );
  }

  /// Remove an existing video URL (mark for deletion on save)
  void removeExistingVideo(int index) {
    if (index < 0 || index >= state.existingVideoUrls.length) {
      return;
    }

    final updatedExisting = List<String>.from(state.existingVideoUrls);
    final removedUrl = updatedExisting.removeAt(index);
    final updatedDeleted = [...state.deletedVideoUrls, removedUrl];

    state = state.copyWith(
      existingVideoUrls: updatedExisting,
      deletedVideoUrls: updatedDeleted,
      hasUnsavedChanges: true,
    );
  }
}

import 'package:memories/models/memory_type.dart';

/// Model representing the state of a memory being captured
class CaptureState {
  /// The type of memory being captured
  final MemoryType memoryType;
  
  /// Input text from dictation or manual entry (canonical field)
  final String? inputText;
  
  /// List of selected photo file paths (local paths before upload)
  final List<String> photoPaths;
  
  /// List of selected video file paths (local paths before upload)
  final List<String> videoPaths;
  
  /// List of tags (case-insensitive, trimmed)
  final List<String> tags;
  
  /// Whether dictation is currently active
  final bool isDictating;
  
  /// Current audio level for waveform visualization (0.0 to 1.0)
  final double audioLevel;
  
  /// Timestamp when capture started
  final DateTime? captureStartTime;
  
  /// Elapsed duration during dictation (updated in real-time)
  final Duration elapsedDuration;
  
  /// Timestamp when capture was saved
  final DateTime? capturedAt;
  
  /// Audio file path (cached audio file from dictation)
  /// Set when dictation stops and audio is persisted
  /// Used for stories - local path to audio recording
  final String? audioPath;
  
  /// Audio duration in seconds (from dictation metadata)
  final double? audioDuration;
  
  /// Locale used for dictation (e.g., 'en-US', 'es-ES')
  /// Tracked separately since plugin doesn't provide it
  final String? dictationLocale;
  
  /// Unique session ID for this capture session
  /// Used to track and reuse audio files for retries
  final String? sessionId;
  
  /// Location coordinates (latitude, longitude)
  final double? latitude;
  final double? longitude;
  
  /// Location status: 'granted', 'denied', or 'unavailable'
  final String? locationStatus;
  
  /// Whether there are unsaved changes
  final bool hasUnsavedChanges;
  
  /// Error message if any
  final String? errorMessage;

  const CaptureState({
    this.memoryType = MemoryType.moment,
    this.inputText,
    this.photoPaths = const [],
    this.videoPaths = const [],
    this.tags = const [],
    this.isDictating = false,
    this.audioLevel = 0.0,
    this.captureStartTime,
    this.elapsedDuration = Duration.zero,
    this.capturedAt,
    this.audioPath,
    this.audioDuration,
    this.dictationLocale,
    this.sessionId,
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.hasUnsavedChanges = false,
    this.errorMessage,
  });

  /// Create a copy with updated fields
  CaptureState copyWith({
    MemoryType? memoryType,
    String? inputText,
    List<String>? photoPaths,
    List<String>? videoPaths,
    List<String>? tags,
    bool? isDictating,
    double? audioLevel,
    DateTime? captureStartTime,
    Duration? elapsedDuration,
    DateTime? capturedAt,
    String? audioPath,
    double? audioDuration,
    String? dictationLocale,
    String? sessionId,
    double? latitude,
    double? longitude,
    String? locationStatus,
    bool? hasUnsavedChanges,
    String? errorMessage,
    bool clearInputText = false,
    bool clearError = false,
    bool clearLocation = false,
    bool clearAudio = false,
  }) {
    return CaptureState(
      memoryType: memoryType ?? this.memoryType,
      inputText: clearInputText
          ? null
          : (inputText ?? this.inputText),
      photoPaths: photoPaths ?? this.photoPaths,
      videoPaths: videoPaths ?? this.videoPaths,
      tags: tags ?? this.tags,
      isDictating: isDictating ?? this.isDictating,
      audioLevel: audioLevel ?? this.audioLevel,
      captureStartTime: captureStartTime ?? this.captureStartTime,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      capturedAt: capturedAt ?? this.capturedAt,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      audioDuration: clearAudio ? null : (audioDuration ?? this.audioDuration),
      dictationLocale: dictationLocale ?? this.dictationLocale,
      sessionId: sessionId ?? this.sessionId,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationStatus: clearLocation ? null : (locationStatus ?? this.locationStatus),
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Determines if the current capture state can be saved.
  /// 
  /// Validation rules:
  /// - Stories: require audio (audioPath must be set)
  /// - Moments: require at least one of {inputText, photo, video}
  /// - Mementos: require at least one of {inputText, photo, video}
  /// 
  /// Tags alone are never sufficient to unlock save.
  bool get canSave {
    // Stories: audio is the only required input
    if (memoryType == MemoryType.story) {
      return audioPath != null && audioPath!.isNotEmpty;
    }
    
    // Mementos: require at least one of inputText, photo, or video
    if (memoryType == MemoryType.memento) {
      return (inputText?.trim().isNotEmpty ?? false) ||
          photoPaths.isNotEmpty ||
          videoPaths.isNotEmpty;
    }
    
    // Moments: require at least one of inputText, photo, or video
    // Tags alone are NOT sufficient
    return (inputText?.trim().isNotEmpty ?? false) ||
        photoPaths.isNotEmpty ||
        videoPaths.isNotEmpty;
  }

  /// Check if photo limit has been reached (10 photos max)
  bool get canAddPhoto => photoPaths.length < 10;

  /// Check if video limit has been reached (3 videos max)
  bool get canAddVideo => videoPaths.length < 3;
}


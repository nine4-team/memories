import 'package:memories/models/memory_type.dart';

/// Input mode for memory capture
enum InputMode {
  /// Dictation mode - voice input with microphone controls
  dictation,
  
  /// Type mode - manual text input
  type,
}

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
  
  /// User-specified date and time when the memory occurred (required)
  final DateTime? memoryDate;
  
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
  
  /// Current input mode (dictation or type)
  final InputMode inputMode;

  /// ID of memory being edited (null when creating new)
  final String? editingMemoryId;

  /// List of existing photo URLs from the memory being edited
  final List<String> existingPhotoUrls;

  /// List of existing video URLs from the memory being edited
  final List<String> existingVideoUrls;

  /// List of existing photo URLs that should be deleted on save
  final List<String> deletedPhotoUrls;

  /// List of existing video URLs that should be deleted on save
  final List<String> deletedVideoUrls;

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
    this.memoryDate,
    this.audioPath,
    this.audioDuration,
    this.dictationLocale,
    this.sessionId,
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.hasUnsavedChanges = false,
    this.errorMessage,
    this.inputMode = InputMode.dictation,
    this.editingMemoryId,
    this.existingPhotoUrls = const [],
    this.existingVideoUrls = const [],
    this.deletedPhotoUrls = const [],
    this.deletedVideoUrls = const [],
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
    DateTime? memoryDate,
    String? audioPath,
    double? audioDuration,
    String? dictationLocale,
    String? sessionId,
    double? latitude,
    double? longitude,
    String? locationStatus,
    bool? hasUnsavedChanges,
    String? errorMessage,
    InputMode? inputMode,
    String? editingMemoryId,
    List<String>? existingPhotoUrls,
    List<String>? existingVideoUrls,
    List<String>? deletedPhotoUrls,
    List<String>? deletedVideoUrls,
    bool clearInputText = false,
    bool clearError = false,
    bool clearLocation = false,
    bool clearAudio = false,
    bool clearEditingMemoryId = false,
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
      memoryDate: memoryDate ?? this.memoryDate,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      audioDuration: clearAudio ? null : (audioDuration ?? this.audioDuration),
      dictationLocale: dictationLocale ?? this.dictationLocale,
      sessionId: sessionId ?? this.sessionId,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationStatus: clearLocation ? null : (locationStatus ?? this.locationStatus),
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      inputMode: inputMode ?? this.inputMode,
      editingMemoryId: clearEditingMemoryId ? null : (editingMemoryId ?? this.editingMemoryId),
      existingPhotoUrls: existingPhotoUrls ?? this.existingPhotoUrls,
      existingVideoUrls: existingVideoUrls ?? this.existingVideoUrls,
      deletedPhotoUrls: deletedPhotoUrls ?? this.deletedPhotoUrls,
      deletedVideoUrls: deletedVideoUrls ?? this.deletedVideoUrls,
    );
  }

  /// Determines if the current capture state can be saved.
  /// 
  /// Validation rules:
  /// - Stories: require audio (audioPath must be set)
  /// - Moments: require at least one of {inputText, photo, video}
  /// - Mementos: require at least one of {inputText, photo, video}
  /// 
  /// When editing, existing media counts toward the requirement.
  /// Tags alone are never sufficient to unlock save.
  bool get canSave {
    // Stories: require either audio or text input
    if (memoryType == MemoryType.story) {
      return (audioPath != null && audioPath!.isNotEmpty) ||
          (inputText?.trim().isNotEmpty ?? false);
    }
    
    // Calculate total media count (existing + new - deleted)
    final totalPhotos = existingPhotoUrls.length + photoPaths.length - deletedPhotoUrls.length;
    final totalVideos = existingVideoUrls.length + videoPaths.length - deletedVideoUrls.length;
    
    // Mementos: require at least one of inputText, photo, or video
    if (memoryType == MemoryType.memento) {
      return (inputText?.trim().isNotEmpty ?? false) ||
          totalPhotos > 0 ||
          totalVideos > 0;
    }
    
    // Moments: require at least one of inputText, photo, or video
    // Tags alone are NOT sufficient
    return (inputText?.trim().isNotEmpty ?? false) ||
        totalPhotos > 0 ||
        totalVideos > 0;
  }

  /// Check if photo limit has been reached (10 photos max)
  /// Includes both new photos and existing photos
  bool get canAddPhoto => (photoPaths.length + existingPhotoUrls.length - deletedPhotoUrls.length) < 10;

  /// Check if video limit has been reached (3 videos max)
  /// Includes both new videos and existing videos
  bool get canAddVideo => (videoPaths.length + existingVideoUrls.length - deletedVideoUrls.length) < 3;

  /// Whether we're currently editing an existing memory
  bool get isEditing => editingMemoryId != null;
}


import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';

/// Status of a queued memory
enum QueuedMemoryStatus {
  queued,
  syncing,
  failed,
  completed,
}

/// Model representing a memory queued for offline sync
///
/// Unified model for moments, mementos, and stories.
/// Stories include optional audio fields (audioPath, audioDuration).
class QueuedMemory {
  static const String operationCreate = 'create';
  static const String operationUpdate = 'update';

  /// Deterministic local ID (UUID)
  final String localId;

  /// Memory type ('moment', 'memento', or 'story')
  final String memoryType;

  /// Input text from dictation or manual entry (canonical field)
  final String? inputText;

  /// User-curated title (nullable; null means fall back to generated title).
  final String? title;

  /// Original curated title snapshot when the edit session started.
  final String? originalTitle;

  /// Whether the input text changed compared to the original snapshot.
  /// Used to decide if NLP processing should be re-queued after sync.
  final bool inputTextChanged;

  /// Audio file path (local path to audio recording) - for stories only
  final String? audioPath;

  /// Audio duration in seconds (optional metadata) - for stories only
  final double? audioDuration;

  /// Photo file paths (local)
  final List<String> photoPaths;

  /// Video file paths (local)
  final List<String> videoPaths;

  /// Video poster file paths aligned with [videoPaths]
  final List<String?> videoPosterPaths;

  /// Tags
  final List<String> tags;

  /// Location latitude
  final double? latitude;

  /// Location longitude
  final double? longitude;

  /// Location status
  final String? locationStatus;

  /// Captured timestamp
  final DateTime? capturedAt;

  /// User-specified date and time when the memory occurred
  final DateTime? memoryDate;

  /// Queue status
  final String status; // 'queued', 'syncing', 'failed', 'completed'

  /// Retry count
  final int retryCount;

  /// Created timestamp
  final DateTime createdAt;

  /// Last retry timestamp
  final DateTime? lastRetryAt;

  /// Server memory ID (set after successful sync)
  /// Unified field name for all memory types (replaces serverMomentId/serverStoryId)
  final String? serverMemoryId;

  /// Error message if sync failed
  final String? errorMessage;

  /// Operation to perform when syncing ('create' or 'update')
  final String operation;

  /// Target memory ID for update operations
  final String? targetMemoryId;

  /// Full memory location data (city/state/country/source/lat/lng/display name)
  final Map<String, dynamic>? memoryLocationData;

  /// Existing remote photo URLs included when editing
  final List<String> existingPhotoUrls;

  /// Existing remote video URLs included when editing
  final List<String> existingVideoUrls;

  /// Existing remote video poster URLs aligned with [existingVideoUrls]
  final List<String?> existingVideoPosterUrls;

  /// Remote photo URLs that should be deleted on sync
  final List<String> deletedPhotoUrls;

  /// Remote video URLs that should be deleted on sync
  final List<String> deletedVideoUrls;

  /// Remote video poster URLs that should be deleted on sync
  final List<String?> deletedVideoPosterUrls;

  /// Version of the serialization format
  /// Increment this when making breaking changes to the model structure
  static const int currentVersion = 4;

  /// Model version for this instance
  final int version;

  QueuedMemory({
    required this.localId,
    required this.memoryType,
    this.inputText,
    this.title,
    this.originalTitle,
    this.audioPath,
    this.audioDuration,
    this.photoPaths = const [],
    this.videoPaths = const [],
    this.videoPosterPaths = const [],
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.capturedAt,
    this.memoryDate,
    this.status = 'queued',
    this.retryCount = 0,
    required this.createdAt,
    this.lastRetryAt,
    this.serverMemoryId,
    this.errorMessage,
    this.operation = operationCreate,
    this.targetMemoryId,
    this.memoryLocationData,
    this.existingPhotoUrls = const [],
    this.existingVideoUrls = const [],
    this.existingVideoPosterUrls = const [],
    this.deletedPhotoUrls = const [],
    this.deletedVideoUrls = const [],
    this.deletedVideoPosterUrls = const [],
    this.version = currentVersion,
    this.inputTextChanged = false,
  });

  bool get isUpdate => operation == operationUpdate;
  bool get isCreate => operation == operationCreate;

  /// Create from CaptureState
  ///
  /// Handles optional audio fields when memoryType is 'story'
  factory QueuedMemory.fromCaptureState({
    required String localId,
    required CaptureState state,
    String? audioPath,
    double? audioDuration,
    DateTime? capturedAt,
    String operation = operationCreate,
    String? targetMemoryId,
    Map<String, dynamic>? memoryLocationData,
  }) {
    return QueuedMemory(
      localId: localId,
      memoryType: state.memoryType.apiValue,
      inputText: state.inputText,
      title: state.memoryTitle,
      originalTitle: state.originalMemoryTitle,
      audioPath: audioPath,
      audioDuration: audioDuration,
      photoPaths: List.from(state.photoPaths),
      videoPaths: List.from(state.videoPaths),
      videoPosterPaths: List<String?>.from(state.videoPosterPaths),
      tags: List.from(state.tags),
      latitude: state.latitude,
      longitude: state.longitude,
      locationStatus: state.locationStatus,
      capturedAt: capturedAt ?? DateTime.now(),
      memoryDate: state.memoryDate,
      createdAt: DateTime.now(),
      operation: operation,
      targetMemoryId: targetMemoryId,
      serverMemoryId: operation == operationUpdate ? targetMemoryId : null,
      memoryLocationData: _cloneMap(memoryLocationData),
      existingPhotoUrls: List.from(state.existingPhotoUrls),
      existingVideoUrls: List.from(state.existingVideoUrls),
      existingVideoPosterUrls:
          List<String?>.from(state.existingVideoPosterUrls),
      deletedPhotoUrls: List.from(state.deletedPhotoUrls),
      deletedVideoUrls: List.from(state.deletedVideoUrls),
      deletedVideoPosterUrls: List<String?>.from(state.deletedVideoPosterUrls),
      inputTextChanged: state.hasInputTextChanged,
    );
  }

  /// Convert to CaptureState
  ///
  /// Includes audioPath and audioDuration for stories
  CaptureState toCaptureState() {
    final mappedLocation = memoryLocationData ?? {};
    final memoryLocationLabel = mappedLocation['display_name'] as String?;
    final memoryLocationLatitude =
        (mappedLocation['latitude'] as num?)?.toDouble();
    final memoryLocationLongitude =
        (mappedLocation['longitude'] as num?)?.toDouble();

    return CaptureState(
      memoryType: _parseMemoryType(memoryType),
      inputText: inputText,
      originalInputText: inputText,
      memoryTitle: title,
      originalMemoryTitle: originalTitle,
      photoPaths: List.from(photoPaths),
      videoPaths: List.from(videoPaths),
      videoPosterPaths: List<String?>.from(videoPosterPaths),
      tags: List.from(tags),
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      capturedAt: capturedAt,
      memoryDate: memoryDate,
      audioPath: audioPath,
      audioDuration: audioDuration,
      memoryLocationLabel: memoryLocationLabel,
      memoryLocationLatitude: memoryLocationLatitude,
      memoryLocationLongitude: memoryLocationLongitude,
      existingPhotoUrls: List.from(existingPhotoUrls),
      existingVideoUrls: List.from(existingVideoUrls),
      existingVideoPosterUrls: List<String?>.from(existingVideoPosterUrls),
      deletedPhotoUrls: List.from(deletedPhotoUrls),
      deletedVideoUrls: List.from(deletedVideoUrls),
      deletedVideoPosterUrls: List<String?>.from(deletedVideoPosterUrls),
      editingMemoryId: isUpdate ? targetMemoryId : null,
      originalEditingMemoryId: isUpdate ? targetMemoryId : null,
    );
  }

  /// Parse memory type string to enum
  MemoryType _parseMemoryType(String value) {
    switch (value.toLowerCase()) {
      case 'moment':
        return MemoryType.moment;
      case 'story':
        return MemoryType.story;
      case 'memento':
        return MemoryType.memento;
      default:
        return MemoryType.moment;
    }
  }

  /// Create copy with updated fields from CaptureState
  ///
  /// Updates content fields from capture state while preserving sync metadata.
  /// Used when editing a queued memory offline.
  /// Preserves audioPath and audioDuration for stories (stories don't allow re-recording during edit).
  QueuedMemory copyWithFromCaptureState({
    required CaptureState state,
    String? status,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastRetryAt,
    String? serverMemoryId,
    String? errorMessage,
    Map<String, dynamic>? memoryLocationData,
  }) {
    // Combine existing photo/video paths with new ones from capture state
    // Extract local paths from file:// URLs in existingPhotoUrls/existingVideoUrls
    final existingPhotoPaths = state.existingPhotoUrls
        .map((url) => url.replaceFirst('file://', ''))
        .where((path) => !state.deletedPhotoUrls.contains('file://$path'))
        .toList();
    final existingVideoPaths = <String>[];
    final existingVideoPosterPaths = <String?>[];
    for (var i = 0; i < state.existingVideoUrls.length; i++) {
      final videoUrl = state.existingVideoUrls[i];
      final normalizedPath = videoUrl.replaceFirst('file://', '');
      final shouldDelete =
          state.deletedVideoUrls.contains('file://$normalizedPath');
      if (shouldDelete) {
        continue;
      }
      existingVideoPaths.add(normalizedPath);
      final posterUrl = i < state.existingVideoPosterUrls.length
          ? state.existingVideoPosterUrls[i]
          : null;
      existingVideoPosterPaths.add(posterUrl);
    }

    // Combine existing (non-deleted) with new paths
    final allPhotoPaths = [...existingPhotoPaths, ...state.photoPaths];
    final allVideoPaths = [...existingVideoPaths, ...state.videoPaths];
    final allVideoPosterPaths = [
      ...existingVideoPosterPaths,
      ...state.videoPosterPaths
    ];

    // Preserve audio fields for stories
    final preservedAudioPath = memoryType == 'story' ? audioPath : null;
    final preservedAudioDuration = memoryType == 'story' ? audioDuration : null;

    final updatedMemoryLocationData = _cloneMap(memoryLocationData) ??
        _cloneMap(this.memoryLocationData) ??
        _buildMemoryLocationDataFromState(state);

    return QueuedMemory(
      localId: localId,
      memoryType: state.memoryType.apiValue,
      inputText: state.inputText,
      title: state.memoryTitle,
      originalTitle: state.originalMemoryTitle,
      audioPath: preservedAudioPath,
      audioDuration: preservedAudioDuration,
      photoPaths: allPhotoPaths,
      videoPaths: allVideoPaths,
      videoPosterPaths: allVideoPosterPaths,
      tags: List.from(state.tags),
      latitude: state.latitude,
      longitude: state.longitude,
      locationStatus: state.locationStatus,
      capturedAt: state.capturedAt ?? capturedAt,
      memoryDate: state.memoryDate ?? this.memoryDate,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      serverMemoryId: serverMemoryId ?? this.serverMemoryId,
      errorMessage: errorMessage ?? this.errorMessage,
      operation: operation,
      targetMemoryId: targetMemoryId,
      memoryLocationData: updatedMemoryLocationData,
      existingPhotoUrls: List.from(state.existingPhotoUrls),
      existingVideoUrls: List.from(state.existingVideoUrls),
      existingVideoPosterUrls:
          List<String?>.from(state.existingVideoPosterUrls),
      deletedPhotoUrls: List.from(state.deletedPhotoUrls),
      deletedVideoUrls: List.from(state.deletedVideoUrls),
      deletedVideoPosterUrls: List<String?>.from(state.deletedVideoPosterUrls),
      version: version,
      inputTextChanged: state.hasInputTextChanged,
    );
  }

  /// Create copy with updated fields
  QueuedMemory copyWith({
    String? localId,
    String? memoryType,
    String? inputText,
    String? title,
    String? originalTitle,
    bool? inputTextChanged,
    String? audioPath,
    double? audioDuration,
    List<String>? photoPaths,
    List<String>? videoPaths,
    List<String?>? videoPosterPaths,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationStatus,
    DateTime? capturedAt,
    DateTime? memoryDate,
    String? status,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastRetryAt,
    String? serverMemoryId,
    String? errorMessage,
    int? version,
    String? operation,
    String? targetMemoryId,
    Map<String, dynamic>? memoryLocationData,
    List<String>? existingPhotoUrls,
    List<String>? existingVideoUrls,
    List<String?>? existingVideoPosterUrls,
    List<String>? deletedPhotoUrls,
    List<String>? deletedVideoUrls,
    List<String?>? deletedVideoPosterUrls,
  }) {
    return QueuedMemory(
      localId: localId ?? this.localId,
      memoryType: memoryType ?? this.memoryType,
      inputText: inputText ?? this.inputText,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      photoPaths: photoPaths ?? this.photoPaths,
      videoPaths: videoPaths ?? this.videoPaths,
      videoPosterPaths: videoPosterPaths ?? this.videoPosterPaths,
      tags: tags ?? this.tags,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationStatus: locationStatus ?? this.locationStatus,
      capturedAt: capturedAt ?? this.capturedAt,
      memoryDate: memoryDate ?? this.memoryDate,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      serverMemoryId: serverMemoryId ?? this.serverMemoryId,
      errorMessage: errorMessage ?? this.errorMessage,
      version: version ?? this.version,
      operation: operation ?? this.operation,
      targetMemoryId: targetMemoryId ?? this.targetMemoryId,
      memoryLocationData: memoryLocationData != null
          ? _cloneMap(memoryLocationData)
          : this.memoryLocationData,
      existingPhotoUrls: existingPhotoUrls ?? this.existingPhotoUrls,
      existingVideoUrls: existingVideoUrls ?? this.existingVideoUrls,
      existingVideoPosterUrls:
          existingVideoPosterUrls ?? this.existingVideoPosterUrls,
      deletedPhotoUrls: deletedPhotoUrls ?? this.deletedPhotoUrls,
      deletedVideoUrls: deletedVideoUrls ?? this.deletedVideoUrls,
      deletedVideoPosterUrls:
          deletedVideoPosterUrls ?? this.deletedVideoPosterUrls,
      inputTextChanged: inputTextChanged ?? this.inputTextChanged,
    );
  }

  QueuedMemoryStatus get statusEnum {
    switch (status) {
      case 'queued':
        return QueuedMemoryStatus.queued;
      case 'syncing':
        return QueuedMemoryStatus.syncing;
      case 'failed':
        return QueuedMemoryStatus.failed;
      case 'completed':
        return QueuedMemoryStatus.completed;
      default:
        return QueuedMemoryStatus.queued;
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'localId': localId,
      'memoryType': memoryType,
      'inputText': inputText,
      'title': title,
      'originalTitle': originalTitle,
      'audioPath': audioPath,
      'audioDuration': audioDuration,
      'photoPaths': photoPaths,
      'videoPaths': videoPaths,
      'videoPosterPaths': videoPosterPaths,
      'tags': tags,
      'latitude': latitude,
      'longitude': longitude,
      'locationStatus': locationStatus,
      'capturedAt': capturedAt?.toIso8601String(),
      'memoryDate': memoryDate?.toIso8601String(),
      'status': status,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastRetryAt': lastRetryAt?.toIso8601String(),
      'serverMemoryId': serverMemoryId,
      'errorMessage': errorMessage,
      'operation': operation,
      'targetMemoryId': targetMemoryId,
      'memoryLocationData': memoryLocationData,
      'existingPhotoUrls': existingPhotoUrls,
      'existingVideoUrls': existingVideoUrls,
      'existingVideoPosterUrls': existingVideoPosterUrls,
      'deletedPhotoUrls': deletedPhotoUrls,
      'deletedVideoUrls': deletedVideoUrls,
      'deletedVideoPosterUrls': deletedVideoPosterUrls,
      'inputTextChanged': inputTextChanged,
    };
  }

  /// Create from JSON
  factory QueuedMemory.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;

    return QueuedMemory(
      version: version,
      localId: json['localId'] as String,
      memoryType: json['memoryType'] as String,
      inputText: json['inputText'] as String?,
      title: json['title'] as String?,
      originalTitle: json['originalTitle'] as String?,
      audioPath: json['audioPath'] as String?,
      audioDuration: (json['audioDuration'] as num?)?.toDouble(),
      photoPaths: List<String>.from(json['photoPaths'] as List? ?? []),
      videoPaths: List<String>.from(json['videoPaths'] as List? ?? []),
      videoPosterPaths:
          List<String?>.from(json['videoPosterPaths'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationStatus: json['locationStatus'] as String?,
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'] as String)
          : null,
      memoryDate: json['memoryDate'] != null
          ? DateTime.parse(json['memoryDate'] as String)
          : null,
      status: json['status'] as String? ?? 'queued',
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastRetryAt: json['lastRetryAt'] != null
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
      serverMemoryId: json['serverMemoryId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      operation: json['operation'] as String? ?? operationCreate,
      targetMemoryId: json['targetMemoryId'] as String?,
      memoryLocationData: _decodeMemoryLocationData(json['memoryLocationData']),
      existingPhotoUrls:
          List<String>.from(json['existingPhotoUrls'] as List? ?? []),
      existingVideoUrls:
          List<String>.from(json['existingVideoUrls'] as List? ?? []),
      existingVideoPosterUrls:
          List<String?>.from(json['existingVideoPosterUrls'] as List? ?? []),
      deletedPhotoUrls:
          List<String>.from(json['deletedPhotoUrls'] as List? ?? []),
      deletedVideoUrls:
          List<String>.from(json['deletedVideoUrls'] as List? ?? []),
      deletedVideoPosterUrls:
          List<String?>.from(json['deletedVideoPosterUrls'] as List? ?? []),
      inputTextChanged: json['inputTextChanged'] as bool? ?? false,
    );
  }

  static Map<String, dynamic>? _decodeMemoryLocationData(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, dynamic>? _buildMemoryLocationDataFromState(CaptureState state) {
    if (state.memoryLocationLabel == null &&
        state.memoryLocationLatitude == null &&
        state.memoryLocationLongitude == null) {
      return _cloneMap(memoryLocationData);
    }

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
    return {
      ...?_cloneMap(memoryLocationData),
      ...map,
    };
  }

  static Map<String, dynamic>? _cloneMap(Map<String, dynamic>? source) {
    if (source == null) {
      return null;
    }
    return Map<String, dynamic>.from(source);
  }
}

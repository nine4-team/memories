import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';

/// Status of a queued story
enum QueuedStoryStatus {
  queued,
  syncing,
  failed,
  completed,
}

/// Model representing a story queued for offline sync
/// 
/// Stories include audio recordings that need to be uploaded along with
/// transcripts and media attachments. The queue ensures offline capture
/// works reliably and syncs automatically when connectivity returns.
class QueuedStory {
  /// Deterministic local ID (UUID)
  final String localId;

  /// Memory type (should always be 'story' for this model)
  final String memoryType;

  /// Input text from dictation or manual entry (canonical field)
  final String? inputText;

  /// Audio file path (local path to audio recording)
  final String? audioPath;

  /// Audio duration in seconds (optional metadata)
  final double? audioDuration;

  /// Photo file paths (local)
  final List<String> photoPaths;

  /// Video file paths (local)
  final List<String> videoPaths;

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

  /// Queue status
  final String status; // 'queued', 'syncing', 'failed', 'completed'

  /// Retry count
  final int retryCount;

  /// Created timestamp
  final DateTime createdAt;

  /// Last retry timestamp
  final DateTime? lastRetryAt;

  /// Server story ID (set after successful sync)
  final String? serverStoryId;

  /// Error message if sync failed
  final String? errorMessage;

  /// Version of the serialization format (for migration compatibility)
  /// Increment this when making breaking changes to the model structure
  static const int currentVersion = 1;

  /// Model version for this instance
  final int version;

  QueuedStory({
    required this.localId,
    required this.memoryType,
    this.inputText,
    this.audioPath,
    this.audioDuration,
    this.photoPaths = const [],
    this.videoPaths = const [],
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.capturedAt,
    this.status = 'queued',
    this.retryCount = 0,
    required this.createdAt,
    this.lastRetryAt,
    this.serverStoryId,
    this.errorMessage,
    this.version = currentVersion,
  });

  /// Create from CaptureState
  /// 
  /// Requires audioPath to be provided separately since CaptureState
  /// doesn't include audio file references yet.
  factory QueuedStory.fromCaptureState({
    required String localId,
    required CaptureState state,
    String? audioPath,
    double? audioDuration,
    DateTime? capturedAt,
  }) {
    return QueuedStory(
      localId: localId,
      memoryType: state.memoryType.apiValue,
      inputText: state.inputText,
      audioPath: audioPath,
      audioDuration: audioDuration,
      photoPaths: List.from(state.photoPaths),
      videoPaths: List.from(state.videoPaths),
      tags: List.from(state.tags),
      latitude: state.latitude,
      longitude: state.longitude,
      locationStatus: state.locationStatus,
      capturedAt: capturedAt ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  /// Convert to CaptureState
  /// 
  /// Note: audioPath is not included in CaptureState as it's story-specific
  CaptureState toCaptureState() {
    return CaptureState(
      memoryType: _parseMemoryType(memoryType),
      inputText: inputText,
      photoPaths: List.from(photoPaths),
      videoPaths: List.from(videoPaths),
      tags: List.from(tags),
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      capturedAt: capturedAt,
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

  /// Create copy with updated fields
  QueuedStory copyWith({
    String? localId,
    String? memoryType,
    String? inputText,
    String? audioPath,
    double? audioDuration,
    List<String>? photoPaths,
    List<String>? videoPaths,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationStatus,
    DateTime? capturedAt,
    String? status,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastRetryAt,
    String? serverStoryId,
    String? errorMessage,
    int? version,
  }) {
    return QueuedStory(
      localId: localId ?? this.localId,
      memoryType: memoryType ?? this.memoryType,
      inputText: inputText ?? this.inputText,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      photoPaths: photoPaths ?? this.photoPaths,
      videoPaths: videoPaths ?? this.videoPaths,
      tags: tags ?? this.tags,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationStatus: locationStatus ?? this.locationStatus,
      capturedAt: capturedAt ?? this.capturedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      serverStoryId: serverStoryId ?? this.serverStoryId,
      errorMessage: errorMessage ?? this.errorMessage,
      version: version ?? this.version,
    );
  }

  QueuedStoryStatus get statusEnum {
    switch (status) {
      case 'queued':
        return QueuedStoryStatus.queued;
      case 'syncing':
        return QueuedStoryStatus.syncing;
      case 'failed':
        return QueuedStoryStatus.failed;
      case 'completed':
        return QueuedStoryStatus.completed;
      default:
        return QueuedStoryStatus.queued;
    }
  }

  /// Convert to JSON for storage
  /// 
  /// Includes version field for migration compatibility
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'localId': localId,
      'memoryType': memoryType,
      'inputText': inputText,
      'audioPath': audioPath,
      'audioDuration': audioDuration,
      'photoPaths': photoPaths,
      'videoPaths': videoPaths,
      'tags': tags,
      'latitude': latitude,
      'longitude': longitude,
      'locationStatus': locationStatus,
      'capturedAt': capturedAt?.toIso8601String(),
      'status': status,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastRetryAt': lastRetryAt?.toIso8601String(),
      'serverStoryId': serverStoryId,
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON
  factory QueuedStory.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    
    return QueuedStory(
      version: version,
      localId: json['localId'] as String,
      memoryType: json['memoryType'] as String,
      inputText: json['inputText'] as String?,
      audioPath: json['audioPath'] as String?,
      audioDuration: json['audioDuration'] as double?,
      photoPaths: List<String>.from(json['photoPaths'] as List? ?? []),
      videoPaths: List<String>.from(json['videoPaths'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationStatus: json['locationStatus'] as String?,
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'queued',
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastRetryAt: json['lastRetryAt'] != null
          ? DateTime.parse(json['lastRetryAt'] as String)
          : null,
      serverStoryId: json['serverStoryId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}


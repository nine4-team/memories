import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';

/// Status of a queued moment
enum QueuedMomentStatus {
  queued,
  syncing,
  failed,
  completed,
}

/// Model representing a moment queued for offline sync
class QueuedMoment {
  /// Deterministic local ID (UUID)
  final String localId;

  /// Memory type
  final String memoryType;

  /// Input text from dictation or manual entry (canonical field)
  final String? inputText;

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

  /// Server moment ID (set after successful sync)
  final String? serverMomentId;

  /// Error message if sync failed
  final String? errorMessage;

  QueuedMoment({
    required this.localId,
    required this.memoryType,
    this.inputText,
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
    this.serverMomentId,
    this.errorMessage,
  });

  /// Create from CaptureState
  factory QueuedMoment.fromCaptureState({
    required String localId,
    required CaptureState state,
    DateTime? capturedAt,
  }) {
    return QueuedMoment(
      localId: localId,
      memoryType: state.memoryType.apiValue,
      inputText: state.inputText,
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
  QueuedMoment copyWith({
    String? localId,
    String? memoryType,
    String? inputText,
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
    String? serverMomentId,
    String? errorMessage,
  }) {
    return QueuedMoment(
      localId: localId ?? this.localId,
      memoryType: memoryType ?? this.memoryType,
      inputText: inputText ?? this.inputText,
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
      serverMomentId: serverMomentId ?? this.serverMomentId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  QueuedMomentStatus get statusEnum {
    switch (status) {
      case 'queued':
        return QueuedMomentStatus.queued;
      case 'syncing':
        return QueuedMomentStatus.syncing;
      case 'failed':
        return QueuedMomentStatus.failed;
      case 'completed':
        return QueuedMomentStatus.completed;
      default:
        return QueuedMomentStatus.queued;
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'memoryType': memoryType,
      'inputText': inputText,
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
      'serverMomentId': serverMomentId,
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON
  factory QueuedMoment.fromJson(Map<String, dynamic> json) {
    return QueuedMoment(
      localId: json['localId'] as String,
      memoryType: json['memoryType'] as String,
      inputText: json['inputText'] as String?,
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
      serverMomentId: json['serverMomentId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}


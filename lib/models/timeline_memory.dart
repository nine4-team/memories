import 'package:memories/models/memory_detail.dart';

/// Status of offline sync for a memory
enum OfflineSyncStatus {
  queued,
  syncing,
  failed,
  synced,
}

/// Model representing a Memory in the timeline feed
class TimelineMemory {
  final String id;
  final String userId;
  final String title;
  final String? inputText;
  final String? processedText;
  final String? generatedTitle;
  final List<String> tags;
  final String memoryType;
  final DateTime capturedAt;
  final DateTime createdAt;
  final DateTime memoryDate;
  final int year;
  final String season;
  final int month;
  final int day;
  final PrimaryMedia? primaryMedia;
  final String? snippetText;
  final DateTime? nextCursorCapturedAt;
  final String? nextCursorId;

  /// True when this memory was captured offline and is stored in a local queue.
  final bool isOfflineQueued;

  /// True when this memory is only represented as a lightweight preview entry.
  /// In Phase 1 this means:
  /// - The card can be shown in the timeline.
  /// - Full detail is NOT available offline.
  final bool isPreviewOnly;

  /// True when full detail for this memory is cached locally.
  /// Phase 1: queued offline memories only.
  /// Phase 2: may also include fully cached synced memories.
  final bool isDetailCachedLocally;

  /// Local ID for queued offline memories (null for preview-only/server entries).
  final String? localId;

  /// Server ID for synced memories (null while queued offline).
  final String? serverId;

  final OfflineSyncStatus offlineSyncStatus;

  TimelineMemory({
    required this.id,
    required this.userId,
    required this.title,
    this.inputText,
    this.processedText,
    this.generatedTitle,
    required this.tags,
    required this.memoryType,
    required this.capturedAt,
    required this.createdAt,
    required this.memoryDate,
    required this.year,
    required this.season,
    required this.month,
    required this.day,
    this.primaryMedia,
    this.snippetText,
    this.nextCursorCapturedAt,
    this.nextCursorId,
    required this.isOfflineQueued,
    required this.isPreviewOnly,
    required this.isDetailCachedLocally,
    this.localId,
    this.serverId,
    required this.offlineSyncStatus,
  });

  /// Display title - prefers generated title, falls back to title, then appropriate "Untitled" text
  String get displayTitle {
    if (generatedTitle != null && generatedTitle!.isNotEmpty) {
      return generatedTitle!;
    }
    if (title.isNotEmpty) {
      return title;
    }
    // Return appropriate untitled text based on memory type
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

  /// Unified descriptive text getter - prefers processed_text, falls back to input_text
  String? get displayText {
    if (processedText != null && processedText!.trim().isNotEmpty) {
      return processedText!.trim();
    }
    if (inputText != null && inputText!.trim().isNotEmpty) {
      return inputText!.trim();
    }
    return null;
  }

  /// Effective ID for this memory - prefers serverId, falls back to localId, then id
  String get effectiveId => serverId ?? localId ?? id;

  /// Whether the user can open a full detail view while offline.
  bool get isAvailableOffline => isOfflineQueued || isDetailCachedLocally;

  /// Effective date - uses memoryDate (now required)
  DateTime get effectiveDate => memoryDate;

  /// Create a copy with updated fields
  TimelineMemory copyWith({
    String? id,
    String? userId,
    String? title,
    String? inputText,
    String? processedText,
    String? generatedTitle,
    List<String>? tags,
    String? memoryType,
    DateTime? capturedAt,
    DateTime? createdAt,
    DateTime? memoryDate,
    int? year,
    String? season,
    int? month,
    int? day,
    PrimaryMedia? primaryMedia,
    String? snippetText,
    DateTime? nextCursorCapturedAt,
    String? nextCursorId,
    bool? isOfflineQueued,
    bool? isPreviewOnly,
    bool? isDetailCachedLocally,
    String? localId,
    String? serverId,
    OfflineSyncStatus? offlineSyncStatus,
  }) {
    return TimelineMemory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      inputText: inputText ?? this.inputText,
      processedText: processedText ?? this.processedText,
      generatedTitle: generatedTitle ?? this.generatedTitle,
      tags: tags ?? this.tags,
      memoryType: memoryType ?? this.memoryType,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      memoryDate: memoryDate ?? this.memoryDate,
      year: year ?? this.year,
      season: season ?? this.season,
      month: month ?? this.month,
      day: day ?? this.day,
      primaryMedia: primaryMedia ?? this.primaryMedia,
      snippetText: snippetText ?? this.snippetText,
      nextCursorCapturedAt: nextCursorCapturedAt ?? this.nextCursorCapturedAt,
      nextCursorId: nextCursorId ?? this.nextCursorId,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
      isPreviewOnly: isPreviewOnly ?? this.isPreviewOnly,
      isDetailCachedLocally: isDetailCachedLocally ?? this.isDetailCachedLocally,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      offlineSyncStatus: offlineSyncStatus ?? this.offlineSyncStatus,
    );
  }

  /// Create from Supabase RPC response
  /// 
  /// For server-synced entries, offline fields are explicitly set to:
  /// - isOfflineQueued: false (server-synced entries are not queued)
  /// - isPreviewOnly: false (full detail available from server)
  /// - isDetailCachedLocally: false (Phase 1: not cached)
  /// - serverId: id from JSON
  /// - offlineSyncStatus: synced
  factory TimelineMemory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return TimelineMemory(
      id: id,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      inputText: json['input_text'] as String?,
      processedText: json['processed_text'] as String?,
      generatedTitle: json['generated_title'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      memoryType: json['memory_type'] as String? ?? 'moment',
      capturedAt: DateTime.parse(json['captured_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      memoryDate: DateTime.parse(json['memory_date'] as String),
      year: json['year'] as int,
      season: json['season'] as String,
      month: json['month'] as int,
      day: json['day'] as int,
      primaryMedia: json['primary_media'] != null
          ? PrimaryMedia.fromJson(json['primary_media'] as Map<String, dynamic>)
          : null,
      snippetText: json['snippet_text'] as String?,
      nextCursorCapturedAt: json['next_cursor_captured_at'] != null
          ? DateTime.parse(json['next_cursor_captured_at'] as String)
          : null,
      nextCursorId: json['next_cursor_id'] as String?,
      isOfflineQueued: false, // Server-synced entries are never queued
      isPreviewOnly: false, // Server-synced entries have full detail available
      isDetailCachedLocally: false, // Phase 1: server entries not cached locally
      localId: null, // Server-synced entries don't have local IDs
      serverId: id, // Server ID is the id from JSON
      offlineSyncStatus: OfflineSyncStatus.synced, // Server entries are synced
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'input_text': inputText,
      'processed_text': processedText,
      'generated_title': generatedTitle,
      'tags': tags,
      'memory_type': memoryType,
      'captured_at': capturedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'memory_date': memoryDate.toIso8601String(),
      'year': year,
      'season': season,
      'month': month,
      'day': day,
      'primary_media': primaryMedia?.toJson(),
      'snippet_text': snippetText,
      'next_cursor_captured_at': nextCursorCapturedAt?.toIso8601String(),
      'next_cursor_id': nextCursorId,
      'is_offline_queued': isOfflineQueued,
      'is_preview_only': isPreviewOnly,
      'is_detail_cached_locally': isDetailCachedLocally,
      'local_id': localId,
      'server_id': serverId,
      'offline_sync_status': _offlineSyncStatusToJson(offlineSyncStatus),
    };
  }

  /// Convert OfflineSyncStatus to JSON
  static String _offlineSyncStatusToJson(OfflineSyncStatus status) {
    switch (status) {
      case OfflineSyncStatus.queued:
        return 'queued';
      case OfflineSyncStatus.syncing:
        return 'syncing';
      case OfflineSyncStatus.failed:
        return 'failed';
      case OfflineSyncStatus.synced:
        return 'synced';
    }
  }
}

/// Primary media metadata for a Memory
class PrimaryMedia {
  final String type; // 'photo' or 'video'
  final String url; // Supabase Storage path or local file path
  final int index;
  final MediaSource source;

  PrimaryMedia({
    required this.type,
    required this.url,
    required this.index,
    this.source = MediaSource.supabaseStorage,
  });

  bool get isLocal => source == MediaSource.localFile;

  factory PrimaryMedia.fromJson(Map<String, dynamic> json) {
    final sourceString = json['source'] as String?;
    final source = sourceString == 'localFile'
        ? MediaSource.localFile
        : MediaSource.supabaseStorage;
    
    return PrimaryMedia(
      type: json['type'] as String,
      url: json['url'] as String,
      index: json['index'] as int,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      'index': index,
      'source': source == MediaSource.localFile ? 'localFile' : 'supabaseStorage',
    };
  }

  bool get isPhoto => type == 'photo';
  bool get isVideo => type == 'video';
}


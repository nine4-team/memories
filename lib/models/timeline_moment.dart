/// Model representing a Moment in the timeline feed
class TimelineMoment {
  final String id;
  final String userId;
  final String title;
  final String? textDescription;
  final String? rawTranscript;
  final String? generatedTitle;
  final List<String> tags;
  final String captureType;
  final DateTime capturedAt;
  final DateTime createdAt;
  final int year;
  final String season;
  final int month;
  final int day;
  final PrimaryMedia? primaryMedia;
  final String? snippetText;
  final DateTime? nextCursorCapturedAt;
  final String? nextCursorId;

  TimelineMoment({
    required this.id,
    required this.userId,
    required this.title,
    this.textDescription,
    this.rawTranscript,
    this.generatedTitle,
    required this.tags,
    required this.captureType,
    required this.capturedAt,
    required this.createdAt,
    required this.year,
    required this.season,
    required this.month,
    required this.day,
    this.primaryMedia,
    this.snippetText,
    this.nextCursorCapturedAt,
    this.nextCursorId,
  });

  /// Display title - prefers generated title, falls back to title, then "Untitled Moment"
  String get displayTitle {
    if (generatedTitle != null && generatedTitle!.isNotEmpty) {
      return generatedTitle!;
    }
    if (title.isNotEmpty) {
      return title;
    }
    return 'Untitled Moment';
  }

  /// Create from Supabase RPC response
  factory TimelineMoment.fromJson(Map<String, dynamic> json) {
    return TimelineMoment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      textDescription: json['text_description'] as String?,
      rawTranscript: json['raw_transcript'] as String?,
      generatedTitle: json['generated_title'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      captureType: json['capture_type'] as String? ?? 'moment',
      capturedAt: DateTime.parse(json['captured_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
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
    );
  }
}

/// Primary media metadata for a Moment
class PrimaryMedia {
  final String type; // 'photo' or 'video'
  final String url; // Supabase Storage path
  final int index;

  PrimaryMedia({
    required this.type,
    required this.url,
    required this.index,
  });

  factory PrimaryMedia.fromJson(Map<String, dynamic> json) {
    return PrimaryMedia(
      type: json['type'] as String,
      url: json['url'] as String,
      index: json['index'] as int,
    );
  }

  bool get isPhoto => type == 'photo';
  bool get isVideo => type == 'video';
}


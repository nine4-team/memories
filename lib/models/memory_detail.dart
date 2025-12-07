import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Source of media content
enum MediaSource {
  /// Media stored in Supabase Storage
  supabaseStorage,

  /// Media stored locally as a file
  localFile,
}

/// Model representing detailed Memory data for the detail view
class MemoryDetail {
  final String id;
  final String userId;
  final String title;
  final String? inputText;
  final String? processedText;
  final String? generatedTitle;
  final DateTime? titleGeneratedAt;
  final List<String> tags;
  final String memoryType;
  final DateTime capturedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime memoryDate;
  final String? publicShareToken;
  final LocationData? locationData;
  final MemoryLocationData? memoryLocationData;
  final List<PhotoMedia> photos;
  final List<VideoMedia> videos;
  final List<String> relatedStories;
  final List<String> relatedMementos;

  /// Audio storage path (Supabase Storage path) - for stories only
  final String? audioPath;

  /// Audio duration in seconds - nullable until stored in database
  final double? audioDuration;

  MemoryDetail({
    required this.id,
    required this.userId,
    required this.title,
    this.inputText,
    this.processedText,
    this.generatedTitle,
    this.titleGeneratedAt,
    required this.tags,
    required this.memoryType,
    required this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.memoryDate,
    this.publicShareToken,
    this.locationData,
    this.memoryLocationData,
    required this.photos,
    required this.videos,
    required this.relatedStories,
    required this.relatedMementos,
    this.audioPath,
    this.audioDuration,
  });

  /// Display title - prefers generated title, falls back to title, then first 60 chars of memory text
  String get displayTitle {
    if (generatedTitle != null && generatedTitle!.isNotEmpty) {
      return generatedTitle!;
    }
    if (title.isNotEmpty) {
      return title;
    }
    // Fallback to first 60 characters of memory text
    final text = displayText;
    if (text != null && text.isNotEmpty) {
      if (text.length <= 60) {
        return text;
      }
      return '${text.substring(0, 60)}...';
    }
    // If no text available, use appropriate fallback based on memory type
    if (memoryType == 'story') {
      return 'Untitled Story';
    } else if (memoryType == 'memento') {
      return 'Untitled Memento';
    } else {
      return 'Untitled Moment';
    }
  }

  /// Whether a generated title exists for this memory
  bool get hasGeneratedTitle {
    return (generatedTitle != null && generatedTitle!.trim().isNotEmpty) ||
        titleGeneratedAt != null;
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

  /// Effective date - uses memoryDate (now required)
  DateTime get effectiveDate => memoryDate;

  /// Create from Supabase RPC response
  factory MemoryDetail.fromJson(Map<String, dynamic> json) {
    final photosJson = json['photos'] as List<dynamic>?;
    final photos = photosJson
            ?.map((e) => PhotoMedia.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Log photo URLs for debugging
    if (photos.isNotEmpty) {
      debugPrint(
          '[MemoryDetail] Parsed ${photos.length} photos for memory ${json['id']}');
      for (final photo in photos) {
        debugPrint(
            '[MemoryDetail]   Photo index ${photo.index}: url="${photo.url}"');
      }
      developer.log(
        'MemoryDetail.fromJson: Parsed ${photos.length} photos for memory ${json['id']}',
        name: 'MemoryDetail',
      );
      for (final photo in photos) {
        developer.log(
          '  Photo index ${photo.index}: url="${photo.url}"',
          name: 'MemoryDetail',
        );
      }
    }

    return MemoryDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      inputText: json['input_text'] as String?,
      processedText: json['processed_text'] as String?,
      generatedTitle: json['generated_title'] as String?,
      titleGeneratedAt: json['title_generated_at'] != null
          ? DateTime.parse(json['title_generated_at'] as String)
          : null,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      memoryType: json['memory_type'] as String? ?? 'moment',
      capturedAt: DateTime.parse(json['captured_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      memoryDate: DateTime.parse(json['memory_date'] as String),
      publicShareToken: json['public_share_token'] as String?,
      locationData: json['location_data'] != null
          ? LocationData.fromJson(json['location_data'] as Map<String, dynamic>)
          : null,
      memoryLocationData: json['memory_location_data'] != null
          ? MemoryLocationData.fromJson(
              json['memory_location_data'] as Map<String, dynamic>)
          : null,
      photos: photos,
      videos: (json['videos'] as List<dynamic>?)
              ?.map((e) => VideoMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      relatedStories: (json['related_stories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      relatedMementos: (json['related_mementos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioPath: json['audio_path'] as String?,
      audioDuration: json['audio_duration'] != null
          ? (json['audio_duration'] as num).toDouble()
          : null,
    );
  }

  // Debug logging for audio fields
  void logAudioFields() {
    developer.log(
      '[MemoryDetail] Audio fields for memory $id: '
      'audioPath=$audioPath audioDuration=$audioDuration memoryType=$memoryType',
      name: 'MemoryDetail',
    );
  }
}

/// Location data for a Memory
///
/// This represents captured location (where the phone was when capturing)
/// For memory location (where the event happened), see MemoryLocationData
class LocationData {
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final String? status;

  LocationData({
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.status,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      city: json['city'] as String?,
      state: json['state'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      status: json['status'] as String?,
    );
  }

  /// Get formatted location string (City, State)
  String? get formattedLocation {
    if (city != null && state != null) {
      return '$city, $state';
    } else if (city != null) {
      return city;
    } else if (state != null) {
      return state;
    }
    return null;
  }
}

/// Memory location data (where the event happened, distinct from captured location)
class MemoryLocationData {
  final String? displayName;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? provider;
  final String?
      source; // e.g., 'gps_suggestion', 'manual_text_only', 'manual_with_suggestion'

  MemoryLocationData({
    this.displayName,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.provider,
    this.source,
  });

  factory MemoryLocationData.fromJson(Map<String, dynamic> json) {
    return MemoryLocationData(
      displayName: json['display_name'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      provider: json['provider'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (displayName != null) 'display_name': displayName,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (provider != null) 'provider': provider,
      if (source != null) 'source': source,
    };
  }

  /// Get formatted location string - prefers displayName, falls back to city/state
  String? get formattedLocation {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName;
    }
    if (city != null && state != null) {
      return '$city, $state';
    } else if (city != null) {
      return city;
    } else if (state != null) {
      return state;
    }
    return null;
  }
}

/// Photo media metadata
class PhotoMedia {
  final String url; // Supabase Storage path or local file path
  final int index;
  final int? width;
  final int? height;
  final String? caption;
  final MediaSource source;

  PhotoMedia({
    required this.url,
    required this.index,
    this.width,
    this.height,
    this.caption,
    this.source = MediaSource.supabaseStorage,
  });

  bool get isLocal => source == MediaSource.localFile;

  factory PhotoMedia.fromJson(Map<String, dynamic> json) {
    final sourceString = json['source'] as String?;
    final source = sourceString == 'localFile'
        ? MediaSource.localFile
        : MediaSource.supabaseStorage;

    return PhotoMedia(
      url: json['url'] as String,
      index: json['index'] as int,
      width: json['width'] as int?,
      height: json['height'] as int?,
      caption: json['caption'] as String?,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'index': index,
      'width': width,
      'height': height,
      'caption': caption,
      'source':
          source == MediaSource.localFile ? 'localFile' : 'supabaseStorage',
    };
  }
}

/// Video media metadata
class VideoMedia {
  final String url; // Supabase Storage path or local file path
  final int index;
  final double? duration; // seconds
  final String? posterUrl; // Supabase Storage path for poster frame
  final String? caption;
  final MediaSource source;

  VideoMedia({
    required this.url,
    required this.index,
    this.duration,
    this.posterUrl,
    this.caption,
    this.source = MediaSource.supabaseStorage,
  });

  bool get isLocal => source == MediaSource.localFile;

  factory VideoMedia.fromJson(Map<String, dynamic> json) {
    final sourceString = json['source'] as String?;
    final source = sourceString == 'localFile'
        ? MediaSource.localFile
        : MediaSource.supabaseStorage;

    return VideoMedia(
      url: json['url'] as String,
      index: json['index'] as int,
      duration: json['duration'] != null
          ? (json['duration'] as num).toDouble()
          : null,
      posterUrl: json['poster_url'] as String?,
      caption: json['caption'] as String?,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'index': index,
      'duration': duration,
      'poster_url': posterUrl,
      'caption': caption,
      'source':
          source == MediaSource.localFile ? 'localFile' : 'supabaseStorage',
    };
  }
}

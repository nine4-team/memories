import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for caching signed URLs to reduce redundant API calls
/// 
/// Caches signed URLs in memory for the duration of the app session.
/// URLs expire after 1 hour for timeline thumbnails, or 2 hours for detail view media.
class TimelineImageCacheService {
  final Map<String, _CachedUrl> _cache = {};
  static const int _urlExpirySeconds = 3600; // 1 hour for timeline thumbnails
  static const int _detailViewExpirySeconds = 7200; // 2 hours for detail view media

  /// Get a signed URL for a storage path, using cache if available
  /// 
  /// [supabase] is the Supabase client
  /// [bucket] is the storage bucket name ('photos' or 'videos')
  /// [path] is the storage path
  /// 
  /// Returns a Future that resolves to the signed URL
  Future<String> getSignedUrl(
    SupabaseClient supabase,
    String bucket,
    String path,
  ) async {
    return getSignedUrlWithExpiry(supabase, bucket, path, _urlExpirySeconds);
  }

  /// Get a signed URL for detail view media with extended expiry
  /// 
  /// Use this method for detail view carousel and lightbox media to ensure
  /// URLs remain valid for longer detail view sessions.
  /// 
  /// [supabase] is the Supabase client
  /// [bucket] is the storage bucket name ('photos' or 'videos')
  /// [path] is the storage path
  /// 
  /// Returns a Future that resolves to the signed URL
  Future<String> getSignedUrlForDetailView(
    SupabaseClient supabase,
    String bucket,
    String path,
  ) async {
    return getSignedUrlWithExpiry(supabase, bucket, path, _detailViewExpirySeconds);
  }

  /// Internal method to get signed URL with custom expiry
  Future<String> getSignedUrlWithExpiry(
    SupabaseClient supabase,
    String bucket,
    String path,
    int expirySeconds,
  ) async {
    final cacheKey = '$bucket/$path';
    final cached = _cache[cacheKey];

    // Check if cached URL is still valid (not expired)
    // Note: We check expiry based on the cached expiry time, not the requested expiry
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Generate new signed URL with requested expiry
    final url = await supabase.storage
        .from(bucket)
        .createSignedUrl(path, expirySeconds);

    // Cache the URL with the expiry time we requested
    _cache[cacheKey] = _CachedUrl(
      url: url,
      expiresAt: DateTime.now().add(Duration(seconds: expirySeconds)),
    );

    return url;
  }

  /// Clear expired entries from cache
  /// 
  /// Call this periodically to prevent memory leaks
  void clearExpired() {
    _cache.removeWhere((key, value) => value.isExpired);
  }

  /// Clear all cached URLs
  void clear() {
    _cache.clear();
  }

  /// Get cache size (for debugging)
  int get cacheSize => _cache.length;
}

/// Internal class for cached URL with expiry
class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl({
    required this.url,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}


import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for caching signed URLs to reduce redundant API calls
/// 
/// Caches signed URLs in memory for the duration of the app session.
/// URLs expire after 1 hour, matching Supabase signed URL expiry.
class TimelineImageCacheService {
  final Map<String, _CachedUrl> _cache = {};
  static const int _urlExpirySeconds = 3600; // 1 hour

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
    final cacheKey = '$bucket/$path';
    final cached = _cache[cacheKey];

    // Check if cached URL is still valid (not expired)
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    // Generate new signed URL
    final url = await supabase.storage
        .from(bucket)
        .createSignedUrl(path, _urlExpirySeconds);

    // Cache the URL
    _cache[cacheKey] = _CachedUrl(
      url: url,
      expiresAt: DateTime.now().add(const Duration(seconds: _urlExpirySeconds)),
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


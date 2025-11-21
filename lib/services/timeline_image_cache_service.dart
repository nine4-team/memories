import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
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
  /// [bucket] is the storage bucket name ('memories-photos' or 'memories-videos')
  /// [path] is the storage path (can be a full URL or just the path)
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
  /// [bucket] is the storage bucket name ('memories-photos' or 'memories-videos')
  /// [path] is the storage path (can be a full URL or just the path)
  /// 
  /// Returns a Future that resolves to the signed URL
  Future<String> getSignedUrlForDetailView(
    SupabaseClient supabase,
    String bucket,
    String path,
  ) async {
    return getSignedUrlWithExpiry(supabase, bucket, path, _detailViewExpirySeconds);
  }

  /// Normalize a storage path, extracting it from a full URL if necessary
  /// 
  /// If [path] is a full Supabase Storage public URL, extracts the storage path.
  /// If [path] is already a storage path, returns it as-is.
  String _normalizeStoragePath(String path) {
    // Check if it's a full URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final uri = Uri.parse(path);
        final pathSegments = uri.pathSegments;
        
        // Supabase Storage public URLs have format:
        // /storage/v1/object/public/{bucket-name}/{path}
        // We need to find the index of 'public' and extract everything after the bucket name
        final publicIndex = pathSegments.indexOf('public');
        if (publicIndex != -1 && publicIndex < pathSegments.length - 1) {
          // Everything after 'public' is: bucket-name, then the actual path
          // Skip the bucket name (publicIndex + 1) and join the rest
          final storagePath = pathSegments.sublist(publicIndex + 2).join('/');
          debugPrint('[TimelineImageCacheService] Extracted storage path from URL: $storagePath');
          developer.log('Extracted storage path from URL: $storagePath', name: 'TimelineImageCacheService');
          return storagePath;
        }
      } catch (e) {
        debugPrint('[TimelineImageCacheService] Failed to parse URL, using as-is: $e');
        developer.log('Failed to parse URL, using as-is: $e', name: 'TimelineImageCacheService');
      }
    }
    
    // Return as-is if not a URL or parsing failed
    return path;
  }

  /// Internal method to get signed URL with custom expiry
  Future<String> getSignedUrlWithExpiry(
    SupabaseClient supabase,
    String bucket,
    String path,
    int expirySeconds,
  ) async {
    // Normalize the path (extract from URL if necessary)
    final normalizedPath = _normalizeStoragePath(path);
    final cacheKey = '$bucket/$normalizedPath';
    final cached = _cache[cacheKey];

    // Check if cached URL is still valid (not expired)
    // Note: We check expiry based on the cached expiry time, not the requested expiry
    if (cached != null && !cached.isExpired) {
      debugPrint('[TimelineImageCacheService] Using cached signed URL for $cacheKey');
      developer.log('Using cached signed URL for $cacheKey', name: 'TimelineImageCacheService');
      return cached.url;
    }

    try {
      debugPrint('[TimelineImageCacheService] Generating signed URL for bucket=$bucket, path=$normalizedPath');
      developer.log('Generating signed URL for bucket=$bucket, path=$normalizedPath', name: 'TimelineImageCacheService');
      
      // Generate new signed URL with requested expiry
      final url = await supabase.storage
          .from(bucket)
          .createSignedUrl(normalizedPath, expirySeconds);

      debugPrint('[TimelineImageCacheService] ✓ Successfully generated signed URL for $cacheKey');
      developer.log('Successfully generated signed URL for $cacheKey', name: 'TimelineImageCacheService');

      // Cache the URL with the expiry time we requested
      _cache[cacheKey] = _CachedUrl(
        url: url,
        expiresAt: DateTime.now().add(Duration(seconds: expirySeconds)),
      );

      return url;
    } catch (e, stackTrace) {
      debugPrint('[TimelineImageCacheService] ✗ Failed to generate signed URL');
      debugPrint('  Bucket: $bucket');
      debugPrint('  Path: $path');
      debugPrint('  Error: $e');
      developer.log(
        'Failed to generate signed URL for bucket=$bucket, path=$path: $e',
        name: 'TimelineImageCacheService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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


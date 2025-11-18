import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/models/moment_detail.dart';

/// Result of fetching moment detail
class MomentDetailResult {
  final MomentDetail moment;
  final bool isFromCache;

  MomentDetailResult({
    required this.moment,
    required this.isFromCache,
  });
}

/// Service for fetching moment detail data from Supabase
class MomentDetailService {
  final SupabaseClient _supabase;
  static const String _cachePrefix = 'moment_detail_cache_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  MomentDetailService(this._supabase);

  /// Fetch detailed moment data by ID
  /// 
  /// [momentId] is the UUID of the moment to fetch
  /// [preferCache] if true, will try cache first before network
  /// 
  /// Returns a [MomentDetailResult] with moment data and cache status
  /// Throws an exception if the moment is not found or user doesn't have access
  Future<MomentDetailResult> getMomentDetail(
    String momentId, {
    bool preferCache = false,
  }) async {
    // Try cache first if requested
    if (preferCache) {
      final cached = await _getCachedMomentDetail(momentId);
      if (cached != null) {
        return MomentDetailResult(moment: cached, isFromCache: true);
      }
    }

    try {
      final response = await _supabase.rpc(
        'get_moment_detail',
        params: {'p_moment_id': momentId},
      ).single();

      final moment = MomentDetail.fromJson(Map<String, dynamic>.from(response));
      
      // Cache the result for offline access
      await _cacheMomentDetail(momentId, moment);
      
      return MomentDetailResult(moment: moment, isFromCache: false);
    } catch (e) {
      // If network fails, try cache as fallback
      final cached = await _getCachedMomentDetail(momentId);
      if (cached != null) {
        return MomentDetailResult(moment: cached, isFromCache: true);
      }
      // Re-throw with more context
      throw Exception('Failed to fetch moment detail: $e');
    }
  }

  /// Get cached moment detail if available and not expired
  Future<MomentDetail?> _getCachedMomentDetail(String momentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$momentId';
      final cacheData = prefs.getString(cacheKey);
      
      if (cacheData == null) return null;
      
      final json = jsonDecode(cacheData) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(json['cached_at'] as String);
      final now = DateTime.now();
      
      // Check if cache is expired
      if (now.difference(cachedAt) > _cacheExpiry) {
        // Remove expired cache
        await prefs.remove(cacheKey);
        return null;
      }
      
      // Return cached moment
      return MomentDetail.fromJson(json['moment'] as Map<String, dynamic>);
    } catch (e) {
      // If cache read fails, return null
      return null;
    }
  }

  /// Cache moment detail data
  Future<void> _cacheMomentDetail(String momentId, MomentDetail moment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$momentId';
      
      final cacheData = {
        'moment': {
          'id': moment.id,
          'user_id': moment.userId,
          'title': moment.title,
          'input_text': moment.inputText,
          'processed_text': moment.processedText,
          'generated_title': moment.generatedTitle,
          'tags': moment.tags,
          'memory_type': moment.memoryType,
          'captured_at': moment.capturedAt.toIso8601String(),
          'created_at': moment.createdAt.toIso8601String(),
          'updated_at': moment.updatedAt.toIso8601String(),
          'public_share_token': moment.publicShareToken,
          'location_data': moment.locationData != null
              ? {
                  'city': moment.locationData!.city,
                  'state': moment.locationData!.state,
                  'latitude': moment.locationData!.latitude,
                  'longitude': moment.locationData!.longitude,
                  'status': moment.locationData!.status,
                }
              : null,
          'photos': moment.photos.map((p) => {
                'url': p.url,
                'index': p.index,
                'width': p.width,
                'height': p.height,
                'caption': p.caption,
              }).toList(),
          'videos': moment.videos.map((v) => {
                'url': v.url,
                'index': v.index,
                'duration': v.duration,
                'poster_url': v.posterUrl,
                'caption': v.caption,
              }).toList(),
          'related_stories': moment.relatedStories,
          'related_mementos': moment.relatedMementos,
        },
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      // Silently fail cache write - not critical
    }
  }

  /// Check if cached data exists for a moment
  Future<bool> hasCachedData(String momentId) async {
    final cached = await _getCachedMomentDetail(momentId);
    return cached != null;
  }

  /// Delete a moment by ID
  /// 
  /// [momentId] is the UUID of the moment to delete
  /// 
  /// Throws an exception if the moment is not found or user doesn't have permission
  Future<void> deleteMoment(String momentId) async {
    try {
      final response = await _supabase
          .from('memories')
          .delete()
          .eq('id', momentId)
          .select();

      if (response.isEmpty) {
        throw Exception('Moment not found or already deleted');
      }
    } catch (e) {
      throw Exception('Failed to delete moment: $e');
    }
  }

  /// Create or get a share link for a moment
  /// 
  /// [momentId] is the UUID of the moment to share
  /// 
  /// Returns a shareable URL if successful, or null if share link creation fails
  /// This will request/create a public_share_token via a future edge function
  /// For now, returns null if token doesn't exist (backend not ready)
  Future<String?> getShareLink(String momentId) async {
    try {
      // First check if moment already has a share token
      final moment = await _supabase
          .from('memories')
          .select('public_share_token')
          .eq('id', momentId)
          .single();

      final existingToken = moment['public_share_token'] as String?;
      
      if (existingToken != null && existingToken.isNotEmpty) {
        // Return shareable URL (format: https://app.example.com/share/<token>)
        // For now, return a placeholder URL structure
        // TODO: Replace with actual app URL when share functionality is fully implemented
        return 'https://app.example.com/share/$existingToken';
      }

      // TODO: Call edge function to create share token when available
      // For now, return null to indicate share link creation is not yet available
      // This will trigger the "Sharing unavailable" error message
      return null;
    } catch (e) {
      // Return null on any error to trigger error handling
      return null;
    }
  }
}


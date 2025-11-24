import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/models/memory_detail.dart';

/// Result of fetching memory detail
class MemoryDetailResult {
  final MemoryDetail memory;
  final bool isFromCache;

  MemoryDetailResult({
    required this.memory,
    required this.isFromCache,
  });
}

/// Service for fetching memory detail data from Supabase
class MemoryDetailService {
  final SupabaseClient _supabase;
  static const String _cachePrefix = 'memory_detail_cache_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  MemoryDetailService(this._supabase);

  /// Fetch detailed memory data by ID
  ///
  /// [memoryId] is the UUID of the memory to fetch
  /// [preferCache] if true, will try cache first before network
  ///
  /// Returns a [MemoryDetailResult] with memory data and cache status
  /// Throws an exception if the memory is not found or user doesn't have access
  Future<MemoryDetailResult> getMemoryDetail(
    String memoryId, {
    bool preferCache = false,
  }) async {
    // Try cache first if requested
    if (preferCache) {
      final cached = await _getCachedMemoryDetail(memoryId);
      if (cached != null) {
        return MemoryDetailResult(memory: cached, isFromCache: true);
      }
    }

    try {
      debugPrint(
          '[MemoryDetailService] Fetching memory detail for ID: $memoryId');
      final response = await _supabase.rpc(
        'get_memory_detail',
        params: {'p_memory_id': memoryId},
      ).single();

      debugPrint('[MemoryDetailService] Received response from RPC');
      debugPrint(
          '[MemoryDetailService] Response keys: ${response.keys.toList()}');

      // Log photos array before parsing
      final photosJson = response['photos'] as List<dynamic>?;
      debugPrint(
          '[MemoryDetailService] Photos array: ${photosJson?.length ?? 0} items');
      if (photosJson != null && photosJson.isNotEmpty) {
        for (int i = 0; i < photosJson.length; i++) {
          final photo = photosJson[i] as Map<String, dynamic>?;
          debugPrint('[MemoryDetailService]   Photo $i: ${photo?.toString()}');
        }
      }

      final memory = MemoryDetail.fromJson(Map<String, dynamic>.from(response));

      debugPrint('[MemoryDetailService] Parsed memory: ${memory.id}');
      debugPrint(
          '[MemoryDetailService]   Photos count: ${memory.photos.length}');
      debugPrint(
          '[MemoryDetailService]   Videos count: ${memory.videos.length}');

      // Cache the result for offline access
      await _cacheMemoryDetail(memoryId, memory);

      return MemoryDetailResult(memory: memory, isFromCache: false);
    } catch (e) {
      // If network fails, try cache as fallback
      final cached = await _getCachedMemoryDetail(memoryId);
      if (cached != null) {
        return MemoryDetailResult(memory: cached, isFromCache: true);
      }
      // Re-throw with more context
      throw Exception('Failed to fetch memory detail: $e');
    }
  }

  /// Get cached memory detail if available and not expired
  Future<MemoryDetail?> _getCachedMemoryDetail(String memoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$memoryId';
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

      // Return cached memory
      return MemoryDetail.fromJson(json['memory'] as Map<String, dynamic>);
    } catch (e) {
      // If cache read fails, return null
      return null;
    }
  }

  /// Cache memory detail data
  Future<void> _cacheMemoryDetail(String memoryId, MemoryDetail memory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$memoryId';

      final cacheData = {
        'memory': {
          'id': memory.id,
          'user_id': memory.userId,
          'title': memory.title,
          'input_text': memory.inputText,
          'processed_text': memory.processedText,
          'generated_title': memory.generatedTitle,
          'tags': memory.tags,
          'memory_type': memory.memoryType,
          'captured_at': memory.capturedAt.toIso8601String(),
          'created_at': memory.createdAt.toIso8601String(),
          'updated_at': memory.updatedAt.toIso8601String(),
          'memory_date': memory.memoryDate?.toIso8601String(),
          'public_share_token': memory.publicShareToken,
          'location_data': memory.locationData != null
              ? {
                  'city': memory.locationData!.city,
                  'state': memory.locationData!.state,
                  'latitude': memory.locationData!.latitude,
                  'longitude': memory.locationData!.longitude,
                  'status': memory.locationData!.status,
                }
              : null,
          'photos': memory.photos
              .map((p) => {
                    'url': p.url,
                    'index': p.index,
                    'width': p.width,
                    'height': p.height,
                    'caption': p.caption,
                  })
              .toList(),
          'videos': memory.videos
              .map((v) => {
                    'url': v.url,
                    'index': v.index,
                    'duration': v.duration,
                    'poster_url': v.posterUrl,
                    'caption': v.caption,
                  })
              .toList(),
          'related_stories': memory.relatedStories,
          'related_mementos': memory.relatedMementos,
        },
        'cached_at': DateTime.now().toIso8601String(),
      };

      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      // Silently fail cache write - not critical
    }
  }

  /// Check if cached data exists for a memory
  Future<bool> hasCachedData(String memoryId) async {
    final cached = await _getCachedMemoryDetail(memoryId);
    return cached != null;
  }

  /// Delete a memory by ID
  ///
  /// [memoryId] is the UUID of the memory to delete
  ///
  /// Throws an exception if the memory is not found or user doesn't have permission
  Future<void> deleteMemory(String memoryId) async {
    try {
      debugPrint('[MemoryDetailService] Deleting memory: $memoryId');

      // Attempt delete - Supabase will throw an exception if there's a permission issue
      // or if the memory doesn't exist (depending on RLS policies)
      final response =
          await _supabase.from('memories').delete().eq('id', memoryId).select();

      debugPrint(
          '[MemoryDetailService] Delete response: ${response.length} row(s) deleted');

      // If delete succeeded (no exception thrown), clear cache even if response is empty
      // (Some edge cases might return empty response but deletion still succeeds)
      // Clear cache after successful deletion
      await _clearCache(memoryId);
      debugPrint(
          '[MemoryDetailService] Successfully deleted memory and cleared cache: $memoryId');

      // If response is empty, log a warning but don't fail (deletion likely succeeded)
      if (response.isEmpty) {
        debugPrint(
            '[MemoryDetailService] Warning: Delete returned empty response, but no exception was thrown. Assuming success.');
      }
    } catch (e, stackTrace) {
      debugPrint('[MemoryDetailService] Error deleting memory: $e');
      debugPrint('[MemoryDetailService] Stack trace: $stackTrace');
      // Preserve the original error message for better debugging
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to delete memory: $e');
    }
  }

  /// Clear cached memory detail data
  Future<void> _clearCache(String memoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$memoryId';
      await prefs.remove(cacheKey);
      debugPrint('[MemoryDetailService] Cleared cache for memory: $memoryId');
    } catch (e) {
      // Log but don't throw - cache clearing failure shouldn't block deletion
      debugPrint('[MemoryDetailService] Failed to clear cache: $e');
    }
  }

  /// Update memory_date for a memory
  ///
  /// [memoryId] is the UUID of the memory to update
  /// [memoryDate] is the new date/time (null to clear it)
  ///
  /// Throws an exception if the memory is not found or user doesn't have permission
  Future<void> updateMemoryDate(String memoryId, DateTime? memoryDate) async {
    try {
      debugPrint('[MemoryDetailService] Updating memory_date for memory: $memoryId');
      
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      if (memoryDate != null) {
        updateData['memory_date'] = memoryDate.toUtc().toIso8601String();
      } else {
        // Set to null to clear the field
        updateData['memory_date'] = null;
      }
      
      await _supabase
          .from('memories')
          .update(updateData)
          .eq('id', memoryId);
      
      // Clear cache so fresh data is fetched next time
      await _clearCache(memoryId);
      
      debugPrint('[MemoryDetailService] Successfully updated memory_date');
    } catch (e) {
      debugPrint('[MemoryDetailService] Error updating memory_date: $e');
      throw Exception('Failed to update memory date: $e');
    }
  }

  /// Create or get a share link for a memory
  ///
  /// [memoryId] is the UUID of the memory to share
  ///
  /// Returns a shareable URL if successful, or null if share link creation fails
  /// This will request/create a public_share_token via a future edge function
  /// For now, returns null if token doesn't exist (backend not ready)
  Future<String?> getShareLink(String memoryId) async {
    try {
      // First check if memory already has a share token
      final memory = await _supabase
          .from('memories')
          .select('public_share_token')
          .eq('id', memoryId)
          .single();

      final existingToken = memory['public_share_token'] as String?;

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

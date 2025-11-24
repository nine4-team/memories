import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/services/local_memory_preview_store.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/offline_queue_to_timeline_adapter.dart';
import 'package:memories/services/preview_index_to_timeline_adapter.dart';

/// Cursor for unified feed pagination
class UnifiedFeedCursor {
  final DateTime? createdAt;
  final String? id;

  const UnifiedFeedCursor({
    this.createdAt,
    this.id,
  });

  bool get isEmpty => createdAt == null && id == null;

  Map<String, dynamic> toParams() {
    if (isEmpty) {
      return {};
    }
    return {
      'p_cursor_created_at': createdAt?.toIso8601String(),
      'p_cursor_id': id,
    };
  }

  /// Create cursor from last item in response
  factory UnifiedFeedCursor.fromTimelineMemory(TimelineMemory moment) {
    return UnifiedFeedCursor(
      createdAt: moment.createdAt,
      id: moment.id,
    );
  }
}

/// Result of fetching a page of unified feed
class UnifiedFeedPageResult {
  final List<TimelineMemory> memories;
  final UnifiedFeedCursor? nextCursor;
  final bool hasMore;

  UnifiedFeedPageResult({
    required this.memories,
    this.nextCursor,
    required this.hasMore,
  });
}

/// Repository for fetching unified feed data
///
/// Handles API calls to the unified feed endpoint, cursor tracking,
/// and exposes typed DTOs (TimelineMemory).
///
/// Phase 2: Integrates preview index and offline queues for offline support.
class UnifiedFeedRepository {
  final SupabaseClient _supabase;
  final OfflineMemoryQueueService _offlineQueueService;
  final LocalMemoryPreviewStore _localPreviewStore;
  static const int _defaultBatchSize = 20;
  static const _allMemoryTypes = {
    MemoryType.story,
    MemoryType.moment,
    MemoryType.memento,
  };

  UnifiedFeedRepository(
    this._supabase,
    this._offlineQueueService,
    this._localPreviewStore,
  );

  /// Fetch a page of unified feed memories
  ///
  /// [cursor] is the pagination cursor (null for first page)
  /// [filters] is the set of memory types to include (empty set or all three means 'all')
  /// [batchSize] is the number of items to fetch (default: 20)
  ///
  /// Returns a [UnifiedFeedPageResult] with memories, next cursor, and hasMore flag
  Future<UnifiedFeedPageResult> fetchPage({
    UnifiedFeedCursor? cursor,
    Set<MemoryType>? filters,
    int batchSize = _defaultBatchSize,
  }) async {
    final effectiveFilters = filters ?? _allMemoryTypes;

    // Determine if we need to fetch all and filter client-side
    final shouldFetchAll = effectiveFilters.length == _allMemoryTypes.length ||
        effectiveFilters.length == 2;

    MemoryType? singleFilter;
    if (!shouldFetchAll && effectiveFilters.length == 1) {
      singleFilter = effectiveFilters.first;
    }

    final params = <String, dynamic>{
      'p_batch_size': batchSize,
      ...cursor?.toParams() ?? {},
    };

    // Add filter parameter
    if (singleFilter != null) {
      params['p_memory_type'] = singleFilter.apiValue;
    } else {
      params['p_memory_type'] = 'all';
    }

    final response =
        await _supabase.rpc('get_unified_timeline_feed', params: params);

    if (response is! List) {
      throw Exception('Invalid response format from get_unified_timeline_feed');
    }

    var memories = response
        .map((json) => TimelineMemory.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter client-side if needed (when 2 types selected or when filtering from 'all')
    if (shouldFetchAll && effectiveFilters.length < _allMemoryTypes.length) {
      final filterSet =
          effectiveFilters.map((t) => t.apiValue.toLowerCase()).toSet();
      memories = memories.where((memory) {
        return filterSet.contains(memory.memoryType.toLowerCase());
      }).toList();
    }

    // Determine next cursor from last item
    UnifiedFeedCursor? nextCursor;
    bool hasMore = false;

    if (memories.isNotEmpty) {
      final lastMemory = memories.last;
      // For client-side filtering, we need to be more conservative about hasMore
      // since we might have filtered out some items
      if (shouldFetchAll && effectiveFilters.length < _allMemoryTypes.length) {
        // If we filtered client-side, we can't be sure if there are more
        // Use the original response length to determine
        hasMore = response.length >= batchSize;
      } else {
        hasMore = memories.length >= batchSize;
      }

      if (hasMore) {
        nextCursor = UnifiedFeedCursor.fromTimelineMemory(lastMemory);
      }
    }

    return UnifiedFeedPageResult(
      memories: memories,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  /// Fetch the complete list of years that contain memories for the current user.
  /// Honors the same memory type filters as the feed.
  Future<List<int>> fetchAvailableYears({Set<MemoryType>? filters}) async {
    final effectiveFilters = filters ?? _allMemoryTypes;
    MemoryType? singleFilter;

    if (effectiveFilters.length == 1) {
      singleFilter = effectiveFilters.first;
    }

    final params = <String, dynamic>{
      'p_memory_type': singleFilter?.apiValue ?? 'all',
    };

    final response =
        await _supabase.rpc('get_unified_timeline_years', params: params);

    if (response is! List) {
      throw Exception(
          'Invalid response format from get_unified_timeline_years');
    }

    final years = response.map((entry) {
      if (entry is int) {
        return entry;
      }
      if (entry is Map<String, dynamic> && entry['year'] != null) {
        return (entry['year'] as num).toInt();
      }
      throw Exception('Unexpected year entry from get_unified_timeline_years');
    }).toList();

    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  /// Fetch queued memories as timeline items
  ///
  /// Converts queued offline memories (moments, mementos, stories) into
  /// TimelineMemory instances for the unified feed.
  Future<List<TimelineMemory>> fetchQueuedMemories({
    Set<MemoryType>? filters,
  }) async {
    final effectiveFilters = filters ?? _allMemoryTypes;

    final results = <TimelineMemory>[];

    // Get all queued memories from unified queue
    final queued = await _offlineQueueService.getAllQueued();
    for (final item in queued) {
      final type = MemoryTypeExtension.fromApiValue(item.memoryType);
      if (effectiveFilters.contains(type)) {
        results.add(OfflineQueueToTimelineAdapter.fromQueuedMemory(item));
      }
    }

    // Phase 1: filter out already-synced queue entries (if any)
    return results.where((m) => m.serverId == null).toList();
  }

  /// Fetch preview-index memories as timeline items
  ///
  /// Reads stored previews from the local preview index and converts them
  /// into TimelineMemory instances for offline timeline rendering.
  Future<List<TimelineMemory>> fetchPreviewIndexMemories({
    Set<MemoryType>? filters,
    int limit = 200,
  }) async {
    final previews = await _localPreviewStore.fetchPreviews(
      filters: filters,
      limit: limit,
    );

    return previews.map(PreviewIndexToTimelineAdapter.fromPreview).toList();
  }

  /// Fetch online page and upsert preview index
  ///
  /// Internal method that fetches from Supabase and updates the preview index
  /// with the results for offline viewing.
  Future<UnifiedFeedPageResult> _fetchOnlinePage({
    UnifiedFeedCursor? cursor,
    Set<MemoryType>? filters,
    int batchSize = _defaultBatchSize,
  }) async {
    final result = await fetchPage(
      cursor: cursor,
      filters: filters,
      batchSize: batchSize,
    );

    // Derive preview rows from online results.
    final previews = result.memories.map((m) {
      // Use displayTitle for preview, or fallback to title
      final titleOrFirstLine = m.displayTitle.isNotEmpty
          ? m.displayTitle
          : (m.snippetText ?? m.title);
      return LocalMemoryPreview(
        serverId: m.serverId ?? m.id,
        memoryType: MemoryTypeExtension.fromApiValue(m.memoryType),
        titleOrFirstLine: titleOrFirstLine,
        capturedAt: m.capturedAt,
        // In Phase 1, RPC results are not considered "locally cached details".
        isDetailCachedLocally: false,
      );
    }).toList();

    await _localPreviewStore.upsertPreviews(previews);

    return result;
  }

  /// Fetch merged feed (online + offline branches)
  ///
  /// Single entry point that merges online RPC + queue + preview index when online,
  /// and merges queue + preview index when offline.
  ///
  /// [isOnline] - Whether the device is currently online
  Future<UnifiedFeedPageResult> fetchMergedFeed({
    UnifiedFeedCursor? cursor,
    Set<MemoryType>? filters,
    int batchSize = _defaultBatchSize,
    required bool isOnline,
  }) async {
    if (!isOnline) {
      // OFFLINE: use preview index + queue only.
      final queued = await fetchQueuedMemories(filters: filters);
      final previews = await fetchPreviewIndexMemories(
        filters: filters,
        // keep a sane upper bound; pagination handled after merge
        limit: batchSize * 3,
      );

      final merged = [...queued, ...previews]
        ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

      final page = merged.take(batchSize).toList();

      return UnifiedFeedPageResult(
        memories: page,
        nextCursor: null, // simple offline pagination (optional to implement)
        hasMore: merged.length > batchSize,
      );
    }

    // ONLINE: fetch from Supabase, then merge in queued + preview index as needed.
    final onlineResult = await _fetchOnlinePage(
      cursor: cursor,
      filters: filters,
      batchSize: batchSize,
    );

    final queued = await fetchQueuedMemories(filters: filters);

    // For Phase 1, it is acceptable to:
    // - show online results + queued; preview index is updated but not required for online rendering.
    final merged = [...onlineResult.memories, ...queued]
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

    // Re-derive pagination over merged list.
    final startIndex =
        0; // keep simple; cursor-based merging can be refined later.
    final page = merged.skip(startIndex).take(batchSize).toList();

    return UnifiedFeedPageResult(
      memories: page,
      nextCursor: onlineResult.nextCursor,
      hasMore: onlineResult.hasMore || merged.length > page.length,
    );
  }
}

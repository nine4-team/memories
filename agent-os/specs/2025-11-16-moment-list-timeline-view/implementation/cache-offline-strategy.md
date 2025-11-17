# Cache & Offline Strategy

## Overview

The timeline feed should support offline reading and graceful degradation when network connectivity is unavailable. This document outlines the caching strategy and offline behavior.

## Caching Layer

### Local Database (Recommended)

Use a local SQLite database (via `sqflite` or similar) to cache timeline data:

**Table Schema:**
```sql
CREATE TABLE cached_timeline_moments (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  text_description TEXT,
  raw_transcript TEXT,
  generated_title TEXT,
  tags TEXT, -- JSON array string
  capture_type TEXT NOT NULL,
  captured_at INTEGER NOT NULL, -- Unix timestamp
  created_at INTEGER NOT NULL,
  year INTEGER NOT NULL,
  season TEXT NOT NULL,
  month INTEGER NOT NULL,
  day INTEGER NOT NULL,
  primary_media TEXT, -- JSON string
  snippet_text TEXT,
  cached_at INTEGER NOT NULL, -- When this record was cached
  cursor_captured_at INTEGER, -- For pagination
  cursor_id TEXT
);

CREATE INDEX idx_cached_timeline_captured_at ON cached_timeline_moments(captured_at DESC);
CREATE INDEX idx_cached_timeline_user_id ON cached_timeline_moments(user_id);
```

### Cache Payload Shape

Store the same payload structure returned by `get_timeline_feed`:
- All fields from the RPC response
- Additional metadata: `cached_at` timestamp
- Cursor information for pagination continuity

### Cache Invalidation

- **Time-based**: Cache expires after 24 hours
- **User-triggered**: Pull-to-refresh invalidates cache
- **Event-based**: New moment created → invalidate cache for affected date ranges

## Offline Behavior

### Timeline Feed

**When Online:**
- Fetch from RPC endpoint
- Update local cache with new data
- Merge with existing cache (upsert by ID)

**When Offline:**
- Read from local cache
- Display cached moments in reverse chronological order
- Show offline banner: "Showing cached moments. Some content may be outdated."
- Disable search (search requires server-side full-text indexing)

### Search Functionality

**When Online:**
- Search queries hit RPC endpoint with `p_search_query` parameter
- Results are not cached (search is dynamic)

**When Offline:**
- Search is **disabled**
- Show message: "Search unavailable offline. Please connect to the internet."
- Hide search bar or show disabled state

### Pull-to-Refresh

**When Online:**
- Fetches latest batch from server
- Updates cache
- Resets infinite scroll cursor

**When Offline:**
- Shows error: "Unable to refresh. Please check your connection."
- Does not clear cache
- Allows retry when connectivity restored

## Cache Management

### Storage Limits

- **Maximum cached moments**: 1000 records per user
- **Eviction policy**: LRU (Least Recently Used)
- **Cleanup**: Remove records older than 30 days on app startup

### Cache Warming

- Pre-fetch first 2-3 batches on app launch (if online)
- Background sync: Periodically refresh cache when app is in foreground and online

### Cache Updates

**Incremental Updates:**
- On pull-to-refresh: Fetch latest batch, merge with cache
- On new moment creation: Insert new moment at top of cache
- On moment update/deletion: Update or remove from cache

**Full Refresh:**
- Triggered by user action (pull-to-refresh)
- Clears cache and re-fetches from beginning

## Implementation Notes

### Flutter Implementation

1. **Service Layer**: Create `TimelineCacheService` to manage local database
2. **Provider**: Use Riverpod provider that:
   - Checks connectivity status
   - Routes to cache or network based on connectivity
   - Merges cache and network results when online
3. **Offline Queue**: Leverage existing `offline_queue_service` for moment creation, but timeline reading uses separate cache

### Connectivity Detection

Use existing `connectivity_service` to:
- Detect online/offline status
- Show appropriate UI states
- Trigger cache refresh when connectivity restored

### Error Handling

**Network Errors:**
- Fall back to cache if available
- Show error banner: "Using cached data. Last updated: [timestamp]"
- Allow manual retry

**Cache Errors:**
- If cache read fails, show empty state with retry option
- Log error for debugging

## Future Enhancements

1. **Background Sync**: Sync cache in background when app is idle
2. **Selective Caching**: Cache only frequently accessed date ranges
3. **Compression**: Compress cached payloads for storage efficiency
4. **Delta Updates**: Fetch only changed moments since last cache update
5. **Search Cache**: Cache recent search queries and results (with expiration)

## Testing Considerations

1. **Offline Mode**: Test with airplane mode enabled
2. **Cache Persistence**: Verify cache survives app restarts
3. **Cache Invalidation**: Test cache refresh scenarios
4. **Storage Limits**: Test eviction when cache exceeds limits
5. **Concurrent Access**: Test cache updates during active scrolling


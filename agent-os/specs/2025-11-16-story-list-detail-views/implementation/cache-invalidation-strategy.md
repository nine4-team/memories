# Cache Invalidation Strategy for Story List & Detail Views

## Overview

This document defines the cache invalidation strategy to ensure Story edits and deletions propagate to the timeline provider without requiring manual refresh.

## Cache Layers

### 1. Timeline Provider State (Riverpod)

**Location:** `lib/providers/timeline_provider.dart`

**State Management:**
- `TimelineFeedState` holds the current list of moments/stories
- `removeMoment()` method provides optimistic updates for deletions
- `refresh()` method reloads the feed from the server

**Invalidation Strategy:**
- **Story Deleted**: Call `removeMoment(storyId)` immediately after successful deletion
- **Story Edited**: Call `refresh()` after successful edit to reload affected items
- **Story Created**: Call `refresh()` after successful creation (or use pull-to-refresh)

### 2. SharedPreferences Cache

**Location:** `lib/services/moment_detail_service.dart`

**Cache Keys:**
- Timeline feed: Not currently cached in SharedPreferences (uses provider state)
- Story detail: `moment_detail_cache_<story_id>`

**Invalidation Strategy:**
- **Story Deleted**: Remove cache key `moment_detail_cache_<story_id>`
- **Story Edited**: Remove cache key `moment_detail_cache_<story_id>` to force refetch
- **Story Created**: No action needed (cache will be created on first detail view)

### 3. Image Cache (TimelineImageCacheService)

**Location:** `lib/providers/timeline_image_cache_provider.dart`

**Cache Behavior:**
- Caches signed URLs for media files
- Auto-expires based on URL expiry time
- No explicit invalidation needed for edits (URLs remain valid)

**Invalidation Strategy:**
- **Story Deleted**: No action needed (images will be cleaned up by storage cleanup)
- **Story Edited (media changed)**: Cache will naturally expire; new URLs fetched on next view

## Implementation Pattern

### Story Deletion Flow

```dart
// 1. Delete from Supabase
await momentDetailService.deleteMoment(storyId);

// 2. Optimistic update to timeline provider
ref.read(timelineFeedNotifierProvider.notifier).removeMoment(storyId);

// 3. Clear detail cache
final prefs = await SharedPreferences.getInstance();
await prefs.remove('moment_detail_cache_$storyId');
```

### Story Edit Flow

```dart
// 1. Update in Supabase
await updateStory(storyId, updates);

// 2. Refresh timeline provider to reload affected item
await ref.read(timelineFeedNotifierProvider.notifier).refresh();

// 3. Clear detail cache to force refetch
final prefs = await SharedPreferences.getInstance();
await prefs.remove('moment_detail_cache_$storyId');
```

### Story Creation Flow

```dart
// 1. Create in Supabase
final newStory = await createStory(storyData);

// 2. Refresh timeline provider to show new item
await ref.read(timelineFeedNotifierProvider.notifier).refresh();

// 3. No cache action needed (detail cache created on first view)
```

## Provider Integration Points

### Timeline Provider Methods

**Existing Methods:**
- `removeMoment(String momentId)` - Removes item from state (optimistic update)
- `refresh({String? searchQuery})` - Reloads feed from server
- `loadInitial({String? searchQuery})` - Loads initial feed

**Usage:**
- Use `removeMoment()` for immediate UI updates on deletion
- Use `refresh()` for edits/creations to ensure data consistency

### Moment Detail Provider

**Location:** `lib/providers/moment_detail_provider.dart`

**Invalidation:**
- Provider automatically refetches when `storyId` changes
- Cache invalidation ensures fresh data on next fetch
- No explicit provider invalidation needed (Riverpod handles it)

## Event-Driven Invalidation (Future Enhancement)

### Potential Implementation

For more sophisticated cache invalidation, consider:

1. **Supabase Realtime Subscriptions**
   - Subscribe to `moments` table changes
   - Invalidate cache on UPDATE/DELETE events
   - Refresh provider state automatically

2. **Event Bus Pattern**
   - Emit events on Story edit/delete
   - Listeners update relevant caches
   - Decouples cache invalidation from business logic

### Current Approach

The current implementation uses **explicit invalidation** at the call site:
- Simple and predictable
- No additional infrastructure needed
- Works well for current scale

## Testing Considerations

### Test Scenarios

1. **Delete Story from Detail View**
   - Verify timeline provider removes item
   - Verify detail cache is cleared
   - Verify navigation returns to timeline

2. **Edit Story from Detail View**
   - Verify timeline provider refreshes
   - Verify detail cache is cleared
   - Verify updated data appears on return

3. **Create Story from Capture**
   - Verify timeline provider refreshes
   - Verify new item appears in list
   - Verify detail view shows correct data

### Mock/Test Helpers

Create test helpers for cache invalidation:
```dart
Future<void> invalidateStoryCache(String storyId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('moment_detail_cache_$storyId');
}

void invalidateTimelineProvider(WidgetRef ref) {
  ref.read(timelineFeedNotifierProvider.notifier).refresh();
}
```

## Performance Considerations

### Batch Operations

For bulk operations (future):
- Batch cache invalidations
- Debounce provider refreshes
- Use optimistic updates where possible

### Network Efficiency

- `refresh()` reloads entire first page (acceptable for current batch size)
- Consider partial updates for large lists (future optimization)
- Cache invalidation is lightweight (SharedPreferences operations)

## Error Handling

### Failed Deletion

If deletion fails:
- Don't call `removeMoment()` (item should remain)
- Don't clear cache (data is still valid)
- Show error to user

### Failed Edit

If edit fails:
- Don't call `refresh()` (data unchanged)
- Don't clear cache (data is still valid)
- Show error to user

### Network Errors

If network fails during refresh:
- Cache remains valid (can show stale data)
- Provider enters error state
- User can retry manually

## Summary

**Current Strategy:**
- **Deletions**: Optimistic update + cache clear
- **Edits**: Provider refresh + cache clear
- **Creations**: Provider refresh only

**Benefits:**
- Simple and predictable
- Immediate UI updates
- No additional infrastructure

**Future Enhancements:**
- Realtime subscriptions for automatic invalidation
- Event bus for decoupled cache management
- Partial updates for better performance


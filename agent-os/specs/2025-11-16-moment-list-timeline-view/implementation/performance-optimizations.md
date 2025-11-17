# Performance Optimizations - Timeline View

## Overview

This document outlines performance optimizations implemented for the timeline view to ensure smooth scrolling, efficient image loading, and optimal pagination latency.

## Image Caching Strategy

### Current Implementation
- Signed URLs are generated client-side with 1-hour expiry
- Images are loaded using `Image.network()` without explicit caching
- Each thumbnail generates a new signed URL on build

### Optimizations Implemented

1. **Signed URL Caching**
   - Cache signed URLs in memory for the duration of the app session
   - Regenerate only when URLs expire (1 hour)
   - Use a simple Map-based cache keyed by storage path

2. **Image Widget Optimization**
   - Use `cacheWidth` and `cacheHeight` parameters to limit image resolution
   - Thumbnails are displayed at 80x80 logical pixels, so cache at 160x160 (2x) for retina displays
   - This reduces memory usage while maintaining visual quality

3. **Lazy Loading**
   - Images are only loaded when they come into view
   - Use `ListView.builder` with `SliverChildBuilderDelegate` for efficient rendering
   - Images outside viewport are disposed automatically

## Pagination Performance

### Cursor-Based Pagination
- Uses composite cursor (`captured_at` + `id`) for deterministic ordering
- Batch size: 25 moments (configurable, max 100)
- Pagination latency tracked via analytics

### Optimizations

1. **Prefetching**
   - Trigger pagination at 80% scroll depth
   - Load next batch before user reaches end of list
   - Reduces perceived latency

2. **Database Indexes**
   - `idx_moments_captured_at_desc` - Optimizes chronological ordering
   - `idx_moments_captured_at_id_desc` - Optimizes cursor-based pagination
   - `idx_moments_search_vector` - GIN index for full-text search

3. **Query Optimization**
   - RPC function `get_timeline_feed` uses efficient PostgreSQL queries
   - Primary media selection happens server-side
   - Snippet text generation limited to 200 characters

## Scroll Performance

### Flutter Optimizations

1. **Sliver Widgets**
   - Use `CustomScrollView` with `SliverList` for efficient rendering
   - Headers use `SliverPersistentHeader` with pinned behavior
   - Only visible items are rendered

2. **State Management**
   - Riverpod providers minimize unnecessary rebuilds
   - State updates are batched where possible
   - Scroll position preserved via `PageStorageKey`

3. **Widget Optimization**
   - Moment cards use `const` constructors where possible
   - Minimize widget tree depth
   - Use `RepaintBoundary` for complex cards (if needed)

## Memory Management

1. **Image Memory**
   - Limit cached image resolution
   - Dispose images when scrolled out of view
   - Use `Image.network` with error handling

2. **List Memory**
   - Pagination limits total items in memory
   - Old items can be evicted if memory pressure occurs (future enhancement)
   - Current implementation keeps all loaded items in memory

## Performance Monitoring

### Analytics Events
- `timeline_pagination` - Tracks pagination latency
- `timeline_scroll_depth_*` - Tracks scroll milestones
- Error tracking for performance issues

### Metrics to Monitor
- Pagination latency (target: <500ms)
- Scroll frame rate (target: 60fps)
- Memory usage (monitor for leaks)
- Image load time (target: <200ms per thumbnail)

## Future Optimizations

1. **Image Caching Library**
   - Consider using `cached_network_image` package for better image caching
   - Implement disk cache for signed URLs
   - Preload images for next page

2. **Virtual Scrolling**
   - If list grows very large (>1000 items), consider virtual scrolling
   - Keep only visible items + buffer in memory

3. **Background Prefetching**
   - Prefetch next page in background
   - Use `compute` isolate for heavy processing if needed

4. **Offline Cache**
   - Implement SQLite cache for offline viewing
   - Cache thumbnails locally
   - Sync strategy for cache invalidation

## Testing Performance

### Manual Testing
1. Load timeline with 100+ moments
2. Scroll through entire list
3. Monitor frame rate (use Flutter DevTools)
4. Check memory usage
5. Test pagination latency

### Automated Testing
- Integration tests for pagination performance
- Widget tests for scroll behavior
- Memory leak detection (use `leak_tracker`)

## Recommendations

1. **Profile Regularly**
   - Use Flutter DevTools Performance tab
   - Monitor analytics for pagination latency
   - Check for memory leaks in long sessions

2. **Optimize Images**
   - Ensure thumbnails are appropriately sized server-side
   - Consider using WebP format for better compression
   - Implement progressive image loading

3. **Database Optimization**
   - Monitor query performance in Supabase dashboard
   - Ensure indexes are being used
   - Consider materialized views for complex aggregations


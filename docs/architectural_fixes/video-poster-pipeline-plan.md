# Video Poster Pipeline Plan

## Context
- Video thumbnails render instantly in the edit screen because the widget can read frames directly from the local file system.
- Timeline and memory detail cards rely on normalized data coming from Supabase (or the offline queue) where only `video_urls` are stored, so they have nothing to display beyond the fallback icon.
- Achieving parity between edit, timeline, and detail views requires treating video posters as first-class media assets that survive offline edits, uploads, and syncs.

## High-Level Plan
1. **Generate posters at capture time** – Whenever a user selects or records a video, extract a representative frame and store the local path alongside the video path in `CaptureState`.
2. **Persist poster metadata in queues** – Serialize poster paths into `QueuedMemory` so offline edits retain the same thumbnail when rendered in the feed.
3. **Upload posters with videos** – When saving (online) or syncing (offline queue), upload the JPEG poster to the photos bucket, store its storage path in a new `video_poster_urls` column, and return it via RPCs.
4. **Propagate poster data to all clients** – Extend models (`PrimaryMedia`, `TimelineMemory`, `MemoryDetail`, adapters) to include `posterUrl`, and update UI widgets to request signed URLs exactly like photos.
5. **Backfill existing content** – Run a server-side job or edge function to generate posters for previously uploaded videos so historical memories benefit without manual edits.

## Implementation Status (as of 2025-12-06)

1. **Capture Layer**
   - [x] Generate poster image when video is picked (uses `VideoThumbnail.thumbnailFile` in `capture_screen.dart` lines 242-259).
   - [x] Store poster file paths in `CaptureState.videoPosterPaths` (verified: `addVideo()` accepts `posterPath` parameter and stores it, line 431-440 in capture_state_provider.dart).

2. **Offline Queue Serialization**
   - [x] Plug poster paths into `QueuedMemory.fromCaptureState` and `copyWithFromCaptureState` (verified: lines 177, 298-301 in queued_memory.dart).
   - [x] Update queue persistence (`toJson` / `fromJson`) to version 4 → existing entries read safely when `videoPosterPaths` is absent (version 4 implemented, handles missing field).

3. **Upload + Schema**
   - [x] Add `video_poster_urls` column (or JSON array) to `memories` along with Supabase RPC updates (`get_timeline_feed`, `get_memory_detail`).
     - ✅ Migration: `supabase/migrations/20251206000000_add_video_poster_urls.sql` (applied: 20251207030746)
     - ✅ Migration: `supabase/migrations/20251206000001_update_memory_detail_for_video_posters.sql` (applied: 20251207030835)
     - ✅ Migration: `supabase/migrations/20251206000002_update_get_primary_media_for_video_posters.sql` (applied: 20251207030815)
     - ✅ Migration: `supabase/migrations/20251206000003_update_timeline_feeds_for_video_posters.sql` (applied: 20251207030816)
   - [x] Extend `MemorySaveService.saveMemory` / `updateMemory` to upload posters and persist the new column (verified: lines 217-222, 249, 571-576, 668).
   - [x] Ensure `MemorySyncService` passes poster metadata when syncing queued memories (verified: `toCaptureState()` includes `videoPosterPaths` on line 218).

4. **Timeline/Detail Rendering**
   - [x] Update `PrimaryMedia`, `TimelineMemory`, `MomentCard`, `MementoCard`, `StoryCard`, and `MediaStrip` to prefer `posterUrl` when `media.isVideo`.
   - [x] Use `TimelineImageCacheService.getSignedUrlForDetailView` for remote posters, falling back to local file paths for offline entries.
     - ✅ Fixed `media_carousel.dart` to handle local `file://` poster URLs vs remote URLs (lines 566-584)
     - ✅ Fixed `media_tray.dart` to display poster images for existing videos instead of placeholder icons (lines 407-425)

5. **Backfill + Monitoring**
   - [ ] Create an Edge Function or Supabase task to generate posters for existing `memories.video_urls` (store results in the new column).
   - [ ] Add logging/metrics to confirm poster upload success and signed URL cache hits in production.

6. **Testing**
   - [ ] Unit tests for queue serialization (version migration) and adapter output.
   - [ ] Integration tests covering: capture → edit → timeline (online/offline) ensuring video thumbnails display without placeholder.

## Verified Fixes (2025-12-06)
- ✅ Backend migrations applied and RPCs updated to return `poster_url` from `video_poster_urls`
- ✅ `updateMemory` properly declares `newVideoPosterUrls` and `posterPath` variables
- ✅ `media_carousel` handles local `file://` poster URLs correctly (checks `isLocal` and `startsWith('file://')`)
- ✅ `media_tray` displays poster images for existing videos using `_posterUrlFuture`
- ✅ `MemorySyncService` passes poster metadata via `QueuedMemory.toCaptureState()`

## Summary

**✅ Fully Implemented:**
- Capture-time poster generation (VideoThumbnail extraction)
- Backend schema and RPCs (migrations applied)
- Upload and persistence in save/update flows
- Offline queue serialization (version 4)
- Sync service poster handling
- UI rendering (carousel, tray, timeline cards) with local/remote handling

**❌ Still Missing:**
- Backfill for existing videos (edge function/task)
- Monitoring/logging for poster uploads
- Unit/integration tests

## Risks / Open Questions
- **Storage costs**: Posters add to the photo bucket footprint; confirm quotas/cleanup policy.
- **Backfill load**: Generating posters for historical videos could be CPU-expensive; consider batching or on-demand generation.
- **Device performance**: Frame extraction needs throttling on low-end devices (cap resolution, reuse cached preview when possible).

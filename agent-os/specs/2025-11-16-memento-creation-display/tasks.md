# Tasks: Memento Creation & Display

## Capture Experience Updates
- [x] 1. Extend the unified capture sheet to hide the manual title field when `captureType = memento`, relying on description/media inputs only.
- [x] 2. Adjust validation so `Save` enables when description text (non-empty) OR at least one photo/video exists for Mementos.
- [x] 3. Ensure switching between memory types preserves current transcript/media/tag state without dropping entries.
- [x] 4. Update Riverpod controllers and state serialization to include memento-specific metadata (tags, location, capture type flag) consistent with Moments.
- [x] 5. Hook Memento saves into the existing deferred upload/offline queue pipeline, including queued/syncing status chips and retry handling.
- [x] 6. Invoke the LLM title-generation edge function for Mementos with `context='memento'`, store `generated_title` + `title_generated_at`, and surface inline edit capability in detail view after save.
- [x] 7. Enforce Moment-level media limits (max 10 photos, 3 videos) with client-side UI feedback and disable add buttons when limits are met.

## Timeline Integration
- [x] 8. Update the unified timeline provider/query to treat Mementos as first-class entries (reverse chronological, date headers, pagination, pull-to-refresh).
- [x] 9. Implement the Memento card presentation using the shared card container: primary thumbnail from first asset, `Memento` badge, generated title fallback, and friendly timestamp identical to Stories.
- [x] 10. Ensure card interactions (tap, skeleton loaders, loading/error states) reuse the same behavior as existing memory types.

## Detail View Parity
- [x] 11. Reuse the Moment detail screen scaffold for Mementos, including app bar, `CustomScrollView`, hero carousel (photos/videos), metadata band, and floating edit/delete pills.
- [x] 12. Wire the detail view to display generated/edited title, markdown description with "Read more", media carousel with pinch-to-zoom and inline video playback, and tags/location rows when data exists.
- [x] 13. Disable related-memory rows until the linking feature ships; hide the section entirely to avoid empty placeholders.
- [x] 14. Hook share/edit/delete actions into the same flows as Moments (share-link generation, edit relaunch of capture sheet, delete confirmation + optimistic removal).

## Data & Storage
- [x] 15. Confirm `memories` table stores all memory types (Moments, Stories, Mementos) with `capture_type` field (`memory_capture_type` enum) differentiating rows. Mementos are filtered via `capture_type = 'memento'` when querying.
- [x] 16. Ensure Supabase Storage uploads, thumbnail generation, and cleanup routines handle Memento assets alongside Moments/Stories.
- [x] 17. Update repositories/DTOs so timeline and detail providers fetch the expanded metadata needed for cards and detail rendering from the unified `memories` table.

## Testing & QA
 - [x] 18. Add widget tests ensuring Save enabling logic works for description-only and media-only Mementos, plus title auto-generation fallbacks.
 - [x] 19. Create integration tests for offline queueing/resume flows covering Mementos (queued state, sync retries, duplicate prevention).
 - [x] 20. Write UI/automation tests for timeline card consistency and detail view parity across Stories, Moments, and Mementos.
 - [x] 21. Verify analytics/telemetry events capture capture mode, media counts, auto-title success/failure, and detail interactions for Mementos.


# Memory title spinner stuck on "Generating title…"

## Summary
- After the recent change that derives the spinner from the processing status plus a `hasGeneratedTitle` flag (which now comes from `generated_title`/`title_generated_at` metadata), some stories never drop the "Generating title…" indicator even when they already have a generated title.
- The problematic story is `e4c13af1-d3fd-4abc-b53e-e0411bbdad21`; on the timeline/detail cards it just shows the spinner forever.

## Reproduction
1. Look at the timeline card or open the detail view for memory `e4c13af1-d3fd-4abc-b53e-e0411bbdad21` while connected to the server.
2. Observe that the title area keeps showing the circular progress indicator and the text "Generating title…" instead of the actual title.

## Expected behavior
- The spinner should only display when `memory_processing_status.state` is `scheduled` or `processing` *and* the record lacks `generated_title` *and* `title_generated_at`. Once either of those fields exists the widget should fall back to the stored title.

## Observed behavior
- The title spinner never goes away despite there being a generated title already in Supabase (and while the memory_processing_status stream still reports `scheduled`/`processing`).

## Recent work/fix attempts
- Added `titleGeneratedAt` to `TimelineMemory`/`MemoryDetail` and a `hasGeneratedTitle` getter so the widget can tell when a generated title actually exists.
- Made `MemoryTitleWithProcessing` consume the new flag instead of checking literal "Untitled…" strings, so spinning now depends on both processing state and JSON metadata.
- Updated `MemoryDetailService` caching plus the `get_memory_detail`, `get_unified_timeline_feed`, and `get_timeline_feed` RPCs to return `title_generated_at` so `hasGeneratedTitle` can be derived from server rows.
- Added `test/widgets/memory_title_with_processing_test.dart` to verify the spinner appears only when processing and no title metadata is present and is suppressed otherwise.

## Investigation hints
- Inspect the `memory_processing_status` row for `memory_id = 'e4c13af1-d3fd-4abc-b53e-e0411bbdad21'`. If it is stuck in `scheduled`/`processing`, determine why it never transitioned to `complete`/`failed` even though `generated_title` exists.
- Confirm the timeline RPC responses (`get_unified_timeline_feed`, `get_timeline_feed`, `get_memory_detail`) are returning a non-null `generated_title` (and ideally `title_generated_at`). Without those fields the new `hasGeneratedTitle` flag stays false.
- Check whether the Supabase worker that writes `title_generated_at` ran for this memory and whether the backend `generated_title` field is non-empty.
- If the processing status can't transition to `complete`, see whether the dispatcher is still retrying or if the status row got left behind in `scheduled`; the spinner logic treats both `scheduled` and `processing` as active.

## Next steps
- Fix the source of data drift (missing `title_generated_at` or stuck processing status) so `hasGeneratedTitle` becomes true for this memory and similar ones.
- Consider re-running the processing job for this story or manually marking the status as `complete` if the title is already published.
- Once the backend data is clean, verify the widget turns off the spinner by watching the story card while the real-time processing stream emits the final state.

## Fix (Dec 7, 2025)
- Updated `dispatch-memory-processing` to inspect the underlying `memories` row before invoking any worker. When a scheduled job already has `title_generated_at` (and, for stories, `processed_text`), the dispatcher now marks the corresponding `memory_processing_status` row as `complete` instead of leaving it stuck in `scheduled`/`processing`.
- The auto-complete update records an `auto_complete_reason = "output_already_present"` metadata flag so we can audit how often we skip redundant work.
- If a job references a memory that no longer exists, the dispatcher now marks it `failed` immediately with a `"Memory not found when dispatching"` error instead of looping forever in `scheduled`.
- After deploying the updated dispatcher, re-run the status stream (or trigger the dispatcher manually) so `e4c13af1-d3fd-4abc-b53e-e0411bbdad21` and similar rows flip to `complete` without additional user intervention. This unblocks the title spinner because the timeline re-fetches once it sees the `complete` transition.
- Follow the companion doc (`story-processing-title-audio-failures-2025-12-07.md`) to ensure the `process-story` edge function fallback remains deployed and requeue any stories that were stuck in `failed` due to the old bundle.

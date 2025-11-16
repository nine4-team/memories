# Specification: Story List & Detail Views

## Goal
Deliver a streamlined Story-only experience that reuses the unified timeline container for browsing while upgrading the Story detail view with consistent controls, a sticky audio player, and polished metadata presentation.

## User Stories
- As a storyteller, I want to skim all of my Stories in one feed so I can quickly jump into the one I want to relive.
- As a returning listener, I want the Story detail page to prioritize audio playback and narrative text so I can listen and read without friction.
- As a memory curator, I need edit and delete controls in predictable spots so I can manage Stories confidently.

## Specific Requirements

**Unified Story Timeline**
- Reuse the existing unified timeline screen and data source, but filter the query/provider to `memory_type = 'story'`.
- Preserve reverse chronological ordering based on `created_at` with the same date headers already implemented for the unified feed.
- Keep batch sizes, skeleton loaders, pull-to-refresh, and error retry patterns identical to the Moment list implementation.
- Ensure navigation keeps Story filter context when users push to detail and return.

**Story Card Presentation**
- Card content limited to title (single line, ellipsized) and friendly timestamp (e.g., “3d ago • Nov 13, 2025”).
- No narrative preview, waveform thumbnail, tags, or related-memory badges; card height should shrink accordingly while retaining tap target minimums.
- Use the same card container styles (padding, shadows, separators) as other unified timeline entries for visual consistency.
- If a Story lacks a title, display “Untitled Story”.

**Timeline Interactions**
- Infinite scroll triggered when the user nears the end of the list; fetch batches aligned with existing timeline behavior (~25 entries or one month window).
- Pull-to-refresh refreshes the newest batch and resets pagination cursors just like the current Moment flow.
- Maintain loading, empty, and error states from the unified timeline; copy for Story-specific empty state should mention recording a Story.

**Story Detail Structure**
- Layout order: title at top, followed by audio player module, then narrative text body.
- Narrative text uses existing rich-text renderer with typography consistent with Moment detail body copy.
- Support long-form text with appropriate scrolling and “read more” handling if the renderer already supports it.

**Sticky Audio Player**
- Audio player should remain visible when the user scrolls; leverage a mini sticky header or anchored module to keep controls accessible.
- Include play/pause, scrubber, elapsed/duration text, and playback speed if already available in the audio component.
- Player uses the same audio engine/plugin defined in the voice story recording flow to ensure feature parity.
- If stickiness cannot be achieved due to platform limits, fall back to a fixed placement between title and narrative without blocking other content.

**Detail Metadata & Actions**
- Share icon placement and visual treatment must match Moment detail (app bar action backed by OS share sheet).
- Metadata rows (timestamp, related items, etc.) should follow the Moment detail ordering and spacing; hide rows with no data.
- Persistent edit and delete pills hover near the lower portion of the screen alongside metadata, mirroring the Moment detail spec.
- Edit opens the existing Story editing experience (same form/editor used today); delete triggers the standard confirmation bottom sheet before removal.

**Accessibility & Localization**
- Friendly timestamps respect locale, providing combined relative + absolute formats.
- Cards and detail controls meet 44px tap target guidelines and include descriptive VoiceOver strings (e.g., “Story titled … recorded on …”).
- Sticky audio player must remain keyboard and screen-reader accessible when focused.

**Data & Sync Considerations**
- Story list API responses should include at minimum id, title, created_at, and the friendly timestamp fields already computed for unified timeline items.
- Detail endpoint must provide narrative text, audio URL, duration, metadata rows (timestamps, related memories), and flags needed by the sticky player.
- Reuse existing caching/state management (Riverpod providers) for timeline pages so that Story filtering does not spawn redundant controllers.
- Ensure that edits or deletions propagate to the Story list provider so cards update or disappear without manual refresh.

## Visual Design
No visual assets provided in `planning/visuals/`.

## Existing Code to Leverage

**Unified timeline implementation (see `agent-os/specs/2025-11-16-moment-list-timeline-view/spec.md`)**
- Provides container layout, batch fetching, skeletons, and date headers; reuse with Story-only filter.

**Moment Detail View patterns (`agent-os/specs/2025-11-16-moment-detail-view/spec.md`)**
- Supplies action pill styling, metadata rows, and share icon placement that should be replicated for Stories.

**Voice Story recording & processing flow (`agent-os/specs/2025-11-16-voice-story-recording-processing/spec.md`)**
- Defines the audio assets and narrative generation logic whose outputs feed the Story detail view and audio player.

## Out of Scope
- Additional Story filters (tags, narrators, media type) or sorting options.
- Narrative previews, waveform thumbnails, or any media badges on Story cards.
- Swipe/long-press actions or bulk operations on the Story list.
- New sharing/export paradigms beyond the existing Share sheet flow.
- Comments, collaboration, or related-memory management from this spec.
- Audio editing, re-recording, or transcript editing inside the detail view.
- Dedicated Story-only timeline component separate from the unified container.
- New metadata types beyond what already exists for Stories.
- Desktop/web layouts beyond the current mobile-first design.
- Analytics instrumentation changes beyond reusing what the timeline/detail flows already emit.

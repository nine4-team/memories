# Specification: Unified Timeline Feed

## Goal
Deliver a single, elegant timeline that blends Stories, Moments, and Mementos into one reverse-chronological experience, honors the scrapbook-like aesthetic of each memory type, and gives users fast filtering while maintaining their sense of time through hierarchical grouping.

## User Stories
- As a parent capturing multiple memory types, I want one feed that shows everything in order so I don’t have to jump between tabs to relive recent life.
- As a nostalgic user browsing older content, I want the list to group entries by year, season, and month so I can jump around without losing context.
- As a returning user, I want the timeline to remember the filter I last used so I can pick up exactly where I left off.
- As a detail-focused user, I want tapping any card to open the full Story/Moment/Memento view without accidental destructive actions on the list itself.

## Experience Overview
- Screen opens on All memories sorted newest-to-oldest by `created_at`.
- A segmented control (All / Stories / Moments / Mementos) sits beneath the page header, updates the list instantly, and persists the last selection in local state.
- Timeline headers follow Year → Season (Winter: Dec–Feb, Spring: Mar–May, Summer: Jun–Aug, Fall: Sep–Nov) → Month. Headers stick while scrolling to anchor the user.
- Each card reuses its memory type’s established layout (story waveform icon, moment media thumbnail, memento object badge) but aligns spacing, typography, and uses a subtle chip indicating the type.
- Infinite scrolling loads ~20 items per request; loading spinners or skeletons appear inline while fetching additional batches.
- Tapping a card navigates to the existing detail screen for that memory type; no inline actions (edit/delete/share) render on cards.

## Functional Requirements

### Feed Structure & Grouping
- Unified dataset interleaves Stories, Moments, and Mementos strictly by their `created_at` timestamp; no type gets pinned or promoted.
- Grouping hierarchy:
  - Year header (e.g., “2025”) spans all seasons until a new year is reached.
  - Season header uses meteorological definitions and appears when the season changes.
  - Month header (e.g., “November”) nests inside the current season.
- Headers stick while scrolling using Flutter slivers, so users always know which year/season/month they are in.

### Filtering & State Memory
- Segmented control uses Flutter `SegmentedButton`/custom widget styled to match the app’s design language.
- Tabs: All, Stories, Moments, Mementos. Each tab filters locally while reusing the same list component.
- Persist last selected tab via Riverpod state or local storage so re-opening the screen restores the previous view.
- No additional filter sheet or modal; selection is instantaneous.

### Card Presentation
- Reuse existing Story, Moment, and Memento card visuals to minimize new design work, but normalize shared properties:
  - Consistent padding, corner radius, shadow, typography scale.
  - Type chip (e.g., “Story”) appears in the metadata row with color-coding aligned to the memory type.
- Story cards: waveform icon + narrative preview (first two lines). Moment cards: lead media thumbnail (photo/video) plus text preview. Memento cards: object photo badge + description snippet.
- Metadata row shows absolute capture date (MMM D, YYYY) and optional duration indicator (Stories with audio length, Moments with video length if relevant).
- No inline actions, swipes, or quick menus on cards.

### Pagination & Loading
- Initial fetch grabs the latest ~20 combined memories ordered by `created_at DESC`.
- Infinite scroll fetches more when the user nears the bottom. Use cursor-based pagination (`created_at`, `id`) to keep ordering deterministic.
- Show inline loader row or skeleton cards while fetching.
- Provide pull-to-refresh to refetch the latest batch and reset pagination.
- When no more items remain, display a gentle “You’ve reached the beginning” message plus CTA to capture a new memory.

### Navigation & Interactions
- Tapping a card pushes the screen for the selected memory type (Story detail, Moment detail, Memento detail). Navigation returns the user to the same scroll offset and tab.
- Scroll position and tab selection should persist through route changes using `ScrollController` + `PageStorageKey`.
- Long-press, swipe, or context menus are out of scope for this release.

### Error & Offline Handling
- If the initial load fails, show a full-screen error with retry and messaging about offline availability.
- During infinite scroll errors, keep already-loaded content visible and display an inline retry pill at the bottom.
- Offline mode displays cached results (if available) and disables pull-to-refresh, with a banner explaining limitations.

## Data & API Requirements
- Backend endpoint queries the unified `memories` table, filtering by `memory_type` (`memory_type_enum` enum) to return Stories, Moments, and Mementos in one feed response with consistent fields:
  - `id`, `memory_type` (`story|moment|memento`), `created_at`
  - Presentation payload (title, `input_text`, `processed_text`, body snippet using display text logic, media metadata, waveform/audio duration, etc.)
  - Grouping atoms: `year`, `season`, `month` derived server-side to keep clients lightweight.
- Filtering parameters allow requesting a single type (e.g., `?memory_type=moment`) or `all` (no filter).
- **Display Text Logic**: Snippet text should prefer `processed_text` (LLM-processed), falling back to `input_text` (raw user text) if `processed_text` is null or empty.
- Pagination uses `cursor` tokens (timestamp + unique id) to avoid duplicates when new items are inserted while scrolling.
- Service should respect Supabase Row-Level Security per user.

## Technical Considerations
- Flutter + Riverpod: create a shared `UnifiedFeedController` that exposes state machines (`loading`, `ready`, `appending`, `error`, `empty`).
- Build composable widgets: `MemoryFeedList`, `MemoryHeader`, `MemoryCard` (type-aware) so future features (search, sorting) can plug in easily.
- Use `SliverAppBar` with `SliverPersistentHeader` for the segmented control and grouping headers.
- Cache media thumbnails using existing caching strategy; refresh signed URLs lazily when expired.
- Analytics hooks: track tab selections, scroll depth, card taps per type, pagination errors.

## Visual Design Notes
- Maintain the scrapbook aesthetic: soft shadows, rounded corners, warm palette.
- Type chip colors align with memory type accent colors.
- Grouping headers use decreasing type scale (Year > Season > Month) with subtle dividers to separate sections.
- Loading skeletons mimic the unified card layout to prevent jumpiness.
- No new visual assets provided; design relies on existing component styles.

## Out of Scope
- Inline edit/delete/share or swipe gestures on feed cards.
- Pinned memories, smart highlights, or custom ordering beyond `created_at`.
- Cross-user or collaborative timeline features.
- Advanced filters (date range, media type) or search (covered by future specs).


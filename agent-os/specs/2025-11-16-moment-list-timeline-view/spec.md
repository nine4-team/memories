# Specification: Moment List & Timeline View

## Goal
Deliver a performant, orientation-friendly timeline that streams a user’s Moments in reverse chronological order, surfaces rich visual cues via a primary thumbnail, and keeps people grounded with hierarchical date groupings plus universal search across their memory corpus.

## User Stories
- As a memory keeper, I want to scroll through my Moments from newest to oldest without manual pagination so I can relive recent events quickly.
- As a nostalgic user, I want to jump back to a specific season or month and still know where I am in time so long scrolling never feels disorienting.
- As a power user, I want to search for a memory by anything I typed or dictated so I can find a Moment even if I forgot the title.

## Experience Overview
- Feed opens on the most recent section with a sticky hierarchy header (Year → Season → Month). As users scroll, headers update to reflect the current context.
- Timeline uses infinite scroll with background prefetching. New batches append seamlessly; when new data is loading, show inline skeleton cards.
- Each card displays the primary media thumbnail (first photo preferred, otherwise best video frame), title, short body preview (description/transcript), capture date, and tag chips when available.
- A persistent search bar sits at the top of the feed (beneath global navigation). Typing triggers debounced full-text queries, replacing the list with search results in the same card layout.
- Tapping any card deep-links to the Moment detail view. Search state is preserved when navigating back so the user can continue where they left off.

## Functional Requirements

### Timeline Structure & Loading
- Reverse chronological ordering by `captured_at`.
- Infinite scroll with fetch batches sized to roughly one month or 25 Moments (whichever boundary comes first). Backend payloads should include grouping metadata so the client can render hierarchy headers without extra computation.
- Section headers: Year (e.g., “2025”), optional Season (Winter/Spring/Summer/Fall, based on hemisphere default), and Month (“November”). When multiple sections share a year, the year header stays sticky until the next year begins.
- While loading additional data, show shimmering placeholders matching card height. If an error occurs, render inline retry controls without breaking already-loaded sections.

### Cards & Content Display
- Primary thumbnail occupies the left third (mobile) or a fixed aspect ratio top panel (tablet). Always choose the first available media asset; if none exist, show a text-only badge.
- Title: single line, ellipsized. If no generated title exists, fall back to "Untitled Moment".
- Body preview: up to two lines, summarizing text using display text logic (prefer `processed_text`, fallback to `input_text`).
- Metadata row: capture date (relative + absolute), tag chips (max 3 visible), and indicators for videos (e.g., duration pill) when the thumbnail is a video frame.
- Accessibility: 44px minimum tap target, VoiceOver labels describing "Moment titled … captured Month Day, Year."

### Search & Filtering
- Search bar accepts free text, debounced at 300 ms. Submit triggers full-text search across: Moment titles, descriptions, transcripts, plus Story/Memento narratives so cross-memory context appears in results (even though cards only represent Moments for this view).
- Search results remain grouped by the same hierarchy when possible; otherwise show a “Search Results” header with subheaders for the original capture period.
- Empty state messaging clarifies whether no Moments exist overall or the query returned nothing, with CTA to clear search.

### Navigation & Interactions
- Tapping a card pushes the Moment detail route. Back navigation returns to the previous scroll offset or preserved search state.
- Pull-to-refresh reloads the latest batch and resets the infinite scroll cursor.
- When the feed reaches the historical end, show a gentle end-of-list message with CTA to capture a new Moment.

### Error & Offline Handling
- If the initial load fails, show a full-page error with retry + offline caching status.
- Offline mode should display cached Moments and disable search, surfacing a banner indicating limited functionality.

## Data & Storage
- Backend API should support cursor-based pagination keyed by `captured_at` + `id` to keep ordering deterministic.
- Responses must include grouping atoms: `year`, `season`, `month`, `day`, plus primary media metadata (URL, type, duration) and snippet text.
- Full-text search can leverage PostgreSQL `tsvector` indexes across titles/descriptions/transcripts. Include rank scores so the client can optionally highlight relevant snippets.
- Tag data should already exist on Moments; payload should deliver trimmed, case-insensitive arrays for rendering.

## Technical Considerations
- Flutter/Riverpod screen backed by a paginated repository; keep scroll state in a `ScrollController` that persists across navigation.
- Use `SliverAppBar` + `SliverPersistentHeader` for sticky hierarchy sections.
- Media thumbnails should rely on cached signed URLs; refresh tokens as needed to avoid expired URLs while scrolling.
- Search results may reuse the same list component with a different data source; ensure state machines clearly differentiate between `Timeline`, `SearchActive`, and `Error/Empty` to avoid flicker.
- Analytics: log scroll depth milestones, search queries (hashed), card taps, and error retries for funnel analysis.

## Visual Design Notes
- Scrapbook-inspired cards with soft shadow, rounded corners, and subdued background to highlight the media.
- Hierarchy headers use typography scales decreasing from Year → Month to signal nesting.
- Search bar matches global input components (rounded rectangle, leading search icon, clear button).
- Skeleton loaders mimic card layout with grey blocks for thumbnail and text lines.

## Existing Code to Leverage
- Investigate any existing feed/timeline widgets within the app (e.g., Stories list). If available, extend common list primitives; otherwise build a reusable “MemoryFeed” component for future Story/Memento timelines.

## Out of Scope
- Editing or deleting Moments directly from the list.
- Inline quick actions (share, favorite) or multi-select.
- Cross-user/shared timelines; this spec focuses on a single user’s Moments.
- Adaptive layouts for desktop/web (mobile + tablet only for now).

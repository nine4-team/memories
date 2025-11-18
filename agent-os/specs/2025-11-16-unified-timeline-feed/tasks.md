# Tasks: Unified Timeline Feed

## 1. Data Layer & API
- [x] 1. Design unified memory query:
   - Combine Stories, Moments, Mementos ordered by `created_at DESC`.
   - Include grouping fields (`year`, `season`, `month`) and presentation payload.
- [x] 2. Implement Supabase RPC / SQL view to return merged feed with cursor pagination.
- [x] 3. Add filter parameter support (`all`, `story`, `moment`, `memento`) while reusing the same ordering + pagination logic.
- [x] 4. Ensure RLS policies protect per-user data and expose only the authenticated user's records.

## 2. Flutter State & Controllers
- [x] 1. Create `UnifiedFeedRepository` to call the backend endpoint, track cursor, and expose typed DTOs.
- [x] 2. Implement Riverpod `UnifiedFeedController` with states: loading, ready, appending, error, empty.
- [x] 3. Persist last-selected tab using `SharedPreferences` or `Hive` and restore on screen init.
- [x] 4. Wire up analytics events for tab switches, card taps (with type), pagination success/failure.

## 3. UI Components
- [x] 1. Build segmented control component matching design system; connect to Riverpod state.
- [x] 2. Create reusable `MemoryHeader` slivers for Year, Season, Month with sticky behavior.
- [x] 3. Compose shared `MemoryCard` wrapper that delegates to type-specific content (Story/Moment/Memento) but shares padding/typography/type chip.
- [x] 4. Implement skeleton loaders mirroring card layout for initial load and pagination.
- [x] 5. Handle empty states (no memories at all, no results for current filter).

## 4. Screen Assembly & Navigation
- [x] 1. Construct the Unified Timeline screen with `CustomScrollView`, segmented control, headers, and cards.
- [x] 2. Integrate infinite scroll triggering additional fetches when near list end.
- [x] 3. Add pull-to-refresh to reload the first page and reset cursors.
- [x] 4. Navigate to respective detail screens on card tap while preserving scroll offset/tab via `PageStorageKey` + `ScrollController`.

## 5. Error, Offline, and QA
- [x] 1. Implement inline error row with retry for pagination failures; full-page error for initial load.
- [x] 2. Add offline banner + cached fallback behavior; disable refresh while offline.
- [x] 3. Write widget and controller tests covering state transitions, tab persistence, and grouping logic.
4. Smoke-test usability: filter switching, grouping accuracy (Year/Season/Month), pagination boundaries, navigation return behavior.


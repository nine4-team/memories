# Tasks: Moment List & Timeline View

## Phase 1 – Backend & Data Foundations
- [x] 1. **Design cursor-based pagination contract**
   - Define API schema with `captured_at` + `id` cursor, batch sizing logic, and grouping metadata (year/season/month).
   - Document request/response format including search params and error codes.
- [x] 2. **Implement timeline feed endpoint**
   - Build Supabase/Postgres RPC or REST endpoint that returns Moments with required grouping atoms and primary media metadata.
   - Ensure results are deterministic, filtered to authenticated user, and respect batch limits.
- [x] 3. **Add full-text search support**
   - Create `tsvector` indexes covering Moment titles, descriptions, transcripts, plus Story/Memento text if available.
   - Extend endpoint to accept search queries, returning ranked results and relevant snippet text.
- [x] 4. **Augment media + tag payloads**
   - Confirm primary media selection logic server-side (first photo else video frame) and include signed URL metadata.
   - Ensure tag arrays are trimmed, case-insensitive, and capped for payload size.
- [x] 5. **Cache & offline strategy**
   - Decide on caching layer (e.g., local database) and shape of cached payloads for offline read + search disablement.

## Phase 2 – Flutter Timeline Experience
- [x] 6. **Screen scaffolding & state management**
   - Create Riverpod providers for timeline data, search state, and pagination cursors.
   - Wire up `ScrollController` with preserved offset and pull-to-refresh handling.
- [x] 7. **Hierarchy headers implementation**
   - Build `SliverPersistentHeader` widgets for Year → Season → Month, ensuring sticky behavior and smooth transitions.
- [x] 8. **Moment card component**
   - Implement reusable card with thumbnail, title, snippet, metadata row, tag chips, and accessibility labels.
   - Handle special cases: text-only badge, video duration pill, missing title fallback.
- [x] 9. **Infinite scroll + skeleton loaders**
   - Hook up lazy loading triggered near list end with inline skeleton placeholders and error retry UI.
- [x] 10. **Search bar + results mode**
    - Add persistent search input with 300 ms debounce, clear control, and state machine to swap between timeline vs. search datasets.
    - Display empty states with call-to-action when no results are found.
- [x] 11. **Navigation + state restoration**
    - Ensure tapping a card deep-links to Moment detail and returning restores scroll/search state.
- [x] 12. **Offline + error surfaces**
    - Display offline banner, disable search when offline, and provide pull-to-refresh / retry actions for failures.

## Phase 3 – QA, Analytics, and Polish
- [x] 13. **Instrumentation & logging**
    - Emit analytics for scroll depth, search queries (hashed), card taps, and errors.
- [x] 14. **Accessibility & localization review**
    - Validate hit areas, VoiceOver strings, and adaptable typography.
- [x] 15. **Testing strategy**
    - Add unit/widget tests for pagination provider, search behavior, and card rendering permutations.
    - Include integration test covering scroll + search + navigation flows.
- [x] 16. **Performance & cache tuning**
    - Profile scroll performance with large media sets, tune image caching, and verify cursor pagination latency.
- [x] 17. **Release checklist**
    - Document feature flags, migration steps, monitoring plan, and rollout strategy.

# Tasks: Story List & Detail Views

## Phase 1 – Data & Backend Alignment
1. **Document Story-only feed contract**
   - Update API docs describing how the unified timeline endpoint filters by `memory_type = 'story'`.
   - Specify required fields (id, title, created_at, friendly timestamp, narrative presence flag) and error semantics.
2. **Ensure timeline query supports Story filter**
   - Add/verify SQL where clauses, indexes, and Supabase RPC parameters for Story-only pagination.
   - Confirm batching, ordering, and RLS rules mirror existing timeline behavior.
3. **Surface Story detail payload fields**
   - Audit Story detail endpoint to ensure it returns narrative text, audio URL, duration, related memories, and timestamps for UI parity.
   - Add any missing fields plus tests/fixtures for sticky audio metadata.
4. **Propagate list updates after edit/delete**
   - Define events or cache invalidation strategy so Story edits/deletions refresh the filtered provider without manual refresh.

## Phase 2 – Flutter Timeline Experience
5. **Create Story filter mode in unified timeline provider**
   - Introduce a filter flag or dedicated provider that reuses pagination state but scopes results to Stories.
   - Persist filter context through navigation so returning from detail restores position.
6. **Implement Story-only card variant**
   - Build card widget showing only title + friendly timestamp, sized consistently with accessibility requirements.
   - Handle untitled Stories and ensure tap targets remain >=44px.
7. **Hook filter mode into screen scaffolding**
   - Add entry point/route that loads the unified timeline in Story mode, reusing headers, skeletons, pull-to-refresh, and error states.
   - Update empty-state copy to encourage recording a Story.

## Phase 3 – Story Detail Enhancements
8. **Refactor detail layout order**
   - Arrange title → audio player → narrative text using existing rich text renderer.
   - Confirm typography, spacing, and read-more affordances match Moment detail.
9. **Implement sticky audio player module**
   - Convert the audio player to a sticky header or anchored panel that stays visible while scrolling.
   - Wire up play/pause, scrubber, duration, and playback speed using the existing audio engine.
10. **Align metadata + action pills with Moment spec**
    - Reuse share icon placement, metadata rows, and edit/delete pill styling from Moment detail.
    - Ensure delete uses the standard confirmation sheet and edit routes to the Story edit form.

## Phase 4 – QA, Accessibility, and Polish
11. **Localization & accessibility pass**
    - Verify friendly timestamps respect locale, VoiceOver strings describe Stories accurately, and sticky player is focusable.
12. **State sync & offline behavior tests**
    - Test pull-to-refresh, pagination, and provider updates when editing/deleting Stories; validate offline states inherit unified timeline behavior.
13. **Widget/integration tests**
    - Add tests for Story card rendering, sticky audio player controls, and Story filter navigation loop (list → detail → list).
14. **Performance & analytics review**
    - Profile list scroll with Story-only data, ensure audio player stickiness doesn’t jank, and confirm existing analytics events fire with Story context.

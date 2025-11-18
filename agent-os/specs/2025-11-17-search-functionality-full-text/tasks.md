# Tasks: Search Functionality (Full Text)

## 1. Align Dependencies & Text Model
- [x] **Confirm Phase 6 migrations status**
  - [x] Ensure `memories` table exists with `memory_type`, `title`, `generated_title`, `input_text`, `processed_text`, and `tags` as defined in `phase-6-text-model-normalization.md`.
  - [x] Update migration status docs to reflect Phase 6 completion for the target environment.
- [x] **Verify app models are aligned**
  - [x] Update `MomentDetail`, `TimelineMoment`, and any other memory models to use `inputText`, `processedText`, and `memoryType` plus a `displayText` getter.
  - [x] Confirm `MemorySaveService` (or equivalent) writes `memory_type` and `input_text` and leaves `processed_text` null on initial save.

## 2. Database: Search Vector & Indexing
- [x] **Design search_vector column**
  - [x] Define a `search_vector tsvector` column on `public.memories` that combines `title`, `generated_title`, `input_text`, `processed_text`, and `tags` with equal weight.
- [x] **Write migration**
  - [x] Add `search_vector` column and create a GIN index (`idx_memories_search_vector`).
  - [x] Implement a BEFORE INSERT/UPDATE trigger to recompute `search_vector` whenever any of the indexed fields change.
  - [x] Ensure all DDL respects existing RLS policies and naming conventions.
- [x] **Add SQL tests / manual checks**
  - [x] Verify that inserts/updates produce a non-null `search_vector` when text/tag fields are populated.

## 3. Backend Search RPC / API
- [x] **Create search function**
  - [x] Implement a Postgres function or Supabase RPC (e.g., `search_memories`) that:
    - [x] Accepts `query`, `page`, `page_size`, and optional `memory_type` filter.
    - [x] Filters rows by authenticated user (`user_id = auth.uid()`).
    - [x] Builds a safe `tsquery` from `query` using `plainto_tsquery` / `phraseto_tsquery`.
    - [x] Orders results by `ts_rank_cd(search_vector, tsquery)` and recency as a tiebreaker.
    - [x] Applies offset/limit and returns `items`, `page`, `page_size`, and a `has_more` flag.
- [x] **Recent searches persistence**
  - [x] Design and migrate a small table or JSON column to store last 5 distinct queries per user.
  - [x] Implement functions or RPCs to:
    - [x] Fetch recent searches.
    - [x] Upsert a new search term (moving duplicates to most recent).
    - [x] Clear history for the current user.
- [x] **Backend validation & logging**
  - [x] Reject empty/whitespace-only queries.
  - [x] Log slow queries and basic search metrics (query length, duration) for tuning.

## 4. Flutter Data Layer & Providers
- [x] **Search repository/service**
  - [x] Implement a Dart service that calls the search RPC, maps responses into memory result models, and exposes pagination helpers.
  - [x] Add methods for fetching, updating, and clearing recent searches.
- [x] **State management (Riverpod)**
  - [x] Create providers for:
    - [x] Current query string and debounced query.
    - [x] Search results list, page/`hasMore` state, loading and error flags.
    - [x] Recent searches list and clear-history action.
  - [x] Ensure providers handle cancellation/ignoring of stale responses when new queries are issued.

## 5. Flutter UI: Global Search Entry
- [x] **Header integration**
  - [x] Embed a search field in the global header component on primary screens with placeholder "Search memories…".
  - [x] Wire up text editing controller with ≈250 ms debounce before triggering provider-backed search.
- [x] **UX behaviours**
  - [x] Show loading indicator and error/empty states inline below the field.
  - [x] When field is focused and query is empty, show recent searches as tappable chips/rows.
  - [x] Support clear button and "Clear recent searches" link that calls the backend and updates UI immediately.
  - [x] Ensure correct focus/keyboard handling and accessibility labels.

## 6. Flutter UI: Results List & Pagination
- [x] **Results list component**
  - [x] Build a reusable results list widget that:
    - [x] Renders title, snippet (from `processedText` or `inputText`), and a badge for `memoryType`.
    - [x] Optionally shows light metadata (date, media indicators) if provided.
  - [x] Implement simple highlighting of matched query terms using spans or styled text.
- [x] **Navigation & pagination**
  - [x] Wire tap on a result to navigate to existing memory detail screens.
  - [x] Add "Load more results" control at list bottom:
    - [x] Disabled while loading.
    - [x] Hidden when `hasMore` is false.

## 7. Testing & QA
- [x] **Backend tests**
  - [x] Add SQL/unit tests (or dev scripts) verifying:
    - [x] `search_vector` includes all five fields and updates on change.
    - [x] Search function honours user scoping and optional `memory_type` filter.
    - [x] Ranking and pagination behave predictably for seeded test data.
- [x] **Flutter tests**
  - [x] Widget tests for:
    - [x] Debounced search behaviour and loading/error states.
    - [x] Recent search history display and clearing.
    - [x] Results list rendering (badges, snippets, highlighting) and pagination.
  - [x] Integration tests:
    - [x] End-to-end flow: create memories of different types → search → open detail.
- [x] **Manual QA**
  - [x] Test on slow networks and low-end devices to validate performance targets.
  - [x] Verify that search results match expectations when querying by title, input text, processed text, and tags.

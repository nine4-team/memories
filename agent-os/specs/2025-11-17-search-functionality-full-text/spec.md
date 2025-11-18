# Specification: Search Functionality (Full Text)

## 1. Goal

Deliver a fast, trustworthy **memory search** experience that lets users instantly retrieve any memory (moment, story, or memento) from a single persistent entry point, using the **normalized text model** (input/processed text and titles) with simple keyword search.

## 2. User Stories

- As a busy parent, I want to search for specific memories by keywords so I can reopen the right story without scrolling endlessly.
- As an adult child archiving family memories, I want to scan all memory types at once so I can cross-reference narratives, photos, and keepsakes.
- As a member of a friend group, I want search results that jump straight to detail views so I can reshare moments when they come up in conversation.

## 3. Scope & Non-Goals

**In scope**
- Full-text search over **memories** (single conceptual model) where `memory_type` is `moment`, `story`, or `memento`.
- Search input and results surface inside the Flutter app.
- Backend data model, indexing strategy, and API to support keyword search on the normalized text model.
- Lightweight per-user recent search history.

**Out of scope (for this release)**
- Semantic search, embeddings, typo tolerance, stemming, or synonym dictionaries.
- Cross-user or collaborative search.
- Offline/local search index on device.
- Voice-initiated search.
- Inline result actions (edit/delete/share) from the search result list.
- Consolidation of Unified Timeline filters into the search UI (timeline remains the owner of advanced filters unless its spec is updated).

## 4. Data Model Alignment (Normalized Text Model)

Search is built on the **normalized memory text model**:

- `memory_type memory_type_enum NOT NULL DEFAULT 'moment'::memory_type_enum`
  - Values: `'moment' | 'story' | 'memento'`.
- `title TEXT`
  - Current display title, user-editable in detail screens.
- `generated_title TEXT`
  - Last LLM-generated title suggestion (audit/debug only).
- `input_text TEXT`
  - Canonical raw user text from capture UI (`CaptureState.inputText`).
- `processed_text TEXT`
  - LLM-processed version of `input_text`.
  - For stories: full narrative text.
  - For moments/mementos: cleaned description text.
- `tags TEXT[]`
  - User-defined tags used for categorization and search.

All memory types are stored in a unified `memories` table; `memory_type` distinguishes moments, stories, and mementos. Search treats them uniformly and uses `memory_type` only for filtering/segmenting results.

## 5. Functional Requirements

### 5.1 Global Search Entry

- **Persistent search field** in the global app header on all primary screens.
- Placeholder: “Search memories…”.
- **Instant (debounced) search**:
  - Debounce keystrokes by ≈250 ms before issuing backend requests.
  - Do not fire a request for empty/whitespace-only input.
- **Inline feedback**:
  - Show loading indicator under the field while a request is in flight.
  - Show clear empty states:
    - Initial: “Start typing to search your memories.”
    - No results: “No memories match your search.”
- **Focus & dismissal**:
  - Retain focus and current query while results update.
  - Dismiss results when:
    - User clears the query, or
    - User navigates to a memory detail screen.
- **Accessibility**:
  - Provide descriptive semantics/labels for the search field and results list for screen readers.

### 5.2 Search Behaviour & Query Language

- **MVP query model**: simple keyword search over the normalized text model only.
- Supported patterns:
  - Single-word and multi-word queries.
  - Quoted phrases.
  - Minus/exclusion terms (e.g., `holiday -work`) if PostgreSQL functions support them cleanly.
- Pre-processing on client:
  - Trim whitespace and collapse repeated spaces.
  - Prevent obviously malformed queries (e.g., extremely long queries, empty quotes).
- Backend:
  - Use PostgreSQL `to_tsvector` and `to_tsquery`/`plainto_tsquery`/`phraseto_tsquery` as appropriate.
  - No stemming, spell correction, or synonym expansion in this release.

### 5.3 Result Presentation

- **Unified result list**:
  - Single relevance-ranked list of memories.
  - Each item shows:
    - `title` (display title).
    - A text snippet built from `processed_text` if present, otherwise `input_text`.
    - Memory type badge: `Story`, `Moment`, or `Memento` derived from `memory_type`.
    - Optional lightweight metadata (e.g., created date, media indicators) when easily available from the query.
- **Highlighting**:
  - Backend returns snippet text with highlighted spans or token offsets for matched terms (implementation detail up to backend).
  - Client renders basic highlighting for matched terms in the snippet.
- **Navigation**:
  - Tapping a result pushes the existing memory detail screen via the app router.
  - No inline edit/delete/share actions in the search results.

### 5.4 Pagination & Performance

- **Pagination**
  - Default page size: **20** results.
  - “Load more” control at the bottom when more results are available.
  - Disable “Load more” while a page request is in flight.
  - Stop requesting when the backend indicates there are no more rows.
- **Performance targets**
  - Median server-side response time \< 600 ms for typical queries on expected dataset size.
  - Client should avoid overlapping requests for the same query+page (cancel or ignore stale responses).
- **Client caching**
  - Cache last successful results for the current query in memory so navigating away and back can rehydrate instantly.

### 5.5 Recent Search History

- Store **last 5 distinct queries per user**.
  - Persisted server-side and scoped by `user_id`.
  - New queries push into history; duplicates move to the most recent position.
- On focus of the search field with an empty query:
  - Show a list of recent searches, most recent first.
  - Selecting a recent term populates the field and immediately triggers search (after debounce).
- Provide a “Clear recent searches” action that wipes history for the current user immediately.
- History is never shared across users; API relies on existing authenticated session.

## 6. Technical Design

### 6.1 Search Vector & Weighting

The search index is built as a single `tsvector` column on `public.memories`:

- Fields included in the vector:
  - `title`
  - `generated_title`
  - `input_text`
  - `processed_text`
  - `tags` (array, concatenated into text for indexing)
- **Weighting**:
  - All five fields use the **same weight**, per Phase 6 decision.
  - This is implemented via uniform `setweight` or by omitting field-specific weighting entirely and relying on a single-weight vector.

High-level definition (illustrative, not literal SQL):
- `search_vector = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(generated_title, '') || ' ' || coalesce(input_text, '') || ' ' || coalesce(processed_text, '') || ' ' || array_to_string(coalesce(tags, '{}'), ' '))`

### 6.2 Indexing Strategy

- Add a `search_vector tsvector` column to `public.memories`.
- Create a GIN index:
  - `CREATE INDEX idx_memories_search_vector ON public.memories USING GIN (search_vector);`
- Keep `search_vector` up to date:
  - Prefer a **BEFORE INSERT/UPDATE trigger** on `memories` that recomputes `search_vector` when any of the indexed fields change.
  - Alternatively, use a periodically refreshed materialized view if needed, but trigger-based maintenance is preferred for MVP simplicity.
- Ensure all operations respect existing RLS policies so users cannot search across other users’ memories.

### 6.3 API Design

Expose a dedicated search RPC or REST endpoint (name to be finalized, e.g. `search_memories`):

- **Request parameters**
  - `query` (string; required, non-empty after trimming).
  - `page` (int; default 1).
  - `page_size` (int; default 20; max 50).
  - Optional filters:
    - `memory_type` (`'moment' | 'story' | 'memento' | 'all'`).
- **Behaviour**
  - Construct a `tsquery` safely from `query`.
  - Filter rows by the authenticated user (e.g., `memories.user_id = auth.uid()`).
  - Apply `memory_type` filter when provided.
  - Rank using `ts_rank_cd(search_vector, tsquery)` (or equivalent) and order by rank desc, then recency as a tiebreaker.
  - Apply offset/limit for pagination.
- **Response shape**
  - `items`: array of result objects:
    - `id`
    - `memory_type`
    - `title`
    - `snippet_text` (built from `processed_text` or `input_text`, trimmed to ~200 chars).
    - `created_at`
    - Optional media flags or counts (if cheap to compute in the same query).
  - `page`
  - `page_size`
  - `has_more` (boolean) or total count (if inexpensive).

### 6.4 Client Integration

- Debounced search:
  - Text field changes update a local query state.
  - After 250 ms of inactivity, fire a search request if the query changed and is non-empty.
- Request management:
  - Cancel or ignore stale responses when a newer request has been issued for the same field.
  - Show loading and error states inline below the search bar.
- Error handling:
  - Network or server errors show a non-blocking error row (“Can’t load results, tap to retry”) without clearing the query.

## 7. Visual Design

- No dedicated visual assets are currently provided.
- Implementation should follow existing app visual language for:
  - Header controls.
  - List items (cards or rows).
  - Empty and error states.

## 8. Dependencies & Interactions

- Depends on:
  - Normalized `memories` schema with `memory_type`, `title`, `generated_title`, `input_text`, `processed_text`, and `tags`.
  - Unified timeline feed using the same text model (for consistent snippets).
- Interacts with:
  - Timeline filters (for messaging only; filtering remains owned by the Unified Timeline spec).
  - Auth/session handling for per-user scoping and recent searches.

## 9. Testing & Metrics

**Testing**
- Unit tests:
  - Backend: search function builds correct `tsquery`, applies user + `memory_type` filters, and ranks predictably.
  - Client: debouncing logic, pagination behaviour, error and empty states.
- Integration tests:
  - Creating memories of different types and verifying they are searchable by terms present in `title`, `input_text`, `processed_text`, and `tags`.
  - Verifying RLS: authenticated user only sees their own memories.

**Metrics / Logging**
- Log slow queries (e.g., >1s) with query text length and approximate result count.
- Track:
  - Search usage (queries per user/day).
  - Zero-result queries (to inform future improvements).
  - Click-through rate from search results to detail views.

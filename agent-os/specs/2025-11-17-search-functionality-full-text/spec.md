# Specification: Search Functionality Full Text

## Goal
Deliver a fast, trustworthy full-text search experience that lets users instantly retrieve Stories, Moments, and Mementos from a single persistent entry point without leaving the current context.

## User Stories
- As a busy parent, I want to search for specific memories by keywords so I can reopen the right story without scrolling endlessly.
- As an adult child archiving family stories, I want to scan all memory types at once so I can cross-reference narratives, photos, and keepsakes.
- As a member of a friend group, I want search results that jump straight to detail views so I can reshare moments when they come up in conversation.

## Specific Requirements

**Global Search Entry**
- Persistent search field anchored in the global header on every screen, optimized for both mobile orientations.
- Debounce keystrokes (≈250ms) before issuing Supabase RPC/REST calls to control query volume.
- Show inline loading state beneath the field and retain the user’s cursor focus while results stream in.
- Provide clear empty-state copy (“Search memories…”) plus accessibility labels for screen readers.
- Hide suggestions when the user dismisses the search or navigates to a detail screen.

**Search Index Construction & Weighting**
- Index titles, `processed_text` (LLM-processed descriptions/narratives), `input_text` (raw user text), and transcripts for all memory tables with PostgreSQL full-text search and type-specific GIN indexes.
- Apply higher weights to titles, then `processed_text`, then `input_text`, then long-form transcript fields; document the weighting constants.
- Ensure indexes respect existing Row-Level Security policies so users see only their own memories.
- Refresh or maintain materialized views (if used) on create/update/delete of Stories, Moments, or Mementos.

**Result Ranking & Presentation**
- Return a unified, relevance-ranked list while also grouping hits by memory type with visible badges (Story/Moment/Memento).
- Display primary title, a text snippet with highlighted query terms, and key metadata such as created date or media count when available.
- Tapping any result opens the native detail screen via existing navigation patterns; no inline actions or contextual menus.
- Provide empty-state guidance when no matches are found, encouraging broader terms.

**Pagination & Performance Guarantees**
- Limit each fetch to 20 records and expose a clearly labeled “Load more results” control that fetches the next page.
- Enforce strict response-time budget (<500ms server-side) via appropriate indexes and query plans; log slow queries for tuning.
- Cache last successful result set client-side to rehydrate instantly if the user toggles away and back.
- Guard against duplicate loads by disabling “Load more” while a request is in flight and stopping when no additional rows remain.

**Query Language & Processing**
- Support simple keyword matching, quoted phrases, and minus/exclusion terms using PostgreSQL’s `plainto_tsquery`/`phraseto_tsquery` utilities.
- Normalize input by trimming whitespace, collapsing double spaces, and escaping reserved characters before sending to the backend.
- Do not attempt stemming, typo correction, or synonym expansion in this release; document as future enhancements.
- Surface validation errors (e.g., unmatched quotes) inline beneath the search bar.

**Recent Search History**
- Persist the last 5 distinct searches per user in Supabase (tied to user_id) and hydrate them when the user focuses the field.
- Provide a clear “Clear recent searches” action that wipes the stored values immediately.
- Never share history across users or devices; rely on authenticated API requests with existing session tokens.

**Filtering Coordination**
- Keep advanced filtering (All/Stories/Moments/Mementos, media filters) owned by the Unified Timeline experience unless that spec is updated explicitly.
- Document in the search UI copy that users can refine results further via the Timeline filters if needed.
- Reevaluate consolidation only if both specs are updated simultaneously; otherwise avoid duplicated filtering surfaces.

## Visual Design
No visual assets provided.

## Existing Code to Leverage

**No existing code identified**
- Current repository contains planning documents only; search UI, API endpoints, and data-layer pieces will be implemented net-new while following platform standards.

## Out of Scope
- Inline result actions such as edit, delete, or quick share.
- Advanced linguistic processing (stemming, typo tolerance, synonyms, semantic ranking).
- Voice-initiated search entry or microphone shortcuts.
- Cross-user or collaborative search surfaces.
- Analytics dashboards or reporting on aggregate search behavior.
- Consolidation of Unified Timeline filters into the search UI unless that separate spec is revised concurrently.
- Offline search or local indexing on device storage.

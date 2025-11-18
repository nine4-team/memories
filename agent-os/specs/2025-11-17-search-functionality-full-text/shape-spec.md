# Spec Shaping: Search Functionality (full-text)

Spec folder: `agent-os/specs/2025-11-17-search-functionality-full-text/`

Short description (from roadmap):

> Implement full-text search across all Stories, Moments, and Mementos using PostgreSQL text search; persistent search bar in app header with instant results.

Purpose
- Capture the minimally sufficient decisions about scope, UX, data model, infra and constraints so we can write the formal spec.

Scope (what this shaping run will address)
- Search types: simple keyword/full-text search across **memories of all types** (where `memory_type` is `moment` / `story` / `memento`), using the normalized text model from Phase 6:
  - `title` (current display title)
  - `generated_title`
  - `input_text` (raw user text)
  - `processed_text` (LLM-processed narrative/description, where available)
  - `tags`
- UI: persistent search bar in top app header, typed query + instant suggestions (recent queries / top matches), and a results surface with result-type badges (Story/Moment/Memento).
- Backend: PostgreSQL full-text indexing strategy (tsvector + GIN), mapping which fields to index and ranking approach.
- Sync/Offline: whether searches should work offline (initial assumption: no — server-side search only), and how results are cached.

Out of scope
- Cross-user/shared search, federated / external data sources, and advanced NLP reranking beyond basic ranking/scoring.

Assumptions & constraints
- We use Supabase (Postgres) as primary DB for full-text search capabilities.
- Mobile app (Flutter) will host a persistent search field in the app header; results should be returned within ~300–600ms for typical queries.
- Minimal acceptable relevance is: exact title matches high, body/content matches next, then metadata (tags, location).

Success metrics
- Time-to-first-result (median) < 600ms
- Query-to-result relevance: at least 80% of top-5 results are relevant in manual spot-check
- UX: user can reach result detail in ≤2 taps from search result

Stakeholders
- Product: roadmap owner
- Frontend: mobile UI engineers
- Backend: Postgres/Supabase infra engineers
- QA: testing search accuracy and perf

Deliverables for formal spec (later)
- DB migration(s) for additional tsvector columns and GIN indexes
- API endpoint(s) for search queries with paging & filters
- Frontend wireframes & component spec for persistent search bar + results screen
- Integration tests for relevance & perf

Clarifying questions (numbered — focused on concrete implementation details)
1. MVP agreement: confirm that MVP is **simple keyword search over the normalized text model only**, with no semantic search, fuzzy matching, or cross-user/global search.
2. Search vector fields and weights (based on Phase 6 + your confirmation):
   - Include `title`, `generated_title`, `input_text`, and `processed_text` **with equal weight**.
   - Include `tags` in the same tsvector with the **same weight** as the other text fields.
   - All other metadata (e.g., location or `memory_type`) are used only for **filtering** or simple boosting, not as full-text fields.
3. Scope of instant suggestions/autocomplete: do we want recent queries and popular suggestions only, or live token-by-token suggestions (more infra cost)?
4. Filters & facets: should users be able to filter results by type (Stories/Moments/Mementos), date range, or media presence (has photos/has audio)? Which filters are required in MVP?
5. Offline expectations: should search work offline (client-side index) or is server-only acceptable for MVP?
6. Privacy & RLS: do we need to enforce row-level security or additional constraints beyond per-user scoping for searches?
7. Result ranking specifics: prefer simple Postgres ranking using ts_rank/ts_rank_cd or do we want to incorporate custom boosting (title > tag > body)?
8. Visual direction: do you have mockups for:
   - the persistent search bar in the header
   - the search results screen (list layout, thumbnails, badges)
   - the instant suggestions UI
   If yes, attach them (PNG, Figma link, or Sketch).

Request for visual assets
- Please attach any existing mockups or screenshots for: search bar in header, results list, suggestion dropdown. If you have a Figma link, share it (wrap the URL in backticks).
- I looked in `planning/visuals/` and found no files; please upload any visuals to `agent-os/specs/2025-11-17-search-functionality-full-text/planning/visuals/` or attach them in your reply.

Initial recommended approach (draft)
- Backend: add `tsvector` columns for search across stories/moments/mementos and maintain via trigger or materialized view; create GIN index on the combined tsvector.
- API: `/search?query=...&type=all|stories|moments|mementos&page=1&page_size=20&filters=...`
- Ranking: use weighted `setweight(to_tsvector(title), 'A') || setweight(to_tsvector(body), 'B')` and `ts_rank_cd` for scoring. Keep configuration simple for MVP.
- Frontend: show instant suggestions (recent queries & top matches) and return a merged result list with type badges and date grouping.

Next actions (what I'll do after you reply)
- Incorporate your answers into `requirements.md` and `planning/` files.
- Draft DB migration(s) and API shape for the formal spec.

Please answer questions 1–8 and attach any visuals; I'll follow up with any clarifying follow-ups after your replies.



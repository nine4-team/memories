# Story List & Detail Views API Contract

## Story-Only Timeline Feed

### Endpoint

**RPC Function:** `get_timeline_feed`

**Access:** Supabase RPC call via authenticated client

### Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `p_cursor_captured_at` | `TIMESTAMPTZ` | No | `NULL` | Cursor timestamp for pagination (from previous response) |
| `p_cursor_id` | `UUID` | No | `NULL` | Cursor ID for pagination (from previous response) |
| `p_batch_size` | `INT` | No | `25` | Number of results per batch (max 100) |
| `p_search_query` | `TEXT` | No | `NULL` | Full-text search query string |
| `p_memory_type` | `TEXT` | No | `NULL` | Filter by memory type: `'story'`, `'moment'`, `'memento'`, or `NULL` for all types |

### Story-Only Filtering

When `p_memory_type = 'story'`:
- The query filters results to only include Stories
- Stories are identified by `memory_type = 'story'` in the unified `memories` table (previously `moments` table)
- All other query behavior (pagination, ordering, RLS) remains identical to the unified timeline

### Response Schema

Each row in the response contains the same fields as the unified timeline feed:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Story/Moment ID |
| `user_id` | `UUID` | Owner user ID |
| `title` | `TEXT` | Story title (may be empty/null for untitled stories) |
| `input_text` | `TEXT` | Raw user text from capture UI (nullable) |
| `processed_text` | `TEXT` | LLM-processed narrative text (nullable, for stories this is the full narrative) |
| `raw_transcript` | `TEXT` | Raw transcript text (nullable) |
| `generated_title` | `TEXT` | Auto-generated title (nullable) |
| `tags` | `TEXT[]` | Array of tags |
| `memory_type` | `TEXT` | Type: `'story'`, `'moment'`, or `'memento'` |
| `captured_at` | `TIMESTAMPTZ` | Capture timestamp (for ordering) |
| `created_at` | `TIMESTAMPTZ` | Record creation timestamp |
| `year` | `INT` | Year extracted from captured_at |
| `season` | `TEXT` | Season: 'Winter', 'Spring', 'Summer', 'Fall' |
| `month` | `INT` | Month (1-12) |
| `day` | `INT` | Day of month |
| `primary_media` | `JSONB` | Primary media object (nullable for Stories) |
| `snippet_text` | `TEXT` | Preview text (max 200 chars, prefers processed_text, falls back to input_text) |
| `next_cursor_captured_at` | `TIMESTAMPTZ` | Cursor for next page (set by client) |
| `next_cursor_id` | `UUID` | Cursor ID for next page (set by client) |

### Story-Specific Fields

For Story-only responses, the following fields are particularly relevant:

- **`title`**: Story title (may be empty/null, display as "Untitled Story" in UI)
- **`generated_title`**: Auto-generated title from narrative processing (preferred for display)
- **`processed_text`**: LLM-processed narrative text (primary content for stories, if available)
- **`input_text`**: Raw user text from capture UI (fallback if processed_text not available)
- **`raw_transcript`**: Original transcript from dictation (for reference/debugging)
- **`memory_type`**: Always `'story'` when filtered
- **`created_at`**: Used for reverse chronological ordering
- **`captured_at`**: Used for cursor-based pagination

### Required Fields for Story Cards

The Story list view requires these minimum fields:
- `id` - For navigation and identification
- `title` or `generated_title` - For card display (fallback to "Untitled Story")
- `created_at` - For friendly timestamp generation
- `memory_type` - To confirm it's a Story

### Narrative Presence Flag

The presence of narrative text can be determined by checking:
- `processed_text IS NOT NULL AND processed_text != ''` - Indicates LLM-processed narrative exists (preferred)
- `input_text IS NOT NULL AND input_text != ''` - Indicates raw user text exists (fallback)
- `raw_transcript IS NOT NULL AND raw_transcript != ''` - Indicates original transcript exists (for reference)

### Error Semantics

| Error Condition | HTTP Status | Description |
|----------------|-------------|-------------|
| Unauthorized | 401 | User not authenticated (no valid JWT) |
| Invalid memory_type | 400 | `p_memory_type` value not in `['story', 'moment', 'memento', NULL]` |
| Invalid batch_size | 400 | `p_batch_size` > 100 |
| Database error | 500 | Internal database error |

### Cursor-Based Pagination

Pagination works identically to the unified timeline:
- Uses `captured_at` + `id` composite cursor
- Reverse chronological ordering (newest first)
- Cursor values come from the last item in the previous response
- Empty result set indicates no more items

### RLS (Row-Level Security)

- Stories are filtered by `user_id = auth.uid()` to ensure users only see their own Stories
- RLS policies mirror existing timeline behavior
- No additional permissions required beyond authenticated user access

## Story Detail Endpoint

### Endpoint

**RPC Function:** `get_memory_detail`

**Access:** Supabase RPC call via authenticated client

**Note:** This function works for all memory types (moment, story, memento). Use `memory_type` field in response to determine the type.

### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `p_memory_id` | `UUID` | Yes | The ID of the memory to fetch (works for any memory type) |

### Response Schema

The response includes all fields needed for Story detail view:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Memory ID |
| `user_id` | `UUID` | Owner user ID |
| `title` | `TEXT` | Memory title (never null, may be empty) |
| `input_text` | `TEXT` | Raw user text from capture UI (nullable) |
| `processed_text` | `TEXT` | LLM-processed narrative text (nullable, for stories this is the full narrative) |
| `generated_title` | `TEXT` | Auto-generated title (nullable) |
| `tags` | `TEXT[]` | Array of tags |
| `memory_type` | `TEXT` | Type: `'story'` for Stories |
| `captured_at` | `TIMESTAMPTZ` | Capture timestamp |
| `created_at` | `TIMESTAMPTZ` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | Last update timestamp (for cache busting) |
| `public_share_token` | `TEXT` | Public share token (nullable, for share links) |
| `location_data` | `JSONB` | Location information (nullable) |
| `photos` | `JSONB[]` | Ordered array of photo objects (nullable) |
| `videos` | `JSONB[]` | Ordered array of video objects (nullable) |
| `related_stories` | `UUID[]` | Array of related Story IDs |
| `related_mementos` | `UUID[]` | Array of related Memento IDs |

### Story-Specific Detail Fields

For Stories, the following fields are critical for the detail view:

- **`processed_text`**: LLM-processed narrative text (primary content for display, preferred)
- **`input_text`**: Raw user text from capture UI (fallback if processed_text not yet available)
- **`generated_title`**: Auto-generated title (preferred display title)
- **`captured_at`**: Used for friendly timestamp display
- **`created_at`**: Used for metadata display
- **`updated_at`**: Used for cache invalidation

**Display Text Logic**: The UI should prefer `processed_text` for display, falling back to `input_text` if `processed_text` is null or empty. For stories, `processed_text` contains the full narrative once LLM processing completes.

### Audio Metadata (Future Enhancement)

For sticky audio player, the following fields will be needed (to be added in future migration):
- `audio_url` - Supabase Storage path to audio file
- `audio_duration` - Duration in seconds
- `audio_path` - Alternative storage path reference

**Note:** Audio metadata fields are included in the `moments`/`memories` table via the `audio_path` column added in the voice processing migration. Stories use the unified table with `memory_type = 'story'`.

### Related Memories

Related Stories and Mementos are fetched from junction tables:
- `story_moments` (for Stories linked to this Story)
- `moment_mementos` (for Mementos linked to this Story)

These relationships are many-to-many and bidirectional.

### Error Handling

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `Unauthorized` | 401 | User not authenticated (no valid JWT) |
| `Not Found` | 404 | Story not found or user doesn't have access |
| `Forbidden` | 403 | User doesn't have permission to view this Story |

## Cache Invalidation Strategy

### Story Edit/Delete Propagation

When a Story is edited or deleted, the timeline provider should be notified to refresh:

1. **Optimistic Updates**: The provider's `removeMemory()` method can be called immediately for deletions
2. **Cache Invalidation**: SharedPreferences cache keys should be cleared for affected Stories
3. **Provider Refresh**: Call `refresh()` on the timeline provider after successful edit/delete operations

### Cache Keys

- Timeline feed cache: `timeline_feed_cache_<user_id>_<memory_type>`
- Story detail cache: `moment_detail_cache_<story_id>`

### Invalidation Triggers

- Story deleted → Remove from timeline provider state + clear detail cache
- Story edited → Refresh timeline provider + invalidate detail cache
- Story created → Refresh timeline provider (pull-to-refresh)


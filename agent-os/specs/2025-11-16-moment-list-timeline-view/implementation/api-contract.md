# Timeline Feed API Contract

## Endpoint

**RPC Function:** `get_timeline_feed`

**Access:** Supabase RPC call via authenticated client

## Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `p_cursor_captured_at` | `TIMESTAMPTZ` | No | `NULL` | Cursor timestamp for pagination (from previous response) |
| `p_cursor_id` | `UUID` | No | `NULL` | Cursor ID for pagination (from previous response) |
| `p_batch_size` | `INT` | No | `25` | Number of results per batch (max 100) |
| `p_search_query` | `TEXT` | No | `NULL` | Full-text search query string |

## Response Schema

Each row in the response contains:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Moment ID |
| `user_id` | `UUID` | Owner user ID |
| `title` | `TEXT` | Moment title |
| `text_description` | `TEXT` | Text description (nullable) |
| `raw_transcript` | `TEXT` | Raw transcript text (nullable) |
| `generated_title` | `TEXT` | Auto-generated title (nullable) |
| `tags` | `TEXT[]` | Array of tags (trimmed, case-insensitive) |
| `capture_type` | `TEXT` | Type: 'moment', 'story', or 'memento' |
| `captured_at` | `TIMESTAMPTZ` | Capture timestamp (for ordering) |
| `created_at` | `TIMESTAMPTZ` | Record creation timestamp |
| `year` | `INT` | Year extracted from captured_at |
| `season` | `TEXT` | Season: 'Winter', 'Spring', 'Summer', 'Fall' |
| `month` | `INT` | Month (1-12) |
| `day` | `INT` | Day of month |
| `primary_media` | `JSONB` | Primary media object (see below) |
| `snippet_text` | `TEXT` | Preview text (max 200 chars, description or transcript) |
| `next_cursor_captured_at` | `TIMESTAMPTZ` | Cursor for next page (set by client) |
| `next_cursor_id` | `UUID` | Cursor ID for next page (set by client) |

### Primary Media Object

```json
{
  "type": "photo" | "video",
  "url": "string (Supabase Storage path)",
  "index": 0
}
```

Or `null` if no media available.

## Cursor-Based Pagination

### First Request
```sql
SELECT * FROM get_timeline_feed(
  p_cursor_captured_at := NULL,
  p_cursor_id := NULL,
  p_batch_size := 25
);
```

### Subsequent Requests
Use the `captured_at` and `id` from the **last row** of the previous response:

```sql
SELECT * FROM get_timeline_feed(
  p_cursor_captured_at := '<last_row_captured_at>',
  p_cursor_id := '<last_row_id>',
  p_batch_size := 25
);
```

### Determining if More Results Exist

If the response contains exactly `p_batch_size` rows, there may be more results. Fetch the next page using the cursor from the last row. If fewer than `p_batch_size` rows are returned, you've reached the end.

## Search Queries

### Basic Search
```sql
SELECT * FROM get_timeline_feed(
  p_search_query := 'beach vacation'
);
```

### Search with Pagination
```sql
SELECT * FROM get_timeline_feed(
  p_cursor_captured_at := '<cursor_timestamp>',
  p_cursor_id := '<cursor_id>',
  p_batch_size := 25,
  p_search_query := 'beach vacation'
);
```

### Search Behavior

- Uses PostgreSQL `plainto_tsquery` for natural language search
- Searches across: title (weight A), description (weight B), transcript (weight C)
- Results are still ordered by `captured_at DESC`
- Empty or whitespace-only queries are ignored (no search filter applied)

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `Unauthorized` | 401 | User not authenticated (no valid JWT) |
| `Invalid batch size` | 400 | Batch size exceeds maximum (100) |

## Batch Sizing Logic

- Default batch size: 25 Moments
- Maximum batch size: 100 Moments
- Recommended: 25-50 for optimal performance
- Batches align with timeline sections (month/season boundaries) when possible, but this is not guaranteed

## Grouping Metadata

The response includes `year`, `season`, `month`, and `day` fields to enable client-side hierarchical grouping without additional computation:

- **Year**: Full year (e.g., 2025)
- **Season**: Northern Hemisphere seasons (Winter: Dec-Feb, Spring: Mar-May, Summer: Jun-Aug, Fall: Sep-Nov)
- **Month**: 1-12
- **Day**: 1-31

These fields are computed server-side for consistency and performance.

## Tag Payloads

- Tags are returned as `TEXT[]` arrays
- Tags are trimmed and case-insensitive (enforced at insert/update time)
- Empty arrays are returned as `'{}'`
- Maximum tag count per moment: No hard limit, but consider payload size

## Primary Media Selection Logic

1. **First photo** in `photo_urls` array (if available)
2. **First video** in `video_urls` array (if no photos)
3. **`null`** if no media exists

The `primary_media` object includes:
- `type`: "photo" or "video"
- `url`: Supabase Storage path (requires signed URL generation client-side)
- `index`: Array index (always 0 for primary)

## Example Flutter/Dart Usage

```dart
// First page
final response = await supabase.rpc('get_timeline_feed', params: {
  'p_batch_size': 25,
});

// Next page (using cursor from last row)
final lastRow = response.last;
final nextPage = await supabase.rpc('get_timeline_feed', params: {
  'p_cursor_captured_at': lastRow['captured_at'],
  'p_cursor_id': lastRow['id'],
  'p_batch_size': 25,
});

// Search
final searchResults = await supabase.rpc('get_timeline_feed', params: {
  'p_search_query': 'beach',
  'p_batch_size': 25,
});
```


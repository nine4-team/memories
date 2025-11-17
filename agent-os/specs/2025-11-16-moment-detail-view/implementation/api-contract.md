# Moment Detail API Contract

## Endpoint

**RPC Function:** `get_moment_detail`

**Access:** Supabase RPC call via authenticated client

## Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `p_moment_id` | `UUID` | Yes | The ID of the moment to fetch |

## Response Schema

The function returns a single row with the following structure:

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Moment ID |
| `user_id` | `UUID` | Owner user ID |
| `title` | `TEXT` | Moment title (never null, may be empty) |
| `text_description` | `TEXT` | Rich text description (markdown/RTF subset, nullable) |
| `raw_transcript` | `TEXT` | Raw transcript text (nullable) |
| `generated_title` | `TEXT` | Auto-generated title (nullable) |
| `tags` | `TEXT[]` | Array of tags |
| `capture_type` | `TEXT` | Type: 'moment', 'story', or 'memento' |
| `captured_at` | `TIMESTAMPTZ` | Capture timestamp |
| `created_at` | `TIMESTAMPTZ` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | Last update timestamp (for cache busting) |
| `public_share_token` | `TEXT` | Public share token (nullable, for share links) |
| `location_data` | `JSONB` | Location information (see below) |
| `photos` | `JSONB[]` | Ordered array of photo objects (see below) |
| `videos` | `JSONB[]` | Ordered array of video objects (see below) |
| `related_stories` | `UUID[]` | Array of related Story IDs |
| `related_mementos` | `UUID[]` | Array of related Memento IDs |

### Location Data Object

```json
{
  "city": "string (nullable)",
  "state": "string (nullable)",
  "latitude": "number (nullable)",
  "longitude": "number (nullable)",
  "status": "string (nullable, e.g., 'precise', 'approximate', 'denied')"
}
```

Or `null` if no location data exists.

### Photo Object

```json
{
  "url": "string (Supabase Storage path)",
  "index": "integer (0-based position in photo_urls array)",
  "width": "integer (nullable, pixels)",
  "height": "integer (nullable, pixels)",
  "caption": "string (nullable)"
}
```

Photos are ordered by their position in the `photo_urls` array (by `media_position` if available in future schema).

### Video Object

```json
{
  "url": "string (Supabase Storage path)",
  "index": "integer (0-based position in video_urls array)",
  "duration": "number (nullable, seconds)",
  "poster_url": "string (nullable, Supabase Storage path for poster frame)",
  "caption": "string (nullable)"
}
```

Videos are ordered by their position in the `video_urls` array.

## Usage

### Basic Request

```sql
SELECT * FROM get_moment_detail(p_moment_id := '<moment-uuid>');
```

### Flutter/Dart Usage

```dart
final response = await supabase.rpc('get_moment_detail', params: {
  'p_moment_id': momentId,
}).single();
```

## Error Handling

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `Unauthorized` | 401 | User not authenticated (no valid JWT) |
| `Not Found` | 404 | Moment not found or user doesn't have access |
| `Forbidden` | 403 | User doesn't have permission to view this moment |

## Share Token Behavior

- `public_share_token` is `NULL` by default
- Share action requests/creates a token via separate API (future edge function)
- Token is used to generate shareable URLs: `https://app.example.com/share/<token>`
- Token creation is handled separately from detail fetch

## Related Memories

Related Stories and Mementos are fetched from junction tables:
- `story_moments` (for Stories linked to this Moment)
- `moment_mementos` (for Mementos linked to this Moment)

These relationships are many-to-many and bidirectional.

## Media Ordering

Media (photos and videos) are ordered by:
1. Their position in the respective arrays (`photo_urls`, `video_urls`)
2. Array order reflects capture/upload order
3. Future schema may include `media_position` field for explicit ordering

## Signed URL Requirements

- Storage paths returned in `photos` and `videos` arrays are **not** signed URLs
- Client must generate signed URLs using `TimelineImageCacheService` or similar
- Signed URLs should have sufficient expiry for detail view sessions (recommended: 1-2 hours)
- Client should refresh signed URLs when they expire

## Cache Busting

- Use `updated_at` timestamp to determine if cached data is stale
- Client should cache detail responses locally for offline viewing
- When `updated_at` changes, invalidate cache and refetch


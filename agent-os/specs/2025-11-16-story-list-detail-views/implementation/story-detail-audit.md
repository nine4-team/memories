# Story Detail Endpoint Field Audit

## Overview

This document audits the `get_memory_detail` RPC function to ensure it returns all fields required for the Story detail view, including narrative text, audio metadata, related memories, and timestamps.

## Current Endpoint: `get_memory_detail`

**Function:** `get_memory_detail(p_memory_id UUID)`

**Works for:** All memory types (moment, story, memento) via `memory_type` field

## Required Fields for Story Detail View

### ✅ Currently Available Fields

| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | UUID | ✅ Available | Memory ID |
| `user_id` | UUID | ✅ Available | Owner user ID |
| `title` | TEXT | ✅ Available | Memory title (may be empty) |
| `processed_text` | TEXT | ✅ Available | **Processed narrative text** (primary content for stories) |
| `input_text` | TEXT | ✅ Available | **Raw user text** (fallback if processed_text not yet available) |
| `generated_title` | TEXT | ✅ Available | **Auto-generated title** (preferred display title) |
| `tags` | TEXT[] | ✅ Available | Array of tags |
| `memory_type` | TEXT | ✅ Available | Always `'story'` for Stories |
| `captured_at` | TIMESTAMPTZ | ✅ Available | **Capture timestamp** (for friendly timestamp) |
| `created_at` | TIMESTAMPTZ | ✅ Available | **Creation timestamp** (for metadata) |
| `updated_at` | TIMESTAMPTZ | ✅ Available | **Update timestamp** (for cache busting) |
| `public_share_token` | TEXT | ✅ Available | Share token (nullable) |
| `location_data` | JSONB | ✅ Available | Location information (nullable) |
| `photos` | JSONB[] | ✅ Available | Array of photo objects |
| `videos` | JSONB[] | ✅ Available | Array of video objects |
| `related_stories` | UUID[] | ✅ Available | Related Story IDs (currently empty until junction tables exist) |
| `related_mementos` | UUID[] | ✅ Available | Related Memento IDs (currently empty until junction tables exist) |

### ❌ Missing Fields (Future Enhancement)

| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `audio_url` | TEXT | ❌ Missing | Supabase Storage path to audio file |
| `audio_duration` | NUMERIC | ❌ Missing | Duration in seconds |
| `audio_path` | TEXT | ❌ Missing | Alternative storage path reference |

**Note:** Audio fields are not currently in the `moments` table. These will need to be added when:
1. The `stories` table is unified with the timeline feed, OR
2. Audio fields are added to the `moments` table for Stories

## Field Usage in Story Detail View

### Layout Order (per spec)

1. **Title** → Uses `generated_title` (fallback to `title`, then "Untitled Story")
2. **Audio Player** → Requires `audio_url` and `audio_duration` (currently missing)
3. **Narrative Text** → Uses `text_description` (fallback to `raw_transcript`)

### Metadata Rows

- **Timestamp**: Uses `captured_at` for friendly timestamp display
- **Created**: Uses `created_at` for metadata
- **Updated**: Uses `updated_at` for cache invalidation
- **Related Memories**: Uses `related_stories` and `related_mementos` arrays

### Action Pills

- **Edit**: Routes to Story edit form (uses `id`)
- **Delete**: Uses `id` for deletion
- **Share**: Uses `public_share_token` if available

## Narrative Text Handling

### Primary Content

The Story detail view prioritizes narrative text:

1. **Preferred**: `text_description` (processed narrative from LLM)
2. **Fallback**: `raw_transcript` (original dictation transcript)
3. **Placeholder**: "Processing your story..." if both are empty/null

### Narrative Presence Flag

The UI can determine narrative presence by checking:
```dart
bool hasNarrative = (textDescription != null && textDescription.isNotEmpty) ||
                    (rawTranscript != null && rawTranscript.isNotEmpty);
```

## Audio Metadata (Future)

### Sticky Audio Player Requirements

When audio fields are added, the sticky audio player will need:

- **`audio_url`**: Supabase Storage path (e.g., `stories/audio/{userId}/{storyId}/{timestamp}.m4a`)
- **`audio_duration`**: Duration in seconds for progress bar
- **`audio_path`**: Alternative path reference (if different from `audio_url`)

### Current Workaround

Until audio fields are available:
- Audio player can be hidden or show placeholder
- Narrative text remains the primary content
- Audio playback can be added in a future phase

## Related Memories

### Current Status

- `related_stories`: Returns empty array (junction tables not yet implemented)
- `related_mementos`: Returns empty array (junction tables not yet implemented)

### Future Implementation

When junction tables are created:
- `story_moments` table will link Stories to Moments
- `moment_mementos` table will link Stories to Mementos
- `get_memory_detail` function will query these tables

## Timestamps

### Display Timestamps

All required timestamps are available:

- **Friendly Timestamp**: `captured_at` (e.g., "3d ago • Nov 13, 2025")
- **Created At**: `created_at` (for metadata display)
- **Updated At**: `updated_at` (for cache invalidation)

### Cache Busting

The `updated_at` field enables cache invalidation:
- Compare cached `updated_at` with current `updated_at`
- If different, invalidate cache and refetch
- Ensures UI shows latest data after edits

## Summary

### ✅ Ready for Implementation

The `get_memory_detail` endpoint provides all fields needed for:
- Title display (with fallbacks)
- Narrative text display (with fallbacks)
- Metadata rows (timestamps, related memories)
- Action pills (edit, delete, share)
- Cache invalidation

### ⚠️ Future Enhancements Needed

The following fields will need to be added for full Story detail functionality:
- `audio_url` - For sticky audio player
- `audio_duration` - For audio progress bar
- `audio_path` - For alternative storage paths

### 📝 Recommendations

1. **Phase 1 (Current)**: Implement Story detail view with narrative text only
2. **Phase 2 (Future)**: Add audio fields to `moments` table or unify with `stories` table
3. **Phase 3 (Future)**: Implement sticky audio player with audio metadata

## Testing Checklist

- [ ] Verify `get_memory_detail` returns all listed fields for Stories
- [ ] Verify `processed_text` contains processed narrative (when available)
- [ ] Verify `input_text` contains raw user text (when available)
- [ ] Verify `generated_title` is preferred over `title` for display
- [ ] Verify `captured_at` is used for friendly timestamp
- [ ] Verify `updated_at` enables cache invalidation
- [ ] Verify `related_stories` and `related_mementos` arrays are returned (even if empty)
- [ ] Document audio field requirements for future implementation


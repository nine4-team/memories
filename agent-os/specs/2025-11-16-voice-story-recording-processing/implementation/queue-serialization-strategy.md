# Queue Serialization & Versioning Strategy

## Overview

Queued stories are persisted locally to survive app restarts, upgrades, and crashes. This document outlines the serialization format and versioning strategy to ensure backward compatibility as the model evolves.

## Storage Backend

**Recommended:** Use `shared_preferences` or `sqflite` for local persistence.

- **shared_preferences**: Simple key-value storage, good for small queues (<100 items)
- **sqflite**: SQLite database, better for larger queues and complex queries

For Phase 1, we'll use `shared_preferences` with JSON serialization, similar to the `QueuedMoment` pattern.

## Serialization Format

### JSON Structure

Each queued story is serialized as a JSON object with the following structure:

```json
{
  "version": 1,
  "localId": "550e8400-e29b-41d4-a716-446655440000",
  "memoryType": "story",
  "rawTranscript": "This is my story transcript...",
  "description": null,
  "audioPath": "/path/to/local/audio.m4a",
  "audioDuration": 45.5,
  "photoPaths": ["/path/to/photo1.jpg", "/path/to/photo2.jpg"],
  "videoPaths": [],
  "tags": ["vacation", "family"],
  "latitude": 37.7749,
  "longitude": -122.4194,
  "locationStatus": "granted",
  "capturedAt": "2025-01-17T13:00:00.000Z",
  "status": "queued",
  "retryCount": 0,
  "createdAt": "2025-01-17T13:00:00.000Z",
  "lastRetryAt": null,
  "serverStoryId": null,
  "errorMessage": null
}
```

### Storage Key Pattern

Stories are stored under keys following this pattern:

```
queued_story_{localId}
```

Example: `queued_story_550e8400-e29b-41d4-a716-446655440000`

### Queue Index

Maintain a separate index list of all queued story IDs:

```
queued_stories_index: ["id1", "id2", "id3"]
```

This allows efficient enumeration without scanning all keys.

## Versioning Strategy

### Version Field

Every serialized story includes a `version` field indicating the model version:

```dart
static const int currentVersion = 1;
```

### Migration Rules

1. **Increment version** when making breaking changes to the model structure
2. **Preserve backward compatibility** by handling older versions in `fromJson()`
3. **Default to version 1** if version field is missing (for legacy data)

### Example Migration Pattern

```dart
factory QueuedStory.fromJson(Map<String, dynamic> json) {
  final version = json['version'] as int? ?? 1;
  
  // Handle version migrations
  switch (version) {
    case 1:
      // Current version - no migration needed
      break;
    case 2:
      // Future version - add migration logic here
      // e.g., rename fields, add defaults, etc.
      break;
    default:
      // Unknown version - attempt to parse with current structure
      // Log warning for monitoring
      break;
  }
  
  return QueuedStory(
    version: version,
    // ... parse fields
  );
}
```

### Breaking vs Non-Breaking Changes

**Non-Breaking Changes** (no version bump needed):
- Adding new optional fields
- Adding new nullable fields with defaults
- Changing internal implementation details

**Breaking Changes** (version bump required):
- Removing fields
- Renaming fields
- Changing field types
- Making required fields optional (or vice versa) without defaults

## Data Durability

### File Path Handling

**Critical:** Audio file paths stored in `audioPath` must be validated on deserialization:

1. Check if file still exists
2. If missing, mark story as `failed` with error message
3. Log for debugging/monitoring

### Media Path Handling

Similarly validate `photoPaths` and `videoPaths`:
- Missing files should be removed from the list
- If all media is missing, still allow sync (transcript + audio may be sufficient)

## Cleanup Strategy

### Completed Stories

Stories with `status: 'completed'` can be removed from the queue after:
- Successful sync confirmed
- Server story ID is set
- No pending retries

### Failed Stories

Stories with `status: 'failed'` should be retained for:
- Manual retry by user
- Automatic retry after app restart (if retryCount < maxRetries)

### Orphaned Files

If a queued story is removed but audio/media files still exist:
- Cleanup can be handled by a separate cleanup service
- Or rely on OS-level temporary file cleanup

## Error Handling

### Deserialization Errors

If `fromJson()` fails:
1. Log error with story ID
2. Skip the story (don't crash)
3. Optionally move to a "corrupted" list for manual review

### Missing Files

If audio/media files are missing:
1. Mark story with appropriate error message
2. Allow user to retry or discard
3. Don't block sync of other stories

## Performance Considerations

### Batch Operations

When syncing multiple stories:
1. Load all queued stories into memory
2. Process in batches (e.g., 5 at a time)
3. Update status after each batch
4. Persist changes incrementally

### Large Queues

For queues with >100 items:
- Consider migrating to `sqflite` for better query performance
- Implement pagination for queue UI
- Add cleanup of old completed items

## Testing Strategy

### Version Migration Tests

Test that:
1. Version 1 stories can be deserialized correctly
2. Future version migrations work as expected
3. Missing version field defaults to version 1

### File Path Tests

Test that:
1. Missing audio files are handled gracefully
2. Missing media files don't block sync
3. Invalid paths are detected and handled

### Persistence Tests

Test that:
1. Stories survive app restarts
2. Stories survive app upgrades
3. Corrupted JSON is handled gracefully


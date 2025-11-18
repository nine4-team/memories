# Story Audio Storage Bucket Structure

## Overview

Story audio files are stored in Supabase Storage with a structured path format that ensures user isolation, organization, and RLS security.

## Bucket Configuration

### Bucket Name: `stories-audio`

**Configuration:**
- **Access Level**: Private (requires authentication)
- **File Size Limit**: 50MB (reasonable for voice recordings)
- **Allowed MIME Types**: `audio/m4a`, `audio/mpeg`, `audio/wav`
- **RLS Policies**: Users can only access their own audio files

## Path Structure

Audio files are stored using the following path pattern:

```
stories/audio/{userId}/{storyId}/{timestamp}.m4a
```

**Example:**
```
stories/audio/550e8400-e29b-41d4-a716-446655440000/123e4567-e89b-12d3-a456-426614174000/1702915200000.m4a
```

### Path Components

- **`stories/audio/`**: Base prefix for all story audio files
- **`{userId}`**: UUID of the authenticated user (from `auth.users.id`)
- **`{storyId}`**: UUID of the story record (from `memories.id` where `capture_type = 'story'`)
- **`{timestamp}`**: Unix timestamp in milliseconds when recording was captured
- **`.m4a`**: File extension (M4A format preferred for iOS compatibility)

## RLS Policies

### Policy: "Users can upload their own story audio"

```sql
CREATE POLICY "Users can upload their own story audio"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

### Policy: "Users can read their own story audio"

```sql
CREATE POLICY "Users can read their own story audio"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

### Policy: "Users can update their own story audio"

```sql
CREATE POLICY "Users can update their own story audio"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

### Policy: "Users can delete their own story audio"

```sql
CREATE POLICY "Users can delete their own story audio"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'stories-audio' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Signed URL Access

For client-side access to audio files, use signed URLs with appropriate expiry:

- **Timeline/List View**: 1 hour expiry
- **Detail View**: 2 hours expiry
- **Audio Player**: 4 hours expiry (for longer playback sessions)

## Storage Path Helper Functions

When implementing the upload service, use helper functions to construct paths:

```dart
String buildStoryAudioPath({
  required String userId,
  required String storyId,
  required DateTime capturedAt,
}) {
  final timestamp = capturedAt.millisecondsSinceEpoch;
  return 'stories/audio/$userId/$storyId/$timestamp.m4a';
}
```

## Migration Notes

This bucket should be created via Supabase Dashboard or CLI before deploying the migration. The RLS policies can be added via SQL migration or Supabase Dashboard.

## Cleanup Strategy

- Audio files are retained even after processing completes (for retry/reprocessing)
- Manual deletion can be triggered from Story detail screen
- Automatic cleanup can be implemented via Edge Function (out of scope for Phase 1)


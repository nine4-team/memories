-- Migration: Remove redundant processing fields from story_fields table
-- Description: Removes processing fields that are now tracked in memory_processing_status table.
--              These fields are redundant and have been deprecated:
--              - processing_started_at (use memory_processing_status.started_at)
--              - processing_completed_at (use memory_processing_status.completed_at)
--              - retry_count (use memory_processing_status.attempts)
--              - processing_error (use memory_processing_status.last_error)
--              - last_retry_at (use memory_processing_status.last_error_at)
--
--              Story-specific fields that remain:
--              - narrative_generated_at (story-specific timestamp)
--              - audio_path (story-specific storage path)
--              - audio_duration (story-specific metadata)

-- Step 1: Drop indexes on redundant columns
DROP INDEX IF EXISTS idx_story_fields_processing_started_at;
DROP INDEX IF EXISTS idx_story_fields_processing_completed_at;
DROP INDEX IF EXISTS idx_story_fields_retry_count;

-- Step 2: Drop redundant columns
ALTER TABLE public.story_fields
  DROP COLUMN IF EXISTS processing_started_at,
  DROP COLUMN IF EXISTS processing_completed_at,
  DROP COLUMN IF EXISTS retry_count,
  DROP COLUMN IF EXISTS processing_error,
  DROP COLUMN IF EXISTS last_retry_at;

-- Step 3: Update table comment to reflect the cleanup
COMMENT ON TABLE public.story_fields IS 'Story-specific extension fields. Contains only story-specific data (narrative_generated_at, audio_path, audio_duration). Processing status, timestamps, errors, and retry counts are tracked in memory_processing_status table.';

-- Step 4: Update remaining column comments
COMMENT ON COLUMN public.story_fields.narrative_generated_at IS 'Timestamp when processed_text (narrative) was generated for this story.';
COMMENT ON COLUMN public.story_fields.audio_path IS 'Supabase Storage path for story audio file.';
COMMENT ON COLUMN public.story_fields.audio_duration IS 'Audio duration in seconds. Stored when audio is uploaded/processed.';


-- Migration: Rename moments table to memories and capture_type enum to memory_capture_type
-- Description: Aligns database terminology with application naming by renaming:
--              - capture_type enum → memory_capture_type
--              - moments table → memories
--              - All related indexes, foreign keys, and RLS policies
--              This is a breaking change - no backwards compatibility maintained.
--
-- ⚠️ DEPRECATED: This migration is superseded by 20251118000000_rename_memory_capture_type_to_memory_type.sql
--                which consolidates Phase 5 and Phase 6 work. Do NOT apply this migration.
--                If already applied, the Phase 6 migration will handle the next steps.

-- Step 1: Rename the enum type
ALTER TYPE capture_type RENAME TO memory_capture_type;

-- Step 2: Update the column default to use the new enum name
-- First, drop the default constraint
ALTER TABLE public.moments 
  ALTER COLUMN capture_type DROP DEFAULT;

-- Re-add the default with the new enum name
ALTER TABLE public.moments 
  ALTER COLUMN capture_type SET DEFAULT 'moment'::memory_capture_type;

-- Step 3: Rename all indexes that reference moments
-- Use DO block to check existence before renaming
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_tags') THEN
    ALTER INDEX idx_moments_tags RENAME TO idx_memories_tags;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_capture_type') THEN
    ALTER INDEX idx_moments_capture_type RENAME TO idx_memories_capture_type;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_title_generated_at') THEN
    ALTER INDEX idx_moments_title_generated_at RENAME TO idx_memories_title_generated_at;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_location') THEN
    ALTER INDEX idx_moments_location RENAME TO idx_memories_location;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_device_timestamp') THEN
    ALTER INDEX idx_moments_device_timestamp RENAME TO idx_memories_device_timestamp;
  END IF;
END $$;
-- Story-specific indexes (added in voice processing migration)
ALTER INDEX IF EXISTS idx_moments_story_status RENAME TO idx_memories_story_status;
ALTER INDEX IF EXISTS idx_moments_processing_started_at RENAME TO idx_memories_processing_started_at;
ALTER INDEX IF EXISTS idx_moments_processing_completed_at RENAME TO idx_memories_processing_completed_at;
ALTER INDEX IF EXISTS idx_moments_story_retry_count RENAME TO idx_memories_story_retry_count;
ALTER INDEX IF EXISTS idx_moments_narrative_generated_at RENAME TO idx_memories_narrative_generated_at;

-- Step 4: Update foreign key references in media_cleanup_queue
-- First drop the foreign key constraint
ALTER TABLE public.media_cleanup_queue 
  DROP CONSTRAINT IF EXISTS media_cleanup_queue_moment_id_fkey;

-- Step 5: Rename the moments table to memories
ALTER TABLE public.moments RENAME TO memories;

-- Step 6: Recreate the foreign key with the new table name
ALTER TABLE public.media_cleanup_queue 
  ADD CONSTRAINT media_cleanup_queue_memory_id_fkey 
  FOREIGN KEY (moment_id) REFERENCES public.memories(id) ON DELETE SET NULL;

-- Step 7: Rename the moment_id column in media_cleanup_queue to memory_id for consistency
-- (Note: This is optional but aligns with the new naming. Keeping moment_id for now to avoid breaking edge functions)
-- ALTER TABLE public.media_cleanup_queue RENAME COLUMN moment_id TO memory_id;

-- Step 8: Update all column comments that reference moments
-- Only comment on columns that exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'raw_transcript') THEN
    COMMENT ON COLUMN public.memories.raw_transcript IS 'Raw transcript text from voice dictation or text input, before any processing';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'generated_title') THEN
    COMMENT ON COLUMN public.memories.generated_title IS 'Auto-generated title from raw_transcript via generate-title edge function';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'title_generated_at') THEN
    COMMENT ON COLUMN public.memories.title_generated_at IS 'Timestamp when generated_title was created';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'tags') THEN
    COMMENT ON COLUMN public.memories.tags IS 'Array of user-defined tags for categorization and search';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'captured_location') THEN
    COMMENT ON COLUMN public.memories.captured_location IS 'PostGIS geography point (WGS84/SRID 4326) representing the location where the memory was captured';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'location_status') THEN
    COMMENT ON COLUMN public.memories.location_status IS 'Status of location capture: precise, approximate, or denied';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'capture_type') THEN
    COMMENT ON COLUMN public.memories.capture_type IS 'Type of memory: moment (standard capture), story (narrative with audio), or memento (curated collection)';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'device_timestamp') THEN
    COMMENT ON COLUMN public.memories.device_timestamp IS 'Device timestamp when capture started (first asset or transcript). Used for auditing drift between device time and server time.';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'metadata_version') THEN
    COMMENT ON COLUMN public.memories.metadata_version IS 'Version of metadata schema used. Incremented when metadata structure changes. Defaults to 1 for existing records.';
  END IF;
END $$;
-- Story-specific column comments (if columns exist from voice processing migration)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'story_status') THEN
    COMMENT ON COLUMN public.memories.story_status IS 'Story processing status: processing (awaiting/undergoing processing), complete (narrative generated), failed (processing error). NULL for non-story memories.';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'narrative_text') THEN
    COMMENT ON COLUMN public.memories.narrative_text IS 'Processed narrative text generated from raw_transcript via LLM. Only populated for stories (capture_type = story).';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'audio_path') THEN
    COMMENT ON COLUMN public.memories.audio_path IS 'Supabase Storage path for audio file (stories/audio/{userId}/{storyId}/{timestamp}.m4a). Only populated for stories.';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'processing_started_at') THEN
    COMMENT ON COLUMN public.memories.processing_started_at IS 'Timestamp when backend processing began for story narrative generation';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'processing_completed_at') THEN
    COMMENT ON COLUMN public.memories.processing_completed_at IS 'Timestamp when backend processing finished (success or failure) for story narrative generation';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'narrative_generated_at') THEN
    COMMENT ON COLUMN public.memories.narrative_generated_at IS 'Timestamp when narrative_text was generated for story';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'retry_count') THEN
    COMMENT ON COLUMN public.memories.retry_count IS 'Number of times story processing has been retried after failure';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'last_retry_at') THEN
    COMMENT ON COLUMN public.memories.last_retry_at IS 'Timestamp of most recent retry attempt for story processing';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'memories' AND column_name = 'processing_error') THEN
    COMMENT ON COLUMN public.memories.processing_error IS 'Error message or context if story processing failed';
  END IF;
END $$;

-- Step 9: Update RLS policy names and references
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can view their own moments" ON public.memories;

-- Create new policy with updated name
CREATE POLICY "Users can view their own memories"
  ON public.memories
  FOR SELECT
  USING (auth.uid() = user_id);

-- Ensure RLS is enabled
ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;

-- Step 10: Update media_cleanup_queue comment
COMMENT ON COLUMN public.media_cleanup_queue.moment_id IS 'Reference to the memory that owned this media (nullable, set to NULL if memory is deleted)';

-- Step 11: Update any database functions that reference the moments table
-- Note: Functions like get_moment_detail, get_timeline_feed, and get_unified_timeline_feed
-- will be updated in their respective migration files or recreated here if needed.
-- The table rename will automatically update function references since PostgreSQL
-- resolves table names at execution time, but we should verify functions still work correctly.


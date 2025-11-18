-- Migration: Align story processing with text normalization
-- Description: Removes narrative_text column and updates story-processing to use processed_text instead.
--              All LLM-processed descriptive or narrative text, regardless of type, lives in processed_text.

-- Step 1: Drop narrative_text column (we use processed_text instead)
ALTER TABLE public.memories
  DROP COLUMN IF EXISTS narrative_text;

-- Step 2: Drop index on narrative_generated_at (we'll use processed_text timestamp tracking instead)
DROP INDEX IF EXISTS idx_memories_narrative_generated_at;

-- Step 3: Update comments to reference processed_text instead of narrative_text
COMMENT ON COLUMN public.memories.story_status IS 'Story processing status: processing (awaiting/undergoing processing), complete (narrative generated), failed (processing error). NULL for non-story memories.';
COMMENT ON COLUMN public.memories.processing_started_at IS 'Timestamp when backend processing began for story narrative generation';
COMMENT ON COLUMN public.memories.processing_completed_at IS 'Timestamp when backend processing finished (success or failure) for story narrative generation';
COMMENT ON COLUMN public.memories.narrative_generated_at IS 'Timestamp when processed_text was generated for story (narrative text lives in processed_text)';
COMMENT ON COLUMN public.memories.audio_path IS 'Supabase Storage path for audio file (stories/audio/{userId}/{storyId}/{timestamp}.m4a). Only populated for stories.';
COMMENT ON COLUMN public.memories.retry_count IS 'Number of times story processing has been retried after failure';
COMMENT ON COLUMN public.memories.last_retry_at IS 'Timestamp of most recent retry attempt for story processing';
COMMENT ON COLUMN public.memories.processing_error IS 'Error message or context if story processing failed';

-- Note: processed_text column comment is already set in the normalize_memory_text_columns migration
-- For stories, processed_text contains the full narrative text generated from input_text/raw_transcript


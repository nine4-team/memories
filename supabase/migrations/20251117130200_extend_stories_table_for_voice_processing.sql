-- Migration: Extend unified memories table for story voice processing
-- Description: Adds story-specific columns for processing status, narrative generation, timestamps, and retry logic
--              to support voice story recording, offline queuing, and backend processing pipeline.
--              Stories are stored in the unified moments/memories table with capture_type = 'story'.

-- Create enum for story processing status
CREATE TYPE story_status AS ENUM ('processing', 'complete', 'failed');

-- Add story-specific columns to unified moments/memories table
-- Note: raw_transcript and title_generated_at already exist from earlier migrations
-- This migration adds story-specific processing columns
ALTER TABLE public.moments
  -- Processing status (defaults to 'processing' for new stories, NULL for non-stories)
  ADD COLUMN IF NOT EXISTS story_status story_status,
  
  -- Processing timestamps (story-specific)
  ADD COLUMN IF NOT EXISTS processing_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS processing_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS narrative_generated_at TIMESTAMPTZ,
  
  -- Narrative text (processed from raw_transcript via LLM, story-specific)
  ADD COLUMN IF NOT EXISTS narrative_text TEXT,
  
  -- Audio storage path (may differ from audio_url during processing, story-specific)
  ADD COLUMN IF NOT EXISTS audio_path TEXT,
  
  -- Retry logic for failed processing (story-specific)
  ADD COLUMN IF NOT EXISTS retry_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_retry_at TIMESTAMPTZ,
  
  -- Error context for failed processing (story-specific)
  ADD COLUMN IF NOT EXISTS processing_error TEXT;

-- Create partial indexes for efficient story-specific querying
-- These indexes only apply to rows where capture_type = 'story'

-- Index on story_status for filtering by processing state (stories only)
CREATE INDEX IF NOT EXISTS idx_moments_story_status 
  ON public.moments(story_status) 
  WHERE capture_type = 'story' AND story_status IN ('processing', 'failed');

-- Index on processing timestamps for monitoring and cleanup (stories only)
CREATE INDEX IF NOT EXISTS idx_moments_processing_started_at 
  ON public.moments(processing_started_at) 
  WHERE capture_type = 'story' AND processing_started_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_moments_processing_completed_at 
  ON public.moments(processing_completed_at) 
  WHERE capture_type = 'story' AND processing_completed_at IS NOT NULL;

-- Index on retry_count for finding stories that need retry
CREATE INDEX IF NOT EXISTS idx_moments_story_retry_count 
  ON public.moments(retry_count) 
  WHERE capture_type = 'story' AND retry_count > 0;

-- Index on narrative_generated_at for stories awaiting narrative generation
CREATE INDEX IF NOT EXISTS idx_moments_narrative_generated_at 
  ON public.moments(narrative_generated_at) 
  WHERE capture_type = 'story' AND narrative_generated_at IS NOT NULL;

-- Ensure updated_at trigger exists (should already exist from moments table creation)
-- The moments table already has an updated_at trigger, so we don't need a separate one

-- Add column comments for clarity
COMMENT ON COLUMN public.moments.story_status IS 'Story processing status: processing (awaiting/undergoing processing), complete (narrative generated), failed (processing error). NULL for non-story memories.';
COMMENT ON COLUMN public.moments.narrative_text IS 'Processed narrative text generated from raw_transcript via LLM. Only populated for stories (capture_type = story).';
COMMENT ON COLUMN public.moments.audio_path IS 'Supabase Storage path for audio file (stories/audio/{userId}/{storyId}/{timestamp}.m4a). Only populated for stories.';
COMMENT ON COLUMN public.moments.processing_started_at IS 'Timestamp when backend processing began for story narrative generation';
COMMENT ON COLUMN public.moments.processing_completed_at IS 'Timestamp when backend processing finished (success or failure) for story narrative generation';
COMMENT ON COLUMN public.moments.narrative_generated_at IS 'Timestamp when narrative_text was generated for story';
COMMENT ON COLUMN public.moments.retry_count IS 'Number of times story processing has been retried after failure';
COMMENT ON COLUMN public.moments.last_retry_at IS 'Timestamp of most recent retry attempt for story processing';
COMMENT ON COLUMN public.moments.processing_error IS 'Error message or context if story processing failed';


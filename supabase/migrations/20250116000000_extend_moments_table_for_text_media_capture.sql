-- Migration: Extend moments table for text and media capture
-- Description: Adds columns for transcripts, generated titles, tags, location capture,
--              and capture type enum to support moment creation with text, media, and metadata.
--              Also creates media_cleanup_queue table for orphaned file cleanup automation.

-- Create enum for capture type
CREATE TYPE capture_type AS ENUM ('moment', 'story', 'memento');

-- Add new columns to moments table
ALTER TABLE public.moments
  -- Raw transcript from voice dictation or text input
  ADD COLUMN IF NOT EXISTS raw_transcript TEXT,
  
  -- Auto-generated title from transcript (via edge function)
  ADD COLUMN IF NOT EXISTS generated_title TEXT,
  
  -- Timestamp when title was generated
  ADD COLUMN IF NOT EXISTS title_generated_at TIMESTAMPTZ,
  
  -- Array of tags for categorization
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
  
  -- PostGIS geography point for location capture (WGS84/SRID 4326)
  ADD COLUMN IF NOT EXISTS captured_location GEOGRAPHY(Point, 4326),
  
  -- Location capture status (e.g., 'precise', 'approximate', 'denied')
  ADD COLUMN IF NOT EXISTS location_status TEXT,
  
  -- Type of capture: moment, story, or memento
  ADD COLUMN IF NOT EXISTS capture_type capture_type NOT NULL DEFAULT 'moment'::capture_type;

-- Create indexes for efficient querying

-- GIN index on tags array for fast tag searches
CREATE INDEX IF NOT EXISTS idx_moments_tags 
  ON public.moments USING GIN (tags);

-- Index on capture_type for filtering by type
CREATE INDEX IF NOT EXISTS idx_moments_capture_type 
  ON public.moments (capture_type);

-- Partial index on title_generated_at for finding moments needing title generation
CREATE INDEX IF NOT EXISTS idx_moments_title_generated_at 
  ON public.moments (title_generated_at) 
  WHERE title_generated_at IS NOT NULL;

-- GiST index on captured_location for spatial queries (only on non-null values)
CREATE INDEX IF NOT EXISTS idx_moments_location 
  ON public.moments USING GiST (captured_location) 
  WHERE captured_location IS NOT NULL;

-- Create media_cleanup_queue table for orphaned file cleanup
CREATE TABLE IF NOT EXISTS public.media_cleanup_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  media_url TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  moment_id UUID REFERENCES public.moments(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  error_message TEXT,
  retry_count INTEGER DEFAULT 0
);

-- Create index on media_cleanup_queue for efficient processing
CREATE INDEX IF NOT EXISTS idx_media_cleanup_queue_status 
  ON public.media_cleanup_queue (status) 
  WHERE status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS idx_media_cleanup_queue_created_at 
  ON public.media_cleanup_queue (created_at);

-- Add column comments for documentation
COMMENT ON COLUMN public.moments.raw_transcript IS 'Raw transcript text from voice dictation or text input, before any processing';
COMMENT ON COLUMN public.moments.generated_title IS 'Auto-generated title from raw_transcript via generate-title edge function';
COMMENT ON COLUMN public.moments.title_generated_at IS 'Timestamp when generated_title was created';
COMMENT ON COLUMN public.moments.tags IS 'Array of user-defined tags for categorization and search';
COMMENT ON COLUMN public.moments.captured_location IS 'PostGIS geography point (WGS84/SRID 4326) representing the location where the moment was captured';
COMMENT ON COLUMN public.moments.location_status IS 'Status of location capture: precise, approximate, or denied';
COMMENT ON COLUMN public.moments.capture_type IS 'Type of capture: moment (standard capture), story (narrative with audio), or memento (curated collection)';

COMMENT ON TABLE public.media_cleanup_queue IS 'Queue for tracking orphaned media files that need to be deleted from Supabase Storage. Processed by cleanup-media edge function.';
COMMENT ON COLUMN public.media_cleanup_queue.media_url IS 'Full URL of the media file in Supabase Storage';
COMMENT ON COLUMN public.media_cleanup_queue.bucket_name IS 'Name of the Supabase Storage bucket containing the file';
COMMENT ON COLUMN public.media_cleanup_queue.file_path IS 'Path within the bucket to the file (e.g., {user_id}/{timestamp}_{index}.{ext})';
COMMENT ON COLUMN public.media_cleanup_queue.moment_id IS 'Reference to the moment that owned this media (nullable, set to NULL if moment is deleted)';
COMMENT ON COLUMN public.media_cleanup_queue.status IS 'Processing status: pending (awaiting cleanup), processing (currently being deleted), completed (successfully deleted), failed (deletion error)';
COMMENT ON COLUMN public.media_cleanup_queue.retry_count IS 'Number of retry attempts for failed deletions (max 3)';

-- Enable Row Level Security on media_cleanup_queue
ALTER TABLE public.media_cleanup_queue ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only service role can access cleanup queue
-- This table is managed by backend edge functions, not directly by users
CREATE POLICY "Service role only for media_cleanup_queue"
  ON public.media_cleanup_queue
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- Note: The cleanup-media edge function uses service role key to bypass RLS
-- Users should not have direct access to this table


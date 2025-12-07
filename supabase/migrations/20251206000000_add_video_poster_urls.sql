-- Migration: Add video_poster_urls column to memories table
-- Description: Adds video_poster_urls column to store poster image URLs for videos.
--              This enables video thumbnails to be displayed in timeline and detail views.

-- Step 1: Add video_poster_urls column to memories table
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS video_poster_urls TEXT[];

COMMENT ON COLUMN public.memories.video_poster_urls IS 
'Array of poster image URLs for videos, aligned with video_urls array. '
'Posters are stored in the memories-photos bucket and used as thumbnails for video media.';

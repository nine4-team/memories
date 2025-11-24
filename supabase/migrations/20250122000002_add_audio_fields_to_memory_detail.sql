-- Migration: Add audio fields to get_memory_detail function
-- Description: Adds audio_path and audio_duration fields to get_memory_detail function
--              for story audio playback support. These fields come from story_fields table.
--              Also adds audio_duration column to story_fields table if it doesn't exist.

-- Step 1: Add audio_duration column to story_fields table if it doesn't exist
ALTER TABLE public.story_fields
  ADD COLUMN IF NOT EXISTS audio_duration NUMERIC;

COMMENT ON COLUMN public.story_fields.audio_duration IS 'Audio duration in seconds. Stored when audio is uploaded/processed.';

-- Step 2: Drop and recreate get_memory_detail function with audio fields
DROP FUNCTION IF EXISTS public.get_memory_detail(UUID);

CREATE OR REPLACE FUNCTION public.get_memory_detail(p_memory_id UUID)
RETURNS TABLE(
  id UUID,
  user_id UUID,
  title TEXT,
  input_text TEXT,
  processed_text TEXT,
  generated_title TEXT,
  tags TEXT[],
  memory_type TEXT,
  captured_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  public_share_token TEXT,
  location_data JSONB,
  photos JSONB[],
  videos JSONB[],
  related_stories UUID[],
  related_mementos UUID[],
  audio_path TEXT,
  audio_duration NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_memory RECORD;
  v_story_fields RECORD;
  v_location_data JSONB;
  v_photos JSONB[] := ARRAY[]::JSONB[];
  v_videos JSONB[] := ARRAY[]::JSONB[];
  v_photo_url TEXT;
  v_video_url TEXT;
  v_photo_index INT := 0;
  v_video_index INT := 0;
  v_audio_path TEXT;
  v_audio_duration NUMERIC;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Fetch the memory record
  SELECT 
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    COALESCE(m.tags, '{}'::TEXT[]) as tags,
    m.memory_type::TEXT,
    COALESCE(m.device_timestamp, m.created_at) as captured_at,
    m.created_at,
    m.updated_at,
    m.captured_location,
    m.location_status,
    m.photo_urls,
    m.video_urls
  INTO v_memory
  FROM public.memories m
  WHERE m.id = p_memory_id
    AND m.user_id = v_user_id;
  
  -- Check if memory was found
  IF v_memory.id IS NULL THEN
    RAISE EXCEPTION 'Not Found: Memory not found or user does not have access';
  END IF;
  
  -- Fetch story_fields if this is a story (for audio_path and audio_duration)
  IF v_memory.memory_type = 'story' THEN
    SELECT sf.audio_path, sf.audio_duration
    INTO v_story_fields
    FROM public.story_fields sf
    WHERE sf.memory_id = p_memory_id;
    
    -- Extract audio fields if story_fields exists
    IF v_story_fields IS NOT NULL THEN
      v_audio_path := v_story_fields.audio_path;
      v_audio_duration := v_story_fields.audio_duration;
    ELSE
      v_audio_path := NULL;
      v_audio_duration := NULL;
    END IF;
  ELSE
    v_audio_path := NULL;
    v_audio_duration := NULL;
  END IF;
  
  -- Build location_data JSONB object
  IF v_memory.captured_location IS NOT NULL THEN
    -- Extract latitude and longitude from PostGIS geography point
    v_location_data := jsonb_build_object(
      'latitude', ST_Y(v_memory.captured_location::geometry)::DOUBLE PRECISION,
      'longitude', ST_X(v_memory.captured_location::geometry)::DOUBLE PRECISION,
      'status', v_memory.location_status
      -- Note: city and state would require reverse geocoding service
      -- For now, returning NULL for these fields as they're not stored
    );
  ELSE
    v_location_data := NULL;
  END IF;
  
  -- Build photos array from photo_urls
  IF v_memory.photo_urls IS NOT NULL AND array_length(v_memory.photo_urls, 1) > 0 THEN
    FOREACH v_photo_url IN ARRAY v_memory.photo_urls
    LOOP
      v_photos := v_photos || jsonb_build_object(
        'url', v_photo_url,
        'index', v_photo_index,
        'width', NULL,
        'height', NULL,
        'caption', NULL
      );
      v_photo_index := v_photo_index + 1;
    END LOOP;
  END IF;
  
  -- Build videos array from video_urls
  IF v_memory.video_urls IS NOT NULL AND array_length(v_memory.video_urls, 1) > 0 THEN
    FOREACH v_video_url IN ARRAY v_memory.video_urls
    LOOP
      v_videos := v_videos || jsonb_build_object(
        'url', v_video_url,
        'index', v_video_index,
        'duration', NULL,
        'poster_url', NULL,
        'caption', NULL
      );
      v_video_index := v_video_index + 1;
    END LOOP;
  END IF;
  
  -- Return the result with audio fields
  RETURN QUERY SELECT
    v_memory.id,
    v_memory.user_id,
    v_memory.title,
    v_memory.input_text,
    v_memory.processed_text,
    v_memory.generated_title,
    v_memory.tags,
    v_memory.memory_type,
    v_memory.captured_at,
    v_memory.created_at,
    v_memory.updated_at,
    NULL::TEXT as public_share_token, -- Not implemented yet
    v_location_data,
    v_photos,
    v_videos,
    ARRAY[]::UUID[] as related_stories, -- Junction tables not created yet
    ARRAY[]::UUID[] as related_mementos, -- Junction tables not created yet
    v_audio_path,
    v_audio_duration
  ;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_memory_detail IS 'Fetches detailed memory data by ID for any memory type (moment, story, memento). Returns all fields needed for memory detail view including photos, videos, location data, related memories, and audio fields for stories.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_memory_detail TO authenticated;


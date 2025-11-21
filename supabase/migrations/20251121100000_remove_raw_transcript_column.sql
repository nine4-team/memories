-- Migration: Remove raw_transcript column from memories table
-- Description: Removes the legacy raw_transcript column as part of Phase 7 cleanup.
--              The normalized text model uses input_text (canonical raw user text) and 
--              processed_text (LLM-processed version). raw_transcript is no longer needed.

-- Step 1: Update get_unified_timeline_feed function to remove raw_transcript
DROP FUNCTION IF EXISTS public.get_unified_timeline_feed(
  p_cursor_created_at TIMESTAMPTZ,
  p_cursor_id UUID,
  p_batch_size INT,
  p_memory_type TEXT
);

CREATE OR REPLACE FUNCTION public.get_unified_timeline_feed(
  p_cursor_created_at TIMESTAMPTZ DEFAULT NULL,
  p_cursor_id UUID DEFAULT NULL,
  p_batch_size INT DEFAULT 20,
  p_memory_type TEXT DEFAULT 'all'
)
RETURNS TABLE (
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
  year INT,
  season TEXT,
  month INT,
  day INT,
  primary_media JSONB,
  snippet_text TEXT,
  next_cursor_created_at TIMESTAMPTZ,
  next_cursor_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_limit_val INT;
  v_memory_type_filter TEXT;
  v_last_row RECORD;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Validate batch size (max 100, default 20 per spec)
  v_limit_val := LEAST(COALESCE(p_batch_size, 20), 100);
  
  -- Validate and normalize memory_type parameter
  -- Accept: 'all', 'story', 'moment', 'memento' (case-insensitive)
  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL; -- NULL means all types
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;
  
  -- Execute unified query combining all memory types from memories table
  -- Order by created_at DESC (as specified in spec) for reverse-chronological order
  RETURN QUERY
  SELECT 
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    COALESCE(m.tags, '{}'::TEXT[]) as tags,
    m.memory_type::TEXT,
    -- Use device_timestamp if available, otherwise fall back to created_at
    COALESCE(m.device_timestamp, m.created_at) as captured_at,
    m.created_at,
    -- Grouping fields derived from created_at (for timeline grouping)
    EXTRACT(YEAR FROM m.created_at)::INT as year,
    public.get_season(m.created_at) as season,
    EXTRACT(MONTH FROM m.created_at)::INT as month,
    EXTRACT(DAY FROM m.created_at)::INT as day,
    -- Primary media for presentation
    public.get_primary_media(m.photo_urls, m.video_urls) as primary_media,
    -- Snippet text for preview (prefer processed_text, fallback to input_text)
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) as snippet_text,
    -- Cursor fields will be set after query execution
    NULL::TIMESTAMPTZ as next_cursor_created_at,
    NULL::UUID as next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    -- Memory type filter (NULL means all types)
    AND (
      v_memory_type_filter IS NULL 
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    -- Cursor-based pagination using created_at and id
    AND (
      p_cursor_created_at IS NULL 
      OR p_cursor_id IS NULL
      OR m.created_at < p_cursor_created_at
      OR (m.created_at = p_cursor_created_at AND m.id < p_cursor_id)
    )
  ORDER BY m.created_at DESC NULLS LAST, m.id DESC
  LIMIT v_limit_val;
  
  -- Note: The next_cursor fields (next_cursor_created_at, next_cursor_id) are set to NULL
  -- The client should extract these from the last row of the response to use as cursors for the next page
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_unified_timeline_feed IS 
'Fetches unified timeline feed combining Stories, Moments, and Mementos ordered by created_at DESC. '
'Supports cursor-based pagination, memory type filtering (all/story/moment/memento), and returns '
'grouping metadata (year, season, month) for timeline organization.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_unified_timeline_feed TO authenticated;

-- Step 2: Update get_timeline_feed function to remove raw_transcript
DROP FUNCTION IF EXISTS public.get_timeline_feed(
  p_cursor_captured_at TIMESTAMPTZ,
  p_cursor_id UUID,
  p_batch_size INT,
  p_search_query TEXT,
  p_memory_type TEXT
);

CREATE OR REPLACE FUNCTION public.get_timeline_feed(
  p_cursor_captured_at TIMESTAMPTZ DEFAULT NULL,
  p_cursor_id UUID DEFAULT NULL,
  p_batch_size INT DEFAULT 25,
  p_search_query TEXT DEFAULT NULL,
  p_memory_type TEXT DEFAULT NULL
)
RETURNS TABLE (
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
  year INT,
  season TEXT,
  month INT,
  day INT,
  primary_media JSONB,
  snippet_text TEXT,
  next_cursor_captured_at TIMESTAMPTZ,
  next_cursor_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_limit_val INT;
  v_memory_type_filter TEXT;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Validate batch size (max 100)
  v_limit_val := LEAST(COALESCE(p_batch_size, 25), 100);
  
  -- Validate memory_type parameter
  IF p_memory_type IS NOT NULL AND p_memory_type NOT IN ('story', 'moment', 'memento') THEN
    RAISE EXCEPTION 'Invalid memory_type: must be story, moment, memento, or NULL';
  END IF;
  
  -- Set memory type filter
  v_memory_type_filter := p_memory_type;
  
  -- Execute query with conditional WHERE clauses
  RETURN QUERY
  SELECT 
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    COALESCE(m.tags, '{}'::TEXT[]) as tags,
    m.memory_type::TEXT,
    m.captured_at,
    m.created_at,
    EXTRACT(YEAR FROM m.captured_at)::INT as year,
    public.get_season(m.captured_at) as season,
    EXTRACT(MONTH FROM m.captured_at)::INT as month,
    EXTRACT(DAY FROM m.captured_at)::INT as day,
    public.get_primary_media(m.photo_urls, m.video_urls) as primary_media,
    -- Snippet text for preview (prefer processed_text, fallback to input_text)
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) as snippet_text,
    NULL::TIMESTAMPTZ as next_cursor_captured_at,
    NULL::UUID as next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    -- Memory type filter
    AND (
      v_memory_type_filter IS NULL 
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    -- Cursor-based pagination
    AND (
      p_cursor_captured_at IS NULL 
      OR p_cursor_id IS NULL
      OR m.captured_at < p_cursor_captured_at
      OR (m.captured_at = p_cursor_captured_at AND m.id < p_cursor_id)
    )
    -- Full-text search (if search_vector column exists)
    AND (
      p_search_query IS NULL 
      OR trim(p_search_query) = ''
      OR (
        EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_schema = 'public' 
          AND table_name = 'memories' 
          AND column_name = 'search_vector'
        )
        AND m.search_vector @@ plainto_tsquery('english', p_search_query)
      )
    )
  ORDER BY m.captured_at DESC NULLS LAST, m.id DESC
  LIMIT v_limit_val;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_timeline_feed IS 'Fetches timeline feed with cursor-based pagination, optional search, and optional memory type filtering (story, moment, memento, or all). Returns unified memory feed with grouping metadata.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_timeline_feed TO authenticated;

-- Step 3: Rename get_moment_detail to get_memory_detail and remove raw_transcript
DROP FUNCTION IF EXISTS public.get_moment_detail(UUID);
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
  related_mementos UUID[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_memory RECORD;
  v_location_data JSONB;
  v_photos JSONB[] := ARRAY[]::JSONB[];
  v_videos JSONB[] := ARRAY[]::JSONB[];
  v_photo_url TEXT;
  v_video_url TEXT;
  v_photo_index INT := 0;
  v_video_index INT := 0;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Fetch the memory record (removed raw_transcript from SELECT)
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
  
  -- Return the result (removed raw_transcript from RETURN QUERY)
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
    ARRAY[]::UUID[] as related_mementos -- Junction tables not created yet
  ;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_memory_detail IS 'Fetches detailed memory data by ID for any memory type (moment, story, memento). Returns all fields needed for memory detail view including photos, videos, location data, and related memories.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_memory_detail TO authenticated;

-- Step 4: Drop the raw_transcript column from memories table
ALTER TABLE public.memories
  DROP COLUMN IF EXISTS raw_transcript;


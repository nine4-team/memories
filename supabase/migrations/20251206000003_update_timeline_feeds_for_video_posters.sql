-- Migration: Update timeline feed functions to use video_poster_urls
-- Description: Updates get_unified_timeline_feed and get_timeline_feed to pass video_poster_urls to get_primary_media

-- Step 1: Update get_unified_timeline_feed function
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
  memory_date TIMESTAMPTZ,
  year INT,
  season TEXT,
  month INT,
  day INT,
  primary_media JSONB,
  snippet_text TEXT,
  memory_location_data JSONB,
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
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Validate batch size (max 100, default 20 per spec)
  v_limit_val := LEAST(COALESCE(p_batch_size, 20), 100);
  
  -- Validate and normalize memory_type parameter
  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL;
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;
  
  -- Execute unified query using COALESCE for effective date
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
    -- Use memory_date if set, otherwise fall back to device_timestamp or created_at
    COALESCE(m.memory_date, m.device_timestamp, m.created_at) as captured_at,
    m.created_at,
    -- Return actual memory_date field (may be NULL)
    m.memory_date,
    -- Grouping fields derived from effective date (memory_date preferred)
    EXTRACT(YEAR FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as year,
    public.get_season(COALESCE(m.memory_date, m.device_timestamp, m.created_at)) as season,
    EXTRACT(MONTH FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as month,
    EXTRACT(DAY FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as day,
    -- Primary media for presentation (now includes poster URLs)
    public.get_primary_media(m.photo_urls, m.video_urls, m.video_poster_urls) as primary_media,
    -- Snippet text for preview
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) as snippet_text,
    -- Memory location data (where event happened)
    m.memory_location_data,
    -- Cursor fields will be set after query execution
    NULL::TIMESTAMPTZ as next_cursor_created_at,
    NULL::UUID as next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    -- Memory type filter
    AND (
      v_memory_type_filter IS NULL 
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    -- Cursor-based pagination using effective date
    AND (
      p_cursor_created_at IS NULL 
      OR p_cursor_id IS NULL
      OR COALESCE(m.memory_date, m.device_timestamp, m.created_at) < p_cursor_created_at
      OR (COALESCE(m.memory_date, m.device_timestamp, m.created_at) = p_cursor_created_at AND m.id < p_cursor_id)
    )
  ORDER BY COALESCE(m.memory_date, m.device_timestamp, m.created_at) DESC NULLS LAST, m.id DESC
  LIMIT v_limit_val;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_unified_timeline_feed IS 
'Fetches unified timeline feed combining Stories, Moments, and Mementos ordered by effective date (memory_date preferred, falls back to device_timestamp/created_at). '
'Supports cursor-based pagination, memory type filtering (all/story/moment/memento), and returns '
'grouping metadata (year, season, month) for timeline organization. Primary media includes video poster URLs when available.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_unified_timeline_feed TO authenticated;

-- Step 2: Update get_timeline_feed function (for search functionality)
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
  memory_date TIMESTAMPTZ,
  year INT,
  season TEXT,
  month INT,
  day INT,
  primary_media JSONB,
  snippet_text TEXT,
  memory_location_data JSONB,
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
  
  -- Execute query with effective date logic
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
    -- Use memory_date if set, otherwise fall back to device_timestamp or created_at
    COALESCE(m.memory_date, m.device_timestamp, m.created_at) as captured_at,
    m.created_at,
    -- Return actual memory_date field (may be NULL)
    m.memory_date,
    -- Grouping fields derived from effective date
    EXTRACT(YEAR FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as year,
    public.get_season(COALESCE(m.memory_date, m.device_timestamp, m.created_at)) as season,
    EXTRACT(MONTH FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as month,
    EXTRACT(DAY FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT as day,
    -- Primary media for presentation (now includes poster URLs)
    public.get_primary_media(m.photo_urls, m.video_urls, m.video_poster_urls) as primary_media,
    -- Snippet text for preview
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) as snippet_text,
    -- Memory location data (where event happened)
    m.memory_location_data,
    NULL::TIMESTAMPTZ as next_cursor_captured_at,
    NULL::UUID as next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    -- Memory type filter
    AND (
      v_memory_type_filter IS NULL 
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    -- Cursor-based pagination using effective date
    AND (
      p_cursor_captured_at IS NULL 
      OR p_cursor_id IS NULL
      OR COALESCE(m.memory_date, m.device_timestamp, m.created_at) < p_cursor_captured_at
      OR (COALESCE(m.memory_date, m.device_timestamp, m.created_at) = p_cursor_captured_at AND m.id < p_cursor_id)
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
  ORDER BY COALESCE(m.memory_date, m.device_timestamp, m.created_at) DESC NULLS LAST, m.id DESC
  LIMIT v_limit_val;
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_timeline_feed IS 
'Fetches timeline feed with cursor-based pagination, optional search, and optional memory type filtering. '
'Uses effective date (memory_date preferred, falls back to device_timestamp/created_at) for ordering and grouping. '
'Primary media includes video poster URLs when available.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_timeline_feed TO authenticated;

-- Migration: Restore memory_location_data fields in detail and timeline RPCs
-- Description: Ensures get_memory_detail, get_unified_timeline_feed, and get_timeline_feed
--              return the memory_location_data JSONB payload (event location) along with
--              explicit memory_date values for client-side rendering.

-- Step 1: Update get_memory_detail to return memory_location_data
DROP FUNCTION IF EXISTS public.get_memory_detail(UUID);

CREATE OR REPLACE FUNCTION public.get_memory_detail(p_memory_id UUID)
RETURNS TABLE(
  id UUID,
  user_id UUID,
  title TEXT,
  input_text TEXT,
  processed_text TEXT,
  generated_title TEXT,
  title_generated_at TIMESTAMPTZ,
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
  audio_duration NUMERIC,
  memory_date TIMESTAMPTZ,
  memory_location_data JSONB
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
  v_video_poster_url TEXT;
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

  -- Fetch the memory record (includes video poster URLs and memory_location_data)
  SELECT
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    m.title_generated_at,
    m.title_generated_at,
    COALESCE(m.tags, '{}'::TEXT[]) AS tags,
    m.memory_type::TEXT,
    COALESCE(m.device_timestamp, m.created_at) AS captured_at,
    m.created_at,
    m.updated_at,
    m.captured_location,
    m.location_status,
    m.photo_urls,
    m.video_urls,
    COALESCE(m.video_poster_urls, '{}'::TEXT[]) AS video_poster_urls,
    m.memory_date,
    m.memory_location_data
  INTO v_memory
  FROM public.memories m
  WHERE m.id = p_memory_id
    AND m.user_id = v_user_id;

  -- Check if memory was found
  IF v_memory.id IS NULL THEN
    RAISE EXCEPTION 'Not Found: Memory not found or user does not have access';
  END IF;

  -- Fetch story_fields if this is a story
  IF v_memory.memory_type::TEXT = 'story' THEN
    SELECT
      sf.audio_path,
      sf.audio_duration
    INTO v_story_fields
    FROM public.story_fields sf
    WHERE sf.memory_id = p_memory_id;

    IF v_story_fields IS NOT NULL THEN
      v_audio_path := v_story_fields.audio_path;
      v_audio_duration := v_story_fields.audio_duration;
    END IF;
  END IF;

  -- Build location_data JSONB object (captured location)
  IF v_memory.captured_location IS NOT NULL THEN
    v_location_data := jsonb_build_object(
      'latitude', ST_Y(v_memory.captured_location::geometry)::DOUBLE PRECISION,
      'longitude', ST_X(v_memory.captured_location::geometry)::DOUBLE PRECISION,
      'status', v_memory.location_status
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

  -- Build videos array from video_urls with poster URLs
  IF v_memory.video_urls IS NOT NULL AND array_length(v_memory.video_urls, 1) > 0 THEN
    FOREACH v_video_url IN ARRAY v_memory.video_urls
    LOOP
      v_video_poster_url := NULL;
      IF v_memory.video_poster_urls IS NOT NULL
         AND array_length(v_memory.video_poster_urls, 1) > v_video_index
         AND v_memory.video_poster_urls[v_video_index + 1] IS NOT NULL
         AND v_memory.video_poster_urls[v_video_index + 1] != '' THEN
        v_video_poster_url := v_memory.video_poster_urls[v_video_index + 1];
      END IF;

      v_videos := v_videos || jsonb_build_object(
        'url', v_video_url,
        'index', v_video_index,
        'duration', NULL,
        'poster_url', v_video_poster_url,
        'caption', NULL
      );
      v_video_index := v_video_index + 1;
    END LOOP;
  END IF;

  -- Return the result with memory_date and memory_location_data
  RETURN QUERY SELECT
    v_memory.id,
    v_memory.user_id,
    v_memory.title,
    v_memory.input_text,
    v_memory.processed_text,
    v_memory.generated_title,
    v_memory.title_generated_at,
    v_memory.tags,
    v_memory.memory_type,
    v_memory.captured_at,
    v_memory.created_at,
    v_memory.updated_at,
    NULL::TEXT AS public_share_token,
    v_location_data,
    v_photos,
    v_videos,
    ARRAY[]::UUID[] AS related_stories,
    ARRAY[]::UUID[] AS related_mementos,
    v_audio_path,
    v_audio_duration,
    v_memory.memory_date,
    v_memory.memory_location_data
  ;
END;
$$;

COMMENT ON FUNCTION public.get_memory_detail IS
'Fetches detailed memory data by ID (moments, stories, mementos). Returns media metadata, '
'captured location data, event memory_location_data, related memories, audio fields for stories, '
'and memory_date for user-specified dates.';

GRANT EXECUTE ON FUNCTION public.get_memory_detail TO authenticated;

-- Step 2: Update get_unified_timeline_feed to include memory_date and memory_location_data
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
  title_generated_at TIMESTAMPTZ,
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
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;

  v_limit_val := LEAST(COALESCE(p_batch_size, 20), 100);

  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL;
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    m.title_generated_at,
    COALESCE(m.tags, '{}'::TEXT[]) AS tags,
    m.memory_type::TEXT,
    COALESCE(m.memory_date, m.device_timestamp, m.created_at) AS captured_at,
    m.created_at,
    m.memory_date,
    EXTRACT(YEAR FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS year,
    public.get_season(COALESCE(m.memory_date, m.device_timestamp, m.created_at)) AS season,
    EXTRACT(MONTH FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS month,
    EXTRACT(DAY FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS day,
    public.get_primary_media(
      m.photo_urls,
      m.video_urls,
      COALESCE(m.video_poster_urls, '{}'::TEXT[])
    ) AS primary_media,
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) AS snippet_text,
    m.memory_location_data,
    NULL::TIMESTAMPTZ AS next_cursor_created_at,
    NULL::UUID AS next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    AND (
      v_memory_type_filter IS NULL
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    AND (
      p_cursor_created_at IS NULL
      OR p_cursor_id IS NULL
      OR COALESCE(m.memory_date, m.device_timestamp, m.created_at) < p_cursor_created_at
      OR (
        COALESCE(m.memory_date, m.device_timestamp, m.created_at) = p_cursor_created_at
        AND m.id < p_cursor_id
      )
    )
  ORDER BY COALESCE(m.memory_date, m.device_timestamp, m.created_at) DESC NULLS LAST, m.id DESC
  LIMIT v_limit_val;
END;
$$;

COMMENT ON FUNCTION public.get_unified_timeline_feed IS
'Fetches the unified timeline feed ordered by effective date (memory_date preferred). '
'Returns media metadata, snippet text, and memory_location_data for each memory.';

GRANT EXECUTE ON FUNCTION public.get_unified_timeline_feed TO authenticated;

-- Step 3: Update get_timeline_feed (search) to include memory_date and memory_location_data
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
  title_generated_at TIMESTAMPTZ,
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
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;

  v_limit_val := LEAST(COALESCE(p_batch_size, 25), 100);

  IF p_memory_type IS NOT NULL AND p_memory_type NOT IN ('story', 'moment', 'memento') THEN
    RAISE EXCEPTION 'Invalid memory_type: must be story, moment, memento, or NULL';
  END IF;

  v_memory_type_filter := p_memory_type;

  RETURN QUERY
  SELECT
    m.id,
    m.user_id,
    m.title,
    m.input_text,
    m.processed_text,
    m.generated_title,
    COALESCE(m.tags, '{}'::TEXT[]) AS tags,
    m.memory_type::TEXT,
    COALESCE(m.memory_date, m.device_timestamp, m.created_at) AS captured_at,
    m.created_at,
    m.memory_date,
    EXTRACT(YEAR FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS year,
    public.get_season(COALESCE(m.memory_date, m.device_timestamp, m.created_at)) AS season,
    EXTRACT(MONTH FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS month,
    EXTRACT(DAY FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS day,
    public.get_primary_media(
      m.photo_urls,
      m.video_urls,
      COALESCE(m.video_poster_urls, '{}'::TEXT[])
    ) AS primary_media,
    LEFT(
      COALESCE(
        NULLIF(trim(m.processed_text), ''),
        NULLIF(trim(m.input_text), '')
      ),
      200
    ) AS snippet_text,
    m.memory_location_data,
    NULL::TIMESTAMPTZ AS next_cursor_captured_at,
    NULL::UUID AS next_cursor_id
  FROM public.memories m
  WHERE m.user_id = v_user_id
    AND (
      v_memory_type_filter IS NULL
      OR m.memory_type::TEXT = v_memory_type_filter
    )
    AND (
      p_cursor_captured_at IS NULL
      OR p_cursor_id IS NULL
      OR COALESCE(m.memory_date, m.device_timestamp, m.created_at) < p_cursor_captured_at
      OR (
        COALESCE(m.memory_date, m.device_timestamp, m.created_at) = p_cursor_captured_at
        AND m.id < p_cursor_id
      )
    )
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

COMMENT ON FUNCTION public.get_timeline_feed IS
'Fetches timeline entries with optional search filtering. Returns effective memory_date, '
'primary media metadata, and memory_location_data for each memory.';

GRANT EXECUTE ON FUNCTION public.get_timeline_feed TO authenticated;

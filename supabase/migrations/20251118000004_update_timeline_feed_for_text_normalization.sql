-- Migration: Update get_timeline_feed function for text normalization
-- Description: Updates get_timeline_feed RPC to use memory_type, input_text, and processed_text columns
--              instead of capture_type and text_description. This function is used by timeline_provider.dart

-- Drop existing function
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
  raw_transcript TEXT,
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
    m.raw_transcript,
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


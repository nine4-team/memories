-- Migration: Create unified timeline feed for Stories, Moments, and Mementos
-- Description: Creates RPC function to return unified feed combining all memory types
--              ordered by created_at DESC with grouping fields (year, season, month)
--              and cursor-based pagination support

-- Drop existing function if it exists (we're replacing it with unified version)
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
  text_description TEXT,
  raw_transcript TEXT,
  generated_title TEXT,
  tags TEXT[],
  capture_type TEXT,
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
    m.text_description,
    m.raw_transcript,
    m.generated_title,
    COALESCE(m.tags, '{}'::TEXT[]) as tags,
    m.capture_type::TEXT,
    m.captured_at,
    m.created_at,
    -- Grouping fields derived from created_at (for timeline grouping)
    EXTRACT(YEAR FROM m.created_at)::INT as year,
    public.get_season(m.created_at) as season,
    EXTRACT(MONTH FROM m.created_at)::INT as month,
    EXTRACT(DAY FROM m.created_at)::INT as day,
    -- Primary media for presentation
    public.get_primary_media(m.photo_urls, m.video_urls) as primary_media,
    -- Snippet text for preview (prefer text_description, fallback to raw_transcript)
    LEFT(
      COALESCE(
        NULLIF(trim(m.text_description), ''),
        NULLIF(trim(m.raw_transcript), '')
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
      OR m.capture_type::TEXT = v_memory_type_filter
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

-- Ensure RLS policies exist on moments table (should already exist, but verify)
-- RLS is enforced via auth.uid() check in the function, but table-level policies provide defense in depth
DO $$
BEGIN
  -- Check if RLS is enabled on memories table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'memories' 
    AND rowsecurity = true
  ) THEN
    -- Enable RLS if not already enabled
    ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;
  END IF;
  
  -- Ensure policy exists for users to read their own memories
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'memories' 
    AND policyname = 'Users can view their own memories'
  ) THEN
    CREATE POLICY "Users can view their own memories"
      ON public.memories
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;


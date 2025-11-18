-- Migration: Create search functionality for memories
-- Description: Creates search_memories RPC function for full-text search with pagination,
--              creates recent_searches table and RPC functions for managing search history,
--              and adds validation and logging for search queries.

-- ============================================================================
-- PART 1: Create search_memories RPC function
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.search_memories(
  p_query TEXT,
  p_page INT,
  p_page_size INT,
  p_memory_type TEXT
);

CREATE OR REPLACE FUNCTION public.search_memories(
  p_query TEXT,
  p_page INT DEFAULT 1,
  p_page_size INT DEFAULT 20,
  p_memory_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_query_normalized TEXT;
  v_tsquery tsquery;
  v_offset_val INT;
  v_limit_val INT;
  v_memory_type_filter TEXT;
  v_start_time TIMESTAMPTZ;
  v_duration_ms NUMERIC;
  v_result_count INT;
  v_has_more BOOLEAN;
  v_items JSONB;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Validate and normalize query (reject empty/whitespace-only)
  v_query_normalized := trim(p_query);
  IF v_query_normalized IS NULL OR v_query_normalized = '' THEN
    RAISE EXCEPTION 'Invalid query: query cannot be empty or whitespace-only';
  END IF;
  
  -- Validate page (must be >= 1)
  IF p_page IS NULL OR p_page < 1 THEN
    RAISE EXCEPTION 'Invalid page: must be >= 1';
  END IF;
  
  -- Validate page_size (default 20, max 50 per spec)
  v_limit_val := LEAST(COALESCE(p_page_size, 20), 50);
  IF v_limit_val < 1 THEN
    RAISE EXCEPTION 'Invalid page_size: must be >= 1';
  END IF;
  
  -- Calculate offset
  v_offset_val := (p_page - 1) * v_limit_val;
  
  -- Validate and normalize memory_type parameter
  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL; -- NULL means all types
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;
  
  -- Build safe tsquery from normalized query
  -- Use plainto_tsquery for simple keyword search (handles multi-word queries)
  -- This is safer than to_tsquery as it handles user input better
  BEGIN
    v_tsquery := plainto_tsquery('english', v_query_normalized);
    
    -- If plainto_tsquery returns empty (e.g., only stopwords), try phraseto_tsquery
    IF v_tsquery IS NULL OR v_tsquery = '' THEN
      v_tsquery := phraseto_tsquery('english', v_query_normalized);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- If tsquery building fails, log and raise
    RAISE EXCEPTION 'Invalid query format: %', SQLERRM;
  END;
  
  -- Start timing for performance logging
  v_start_time := clock_timestamp();
  
  -- Execute search query with ranking
  -- Order by ts_rank_cd (coverage density ranking) DESC, then recency as tiebreaker
  -- Fetch one extra row to determine has_more
  WITH ranked_results AS (
    SELECT 
      m.id,
      m.memory_type::TEXT as memory_type,
      m.title,
      -- Snippet text: prefer processed_text, fallback to input_text, trim to ~200 chars
      LEFT(
        COALESCE(
          NULLIF(trim(m.processed_text), ''),
          NULLIF(trim(m.input_text), '')
        ),
        200
      ) as snippet_text,
      m.created_at
    FROM public.memories m
    WHERE m.user_id = v_user_id
      -- Memory type filter
      AND (
        v_memory_type_filter IS NULL 
        OR m.memory_type::TEXT = v_memory_type_filter
      )
      -- Full-text search match
      AND m.search_vector @@ v_tsquery
    ORDER BY 
      ts_rank_cd(m.search_vector, v_tsquery) DESC,
      m.created_at DESC NULLS LAST,
      m.id DESC
    LIMIT v_limit_val + 1  -- Fetch one extra to determine has_more
    OFFSET v_offset_val
  ),
  limited_results AS (
    SELECT 
      id,
      memory_type,
      title,
      snippet_text,
      created_at
    FROM ranked_results
    LIMIT v_limit_val  -- Only include the first v_limit_val rows in results
  )
  SELECT 
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'memory_type', memory_type,
          'title', title,
          'snippet_text', snippet_text,
          'created_at', created_at
        )
      ),
      '[]'::jsonb
    ),
    (SELECT COUNT(*) FROM ranked_results) > v_limit_val as has_more
  INTO v_items, v_has_more
  FROM limited_results;
  
  -- Calculate duration for logging
  v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
  v_result_count := jsonb_array_length(COALESCE(v_items, '[]'::jsonb));
  
  -- Log slow queries (>1000ms) and basic metrics
  -- Note: In production, you might want to use a logging table or external service
  -- For now, we'll use RAISE NOTICE for development/debugging
  IF v_duration_ms > 1000 THEN
    RAISE NOTICE 'Slow search query detected: query_length=%, duration_ms=%, result_count=%, page=%, memory_type=%',
      length(v_query_normalized), v_duration_ms, v_result_count, p_page, p_memory_type;
  END IF;
  
  -- Return paginated results
  RETURN jsonb_build_object(
    'items', COALESCE(v_items, '[]'::jsonb),
    'page', p_page,
    'page_size', v_limit_val,
    'has_more', COALESCE(v_has_more, false)
  );
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.search_memories IS 
'Full-text search function for memories. Searches across title, generated_title, input_text, processed_text, and tags. '
'Returns paginated results ordered by relevance (ts_rank_cd) and recency. Supports optional memory_type filtering.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.search_memories TO authenticated;

-- ============================================================================
-- PART 2: Create recent_searches table
-- ============================================================================

-- Create recent_searches table to store last 5 distinct queries per user
CREATE TABLE IF NOT EXISTS public.recent_searches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  searched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Ensure unique query per user (for upsert logic)
  UNIQUE(user_id, query)
);

-- Create index for fast lookups by user_id ordered by searched_at
CREATE INDEX IF NOT EXISTS idx_recent_searches_user_searched_at 
  ON public.recent_searches(user_id, searched_at DESC);

-- Add comments
COMMENT ON TABLE public.recent_searches IS 
'Stores recent search queries per user. Maintains last 5 distinct queries per user for quick recall.';
COMMENT ON COLUMN public.recent_searches.query IS 
'The search query text (normalized, trimmed).';
COMMENT ON COLUMN public.recent_searches.searched_at IS 
'Timestamp when the query was executed. Used for ordering (most recent first).';

-- Enable RLS
ALTER TABLE public.recent_searches ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own recent searches
CREATE POLICY "Users can view their own recent searches"
  ON public.recent_searches
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own recent searches
CREATE POLICY "Users can insert their own recent searches"
  ON public.recent_searches
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own recent searches
CREATE POLICY "Users can update their own recent searches"
  ON public.recent_searches
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can delete their own recent searches
CREATE POLICY "Users can delete their own recent searches"
  ON public.recent_searches
  FOR DELETE
  USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recent_searches TO authenticated;

-- ============================================================================
-- PART 3: Create RPC functions for managing recent searches
-- ============================================================================

-- Function: Get recent searches for current user (last 5)
DROP FUNCTION IF EXISTS public.get_recent_searches();

CREATE OR REPLACE FUNCTION public.get_recent_searches()
RETURNS TABLE (
  query TEXT,
  searched_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Return last 5 recent searches, most recent first
  RETURN QUERY
  SELECT 
    rs.query,
    rs.searched_at
  FROM public.recent_searches rs
  WHERE rs.user_id = v_user_id
  ORDER BY rs.searched_at DESC
  LIMIT 5;
END;
$$;

COMMENT ON FUNCTION public.get_recent_searches IS 
'Returns the last 5 distinct search queries for the authenticated user, ordered by most recent first.';

GRANT EXECUTE ON FUNCTION public.get_recent_searches TO authenticated;

-- Function: Upsert recent search (add new or move existing to top)
DROP FUNCTION IF EXISTS public.upsert_recent_search(p_query TEXT);

CREATE OR REPLACE FUNCTION public.upsert_recent_search(p_query TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_query_normalized TEXT;
  v_existing_count INT;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Normalize query
  v_query_normalized := trim(p_query);
  IF v_query_normalized IS NULL OR v_query_normalized = '' THEN
    RAISE EXCEPTION 'Invalid query: query cannot be empty or whitespace-only';
  END IF;
  
  -- Check if query already exists for this user
  SELECT COUNT(*) INTO v_existing_count
  FROM public.recent_searches
  WHERE user_id = v_user_id AND query = v_query_normalized;
  
  IF v_existing_count > 0 THEN
    -- Update existing record to move it to most recent
    UPDATE public.recent_searches
    SET searched_at = NOW()
    WHERE user_id = v_user_id AND query = v_query_normalized;
  ELSE
    -- Insert new record
    INSERT INTO public.recent_searches (user_id, query, searched_at)
    VALUES (v_user_id, v_query_normalized, NOW());
    
    -- Maintain only last 5: delete oldest if we exceed 5
    DELETE FROM public.recent_searches
    WHERE user_id = v_user_id
      AND id NOT IN (
        SELECT id
        FROM public.recent_searches
        WHERE user_id = v_user_id
        ORDER BY searched_at DESC
        LIMIT 5
      );
  END IF;
END;
$$;

COMMENT ON FUNCTION public.upsert_recent_search IS 
'Adds a new search query to recent searches or updates existing one to most recent. '
'Maintains only the last 5 distinct queries per user.';

GRANT EXECUTE ON FUNCTION public.upsert_recent_search TO authenticated;

-- Function: Clear recent searches for current user
DROP FUNCTION IF EXISTS public.clear_recent_searches();

CREATE OR REPLACE FUNCTION public.clear_recent_searches()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Delete all recent searches for this user
  DELETE FROM public.recent_searches
  WHERE user_id = v_user_id;
END;
$$;

COMMENT ON FUNCTION public.clear_recent_searches IS 
'Deletes all recent search queries for the authenticated user.';

GRANT EXECUTE ON FUNCTION public.clear_recent_searches TO authenticated;

-- ============================================================================
-- Verification queries (run manually after migration):
-- ============================================================================
-- 
-- 1. Test search_memories function:
--    SELECT * FROM public.search_memories('test query', 1, 20, NULL);
--
-- 2. Test with memory_type filter:
--    SELECT * FROM public.search_memories('story', 1, 20, 'story');
--
-- 3. Test recent searches:
--    SELECT * FROM public.get_recent_searches();
--
-- 4. Test upsert recent search:
--    SELECT public.upsert_recent_search('test query');
--    SELECT * FROM public.get_recent_searches();
--
-- 5. Test clear recent searches:
--    SELECT public.clear_recent_searches();
--    SELECT * FROM public.get_recent_searches();
--
-- 6. Verify RLS policies:
--    -- As user A, insert a search
--    -- As user B, verify you cannot see user A's searches
--    SELECT * FROM public.recent_searches WHERE user_id = '<user_a_id>';


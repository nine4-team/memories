-- Migration: Update get_unified_timeline_years to use memory_date
-- Description: Updates years function to extract years from effective date (memory_date preferred)

DROP FUNCTION IF EXISTS public.get_unified_timeline_years(p_memory_type TEXT);

CREATE OR REPLACE FUNCTION public.get_unified_timeline_years(
  p_memory_type TEXT DEFAULT 'all'
)
RETURNS TABLE (
  year INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_memory_type_filter TEXT;
BEGIN
  -- Resolve authenticated user
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;

  -- Normalize memory type filter
  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL;
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;

  -- Extract years from effective date (memory_date preferred, falls back to device_timestamp/created_at)
  RETURN QUERY
  SELECT DISTINCT
    EXTRACT(YEAR FROM COALESCE(m.memory_date, m.device_timestamp, m.created_at))::INT AS year
  FROM public.memories m
  WHERE m.user_id = v_user_id
    AND (
      v_memory_type_filter IS NULL
      OR m.memory_type::TEXT = v_memory_type_filter
    )
  ORDER BY year DESC;
END;
$$;

COMMENT ON FUNCTION public.get_unified_timeline_years IS
'Returns the list of years containing memories for the authenticated user, '
'optionally filtered by memory type (all/story/moment/memento). '
'Uses effective date (memory_date preferred, falls back to device_timestamp/created_at).';

GRANT EXECUTE ON FUNCTION public.get_unified_timeline_years TO authenticated;


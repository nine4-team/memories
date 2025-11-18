-- Migration: Add search vector and indexing to memories table
-- Description: Adds a tsvector column for full-text search, creates a trigger to maintain it,
--              and creates a GIN index for fast search queries. The search_vector combines
--              title, generated_title, input_text, processed_text, and tags with equal weight.

-- Step 1: Create function to compute search_vector
-- This function combines all text fields into a single tsvector for full-text search
CREATE OR REPLACE FUNCTION public.compute_memory_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  -- Combine title, generated_title, input_text, processed_text, and tags
  -- Use coalesce to handle NULL values and convert tags array to text
  -- All fields use equal weight (no setweight calls)
  NEW.search_vector := to_tsvector('english',
    coalesce(NEW.title, '') || ' ' ||
    coalesce(NEW.generated_title, '') || ' ' ||
    coalesce(NEW.input_text, '') || ' ' ||
    coalesce(NEW.processed_text, '') || ' ' ||
    coalesce(array_to_string(NEW.tags, ' '), '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Add search_vector column to memories table
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- Step 3: Create trigger to automatically update search_vector on INSERT and UPDATE
-- The trigger fires BEFORE INSERT/UPDATE so search_vector is always current
CREATE TRIGGER trg_update_memory_search_vector
  BEFORE INSERT OR UPDATE OF title, generated_title, input_text, processed_text, tags
  ON public.memories
  FOR EACH ROW
  EXECUTE FUNCTION public.compute_memory_search_vector();

-- Step 4: Create GIN index on search_vector for fast full-text search queries
CREATE INDEX IF NOT EXISTS idx_memories_search_vector
  ON public.memories
  USING GIN (search_vector);

-- Step 5: Backfill search_vector for existing rows
-- Update all existing rows to populate search_vector
UPDATE public.memories
SET search_vector = to_tsvector('english',
  coalesce(title, '') || ' ' ||
  coalesce(generated_title, '') || ' ' ||
  coalesce(input_text, '') || ' ' ||
  coalesce(processed_text, '') || ' ' ||
  coalesce(array_to_string(tags, ' '), '')
)
WHERE search_vector IS NULL;

-- Step 6: Add column comment for documentation
COMMENT ON COLUMN public.memories.search_vector IS
  'Full-text search vector combining title, generated_title, input_text, processed_text, and tags. Automatically maintained by trigger.';

COMMENT ON FUNCTION public.compute_memory_search_vector() IS
  'Trigger function that computes search_vector for memories table. Combines title, generated_title, input_text, processed_text, and tags with equal weight.';

-- Verification queries (run manually after migration):
-- 
-- 1. Verify search_vector is populated for existing rows:
--    SELECT id, title, search_vector IS NOT NULL as has_search_vector
--    FROM public.memories
--    LIMIT 10;
--
-- 2. Verify trigger updates search_vector on INSERT:
--    INSERT INTO public.memories (user_id, title, input_text, tags, memory_type)
--    VALUES (auth.uid(), 'Test Memory', 'This is test input text', ARRAY['test', 'search'], 'moment')
--    RETURNING id, title, search_vector IS NOT NULL as has_search_vector;
--
-- 3. Verify trigger updates search_vector on UPDATE:
--    UPDATE public.memories
--    SET input_text = 'Updated text'
--    WHERE id = '<test_id>'
--    RETURNING id, input_text, search_vector IS NOT NULL as has_search_vector;
--
-- 4. Verify search_vector includes all fields:
--    SELECT 
--      id,
--      title,
--      search_vector @@ to_tsquery('english', 'test') as matches_title,
--      search_vector @@ to_tsquery('english', 'input') as matches_input_text
--    FROM public.memories
--    WHERE title LIKE '%test%' OR input_text LIKE '%test%'
--    LIMIT 5;
--
-- 5. Verify GIN index exists:
--    SELECT indexname, indexdef
--    FROM pg_indexes
--    WHERE tablename = 'memories' AND indexname = 'idx_memories_search_vector';


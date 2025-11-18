-- Migration: Rename moments→memories, capture_type→memory_type_enum, and normalize text columns
-- Description: Consolidates Phase 5 (table/enum rename) and Phase 6 (text normalization).
--              Handles both cases: whether Phase 5 was applied or not.
--              This is a breaking change - no backwards compatibility maintained.

-- Step 1: Rename table if it's still called 'moments' (Phase 5 consolidation)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moments') THEN
    ALTER TABLE public.moments RENAME TO memories;
  END IF;
END $$;

-- Step 2: Rename enum type (handles both capture_type and memory_capture_type)
DO $$
BEGIN
  -- If enum is still 'capture_type', rename to 'memory_capture_type' first (Phase 5)
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'capture_type') THEN
    ALTER TYPE capture_type RENAME TO memory_capture_type;
  END IF;
  
  -- Then rename to 'memory_type_enum' (Phase 6)
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'memory_capture_type') THEN
    ALTER TYPE memory_capture_type RENAME TO memory_type_enum;
  END IF;
END $$;

-- Step 3: Rename column capture_type → memory_type (handles both table names)
DO $$
BEGIN
  -- Check if column exists and needs renaming
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'memories' 
    AND column_name = 'capture_type'
  ) THEN
    -- Drop default constraint first
    ALTER TABLE public.memories ALTER COLUMN capture_type DROP DEFAULT;
    
    -- Rename the column
    ALTER TABLE public.memories RENAME COLUMN capture_type TO memory_type;
    
    -- Re-add default with new enum name
    ALTER TABLE public.memories ALTER COLUMN memory_type SET DEFAULT 'moment'::memory_type_enum;
  END IF;
END $$;

-- Step 4: Rename indexes that reference capture_type (handle both old and new index names)
DO $$
BEGIN
  -- Handle index that might be named idx_moments_capture_type or idx_memories_capture_type
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_moments_capture_type') THEN
    ALTER INDEX idx_moments_capture_type RENAME TO idx_memories_memory_type;
  ELSIF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_capture_type') THEN
    ALTER INDEX idx_memories_capture_type RENAME TO idx_memories_memory_type;
  END IF;
END $$;

-- Step 5: Update comments
COMMENT ON COLUMN public.memories.memory_type IS
  'Memory type: moment (standard capture), story (narrative with audio), or memento (curated collection).';

-- Step 6: Update story-processing migration indexes that reference capture_type
-- These are partial indexes, so we need to recreate them with the new column name
DO $$
BEGIN
  -- Drop and recreate idx_memories_story_status
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_story_status') THEN
    DROP INDEX idx_memories_story_status;
  END IF;
  CREATE INDEX idx_memories_story_status 
    ON public.memories(story_status) 
    WHERE memory_type = 'story' AND story_status IN ('processing', 'failed');

  -- Drop and recreate idx_memories_processing_started_at
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_processing_started_at') THEN
    DROP INDEX idx_memories_processing_started_at;
  END IF;
  CREATE INDEX idx_memories_processing_started_at 
    ON public.memories(processing_started_at) 
    WHERE memory_type = 'story' AND processing_started_at IS NOT NULL;

  -- Drop and recreate idx_memories_processing_completed_at
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_processing_completed_at') THEN
    DROP INDEX idx_memories_processing_completed_at;
  END IF;
  CREATE INDEX idx_memories_processing_completed_at 
    ON public.memories(processing_completed_at) 
    WHERE memory_type = 'story' AND processing_completed_at IS NOT NULL;

  -- Drop and recreate idx_memories_story_retry_count
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_story_retry_count') THEN
    DROP INDEX idx_memories_story_retry_count;
  END IF;
  CREATE INDEX idx_memories_story_retry_count 
    ON public.memories(retry_count) 
    WHERE memory_type = 'story' AND retry_count > 0;

  -- Drop and recreate idx_memories_narrative_generated_at
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_memories_narrative_generated_at') THEN
    DROP INDEX idx_memories_narrative_generated_at;
  END IF;
  CREATE INDEX idx_memories_narrative_generated_at 
    ON public.memories(narrative_generated_at) 
    WHERE memory_type = 'story' AND narrative_generated_at IS NOT NULL;
END $$;


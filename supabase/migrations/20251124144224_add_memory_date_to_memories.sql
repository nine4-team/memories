-- Migration: Add memory_date column to memories table
-- Description: Adds user-editable memory_date field that represents when the memory actually occurred.
--              Timeline will prefer this user-specified date, falling back to captured_at when not set.

-- Add memory_date column to memories table
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS memory_date TIMESTAMPTZ;

-- Add index for efficient timeline queries
CREATE INDEX IF NOT EXISTS idx_memories_memory_date 
  ON public.memories (memory_date DESC) 
  WHERE memory_date IS NOT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.memories.memory_date IS 
'User-specified date and time when the memory occurred (stored as TIMESTAMPTZ in UTC). Used for timeline ordering and grouping. Falls back to captured_at (device_timestamp or created_at) if not set.';


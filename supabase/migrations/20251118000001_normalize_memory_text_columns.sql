-- Migration: Normalize memory text columns
-- Description: Renames text_description to input_text and adds processed_text column.
--              This establishes the normalized text model: input_text (raw) and processed_text (LLM-processed).

-- Step 1: Rename text_description to input_text
ALTER TABLE public.memories
  RENAME COLUMN text_description TO input_text;

-- Step 2: Add processed_text column
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS processed_text TEXT;

-- Step 3: Update comments
COMMENT ON COLUMN public.memories.input_text IS
  'Canonical raw user text from dictation or typing. Edited in capture UI.';

COMMENT ON COLUMN public.memories.processed_text IS
  'LLM-processed version of input_text (cleaned description or narrative). For stories, full narrative; for other types, cleaned description.';

-- Note: We do NOT backfill processed_text from input_text.
-- processed_text must only contain LLM-processed content.
-- Until the LLM pipeline runs successfully, processed_text stays NULL.


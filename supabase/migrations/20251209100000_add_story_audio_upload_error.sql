-- Migration: Log story audio upload failures
-- Description: Adds a column for storing the client-side error message when uploading story audio fails.
--              This ensures we can diagnose missing audio_path rows without relying on device logs.

ALTER TABLE public.story_fields
  ADD COLUMN IF NOT EXISTS audio_upload_error TEXT;

COMMENT ON COLUMN public.story_fields.audio_upload_error IS
  'Optional error message captured when the client fails to upload a story audio file. Helps debug missing audio_path entries.';

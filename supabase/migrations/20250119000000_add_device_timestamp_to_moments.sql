-- Migration: Add device_timestamp and metadata_version to moments table
-- Description: Adds device_timestamp for audit trail (when first asset/transcript started)
--              and metadata_version for future migration compatibility
--              These fields support Moments, Stories, and Mementos stored in the moments table

-- Add device_timestamp column
-- This stores the timestamp from the device when capture started (first asset or transcript)
-- Used for auditing drift between device time and server time
ALTER TABLE public.moments
  ADD COLUMN IF NOT EXISTS device_timestamp TIMESTAMPTZ;

-- Add metadata_version column
-- Used for future migrations to track which version of metadata schema was used
-- Defaults to 1 for existing records
ALTER TABLE public.moments
  ADD COLUMN IF NOT EXISTS metadata_version INTEGER DEFAULT 1;

-- Create index on device_timestamp for potential audit queries
CREATE INDEX IF NOT EXISTS idx_moments_device_timestamp 
  ON public.moments (device_timestamp) 
  WHERE device_timestamp IS NOT NULL;

-- Add column comments for documentation
COMMENT ON COLUMN public.moments.device_timestamp IS 'Device timestamp when capture started (first asset or transcript). Used for auditing drift between device time and server time.';
COMMENT ON COLUMN public.moments.metadata_version IS 'Version of metadata schema used. Incremented when metadata structure changes. Defaults to 1 for existing records.';


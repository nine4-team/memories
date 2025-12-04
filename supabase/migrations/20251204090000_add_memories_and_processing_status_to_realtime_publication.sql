-- Migration: Ensure key tables emit realtime events for Supabase clients
-- Description: Adds public.memories and public.memory_processing_status to the supabase_realtime publication if
--              they are not already present. This allows the mobile client to receive live updates for timeline
--              entries and processing status changes without manual refreshes.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'memories'
  ) THEN
    RAISE NOTICE 'Adding public.memories to supabase_realtime publication';
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.memories';
  ELSE
    RAISE NOTICE 'public.memories already present in supabase_realtime publication';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'memory_processing_status'
  ) THEN
    RAISE NOTICE 'Adding public.memory_processing_status to supabase_realtime publication';
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.memory_processing_status';
  ELSE
    RAISE NOTICE 'public.memory_processing_status already present in supabase_realtime publication';
  END IF;
END
$$;


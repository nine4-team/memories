-- Migration: Drop Old Moments Storage Buckets
-- Description: Removes the old moments-photos and moments-videos buckets and their RLS policies.
--              This completes the hard cutover to memories-photos and memories-videos buckets.
--              WARNING: This deletes all objects in the old buckets.

-- Step 1: Delete all objects from moments-photos bucket
DELETE FROM storage.objects WHERE bucket_id = 'moments-photos';

-- Step 2: Delete all objects from moments-videos bucket
DELETE FROM storage.objects WHERE bucket_id = 'moments-videos';

-- Step 3: Drop RLS policies for moments-photos bucket
DROP POLICY IF EXISTS "Users can upload their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own photos" ON storage.objects;

-- Step 4: Drop RLS policies for moments-videos bucket
DROP POLICY IF EXISTS "Users can upload their own videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own videos" ON storage.objects;

-- Step 5: Delete the old buckets
DELETE FROM storage.buckets WHERE id = 'moments-photos';
DELETE FROM storage.buckets WHERE id = 'moments-videos';


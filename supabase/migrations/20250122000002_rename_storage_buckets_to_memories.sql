-- Migration: Rename Storage Buckets from moments-* to memories-*
-- Description: Renames storage buckets to use unified "memories" terminology.
--              This is a hard cutover - no backward compatibility maintained.
--              Existing objects in old buckets will need to be migrated separately.

-- Step 1: Create new memories-photos bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'memories-photos',
  'memories-photos',
  false,
  10485760, -- 10MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Step 2: Create new memories-videos bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'memories-videos',
  'memories-videos',
  false,
  104857600, -- 100MB in bytes
  ARRAY['video/mp4', 'video/quicktime', 'video/x-msvideo']
)
ON CONFLICT (id) DO NOTHING;

-- Step 3: Create RLS Policies for memories-photos bucket
-- Path structure: {userId}/{filename}

-- Drop policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload their own memory photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own memory photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own memory photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own memory photos" ON storage.objects;

-- Policy: Users can upload their own photos
CREATE POLICY "Users can upload their own memory photos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'memories-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can read their own photos
CREATE POLICY "Users can read their own memory photos"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'memories-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can update their own photos
CREATE POLICY "Users can update their own memory photos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'memories-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
)
WITH CHECK (
  bucket_id = 'memories-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can delete their own photos
CREATE POLICY "Users can delete their own memory photos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'memories-photos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Step 4: Create RLS Policies for memories-videos bucket
-- Path structure: {userId}/{filename}

-- Drop policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload their own memory videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own memory videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own memory videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own memory videos" ON storage.objects;

-- Policy: Users can upload their own videos
CREATE POLICY "Users can upload their own memory videos"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'memories-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can read their own videos
CREATE POLICY "Users can read their own memory videos"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'memories-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can update their own videos
CREATE POLICY "Users can update their own memory videos"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'memories-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
)
WITH CHECK (
  bucket_id = 'memories-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Policy: Users can delete their own videos
CREATE POLICY "Users can delete their own memory videos"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'memories-videos' AND
  auth.uid()::text = (string_to_array(name, '/'))[1]
);

-- Note: The old moments-photos and moments-videos buckets and their policies
-- are left in place for now. They can be dropped in a future migration after
-- confirming all objects have been migrated to the new buckets.


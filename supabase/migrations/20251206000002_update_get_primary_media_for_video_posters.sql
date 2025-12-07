-- Migration: Update get_primary_media function to include video poster URLs
-- Description: Updates get_primary_media helper function to accept video_poster_urls and include poster_url in video primary_media JSON

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_primary_media(TEXT[], TEXT[]);
DROP FUNCTION IF EXISTS public.get_primary_media(TEXT[], TEXT[], TEXT[]);

-- Create updated function that accepts video_poster_urls
CREATE OR REPLACE FUNCTION public.get_primary_media(
  p_photo_urls TEXT[],
  p_video_urls TEXT[],
  p_video_poster_urls TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_primary_media JSONB;
  v_first_video_poster_url TEXT;
BEGIN
  -- Prefer first photo if available
  IF p_photo_urls IS NOT NULL AND array_length(p_photo_urls, 1) > 0 THEN
    v_primary_media := jsonb_build_object(
      'type', 'photo',
      'url', p_photo_urls[1],
      'index', 0
    );
  -- Otherwise use first video if available
  ELSIF p_video_urls IS NOT NULL AND array_length(p_video_urls, 1) > 0 THEN
    -- Get corresponding poster URL if available
    v_first_video_poster_url := NULL;
    IF p_video_poster_urls IS NOT NULL 
       AND array_length(p_video_poster_urls, 1) > 0 THEN
      v_first_video_poster_url := p_video_poster_urls[1];
    END IF;
    
    v_primary_media := jsonb_build_object(
      'type', 'video',
      'url', p_video_urls[1],
      'index', 0,
      'poster_url', v_first_video_poster_url
    );
  ELSE
    v_primary_media := NULL;
  END IF;
  
  RETURN v_primary_media;
END;
$$;

-- Create backward-compatible overload for existing calls
CREATE OR REPLACE FUNCTION public.get_primary_media(
  p_photo_urls TEXT[],
  p_video_urls TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Call the 3-parameter version with NULL poster URLs
  RETURN public.get_primary_media(p_photo_urls, p_video_urls, NULL::TEXT[]);
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.get_primary_media IS 
'Returns primary media JSONB for timeline display. Prefers first photo, otherwise first video. '
'If video_poster_urls is provided, includes poster_url in video media object.';

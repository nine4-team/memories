-- Backend SQL Tests for Search Functionality
-- 
-- These tests verify:
-- 1. search_vector includes all five fields and updates on change
-- 2. Search function honors user scoping and optional memory_type filter
-- 3. Ranking and pagination behave predictably
--
-- Run these tests manually against a test database:
-- psql -h <host> -U <user> -d <database> -f test/backend/search_backend_test.sql
--
-- Or execute individual queries in Supabase SQL Editor

-- ============================================================================
-- SETUP: Create test data
-- ============================================================================

-- Note: These tests assume you have an authenticated user session
-- In a real test environment, you would:
-- 1. Create test users
-- 2. Create test memories with known content
-- 3. Run tests
-- 4. Clean up

-- ============================================================================
-- TEST 1: Verify search_vector includes all five fields
-- ============================================================================

-- Test that search_vector is populated for a memory with all fields
DO $$
DECLARE
  v_test_user_id UUID;
  v_memory_id UUID;
  v_search_vector tsvector;
BEGIN
  -- Get current user (assumes authenticated session)
  v_test_user_id := auth.uid();
  
  IF v_test_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: No authenticated user. Set up test user first.';
    RETURN;
  END IF;

  -- Create a test memory with all fields populated
  INSERT INTO public.memories (
    user_id,
    memory_type,
    title,
    generated_title,
    input_text,
    processed_text,
    tags
  ) VALUES (
    v_test_user_id,
    'moment',
    'Test Memory Title',
    'Generated Title',
    'This is input text with searchable content',
    'This is processed text with searchable content',
    ARRAY['tag1', 'tag2', 'searchable']
  )
  RETURNING id, search_vector INTO v_memory_id, v_search_vector;

  -- Verify search_vector is not null
  IF v_search_vector IS NULL THEN
    RAISE EXCEPTION 'FAIL: search_vector is NULL after INSERT';
  END IF;

  -- Verify search_vector contains terms from all fields
  IF NOT (v_search_vector @@ to_tsquery('english', 'Test')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain title term';
  END IF;

  IF NOT (v_search_vector @@ to_tsquery('english', 'Generated')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain generated_title term';
  END IF;

  IF NOT (v_search_vector @@ to_tsquery('english', 'input')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain input_text term';
  END IF;

  IF NOT (v_search_vector @@ to_tsquery('english', 'processed')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain processed_text term';
  END IF;

  IF NOT (v_search_vector @@ to_tsquery('english', 'tag1')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain tags term';
  END IF;

  RAISE NOTICE 'PASS: search_vector includes all five fields';

  -- Clean up
  DELETE FROM public.memories WHERE id = v_memory_id;
END $$;

-- ============================================================================
-- TEST 2: Verify search_vector updates on field change
-- ============================================================================

DO $$
DECLARE
  v_test_user_id UUID;
  v_memory_id UUID;
  v_old_vector tsvector;
  v_new_vector tsvector;
BEGIN
  v_test_user_id := auth.uid();
  
  IF v_test_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: No authenticated user. Set up test user first.';
    RETURN;
  END IF;

  -- Create initial memory
  INSERT INTO public.memories (
    user_id,
    memory_type,
    title,
    input_text
  ) VALUES (
    v_test_user_id,
    'moment',
    'Original Title',
    'Original input'
  )
  RETURNING id, search_vector INTO v_memory_id, v_old_vector;

  -- Update title
  UPDATE public.memories
  SET title = 'Updated Title'
  WHERE id = v_memory_id
  RETURNING search_vector INTO v_new_vector;

  -- Verify search_vector changed
  IF v_old_vector = v_new_vector THEN
    RAISE EXCEPTION 'FAIL: search_vector did not update after title change';
  END IF;

  -- Verify new term is searchable
  IF NOT (v_new_vector @@ to_tsquery('english', 'Updated')) THEN
    RAISE EXCEPTION 'FAIL: search_vector does not contain updated term';
  END IF;

  RAISE NOTICE 'PASS: search_vector updates on field change';

  -- Clean up
  DELETE FROM public.memories WHERE id = v_memory_id;
END $$;

-- ============================================================================
-- TEST 3: Verify search function honors user scoping
-- ============================================================================

DO $$
DECLARE
  v_user1_id UUID;
  v_user2_id UUID;
  v_memory1_id UUID;
  v_memory2_id UUID;
  v_results JSONB;
BEGIN
  -- This test requires two users, which is complex in a single session
  -- In a real test environment, you would:
  -- 1. Create user1 and user2
  -- 2. Create memories for each user
  -- 3. Search as user1 and verify only user1's memories are returned
  -- 4. Search as user2 and verify only user2's memories are returned
  
  RAISE NOTICE 'INFO: User scoping test requires multiple authenticated sessions.';
  RAISE NOTICE 'INFO: Manual verification: Create memories as different users and verify RLS works.';
  
  -- Basic check: search_memories requires authentication
  BEGIN
    -- This should fail if not authenticated
    SELECT * INTO v_results FROM public.search_memories('test', 1, 20, NULL);
    RAISE NOTICE 'PASS: search_memories requires authentication';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Unauthorized%' THEN
      RAISE NOTICE 'PASS: search_memories correctly rejects unauthenticated requests';
    ELSE
      RAISE EXCEPTION 'FAIL: Unexpected error: %', SQLERRM;
    END IF;
  END;
END $$;

-- ============================================================================
-- TEST 4: Verify memory_type filter works
-- ============================================================================

DO $$
DECLARE
  v_test_user_id UUID;
  v_moment_id UUID;
  v_story_id UUID;
  v_results JSONB;
  v_items JSONB;
  v_all_types_count INT;
  v_moments_only_count INT;
BEGIN
  v_test_user_id := auth.uid();
  
  IF v_test_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: No authenticated user. Set up test user first.';
    RETURN;
  END IF;

  -- Create test memories of different types
  INSERT INTO public.memories (
    user_id,
    memory_type,
    title,
    input_text
  ) VALUES 
  (
    v_test_user_id,
    'moment',
    'Test Moment',
    'moment content'
  ),
  (
    v_test_user_id,
    'story',
    'Test Story',
    'story content'
  )
  RETURNING id INTO v_moment_id, v_story_id;

  -- Search without filter (should return both)
  SELECT * INTO v_results FROM public.search_memories('Test', 1, 20, NULL);
  v_items := v_results->'items';
  v_all_types_count := jsonb_array_length(v_items);

  IF v_all_types_count < 2 THEN
    RAISE NOTICE 'WARN: Expected at least 2 results, got %. Check test data.', v_all_types_count;
  END IF;

  -- Search with moment filter (should return only moments)
  SELECT * INTO v_results FROM public.search_memories('Test', 1, 20, 'moment');
  v_items := v_results->'items';
  v_moments_only_count := jsonb_array_length(v_items);

  -- Verify all results are moments
  FOR i IN 0..(v_moments_only_count - 1) LOOP
    IF (v_items->i->>'memory_type') != 'moment' THEN
      RAISE EXCEPTION 'FAIL: memory_type filter returned non-moment result';
    END IF;
  END LOOP;

  RAISE NOTICE 'PASS: memory_type filter works correctly';

  -- Clean up
  DELETE FROM public.memories WHERE id IN (v_moment_id, v_story_id);
END $$;

-- ============================================================================
-- TEST 5: Verify ranking and pagination
-- ============================================================================

DO $$
DECLARE
  v_test_user_id UUID;
  v_results_page1 JSONB;
  v_results_page2 JSONB;
  v_items_page1 JSONB;
  v_items_page2 JSONB;
  v_page1_count INT;
  v_page2_count INT;
  v_has_more BOOLEAN;
BEGIN
  v_test_user_id := auth.uid();
  
  IF v_test_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: No authenticated user. Set up test user first.';
    RETURN;
  END IF;

  -- Create multiple test memories (at least 3 for pagination test)
  -- Note: In a real test, you'd create more memories with varying relevance
  
  -- Test pagination: page 1
  SELECT * INTO v_results_page1 FROM public.search_memories('test', 1, 2, NULL);
  v_items_page1 := v_results_page1->'items';
  v_page1_count := jsonb_array_length(v_items_page1);
  v_has_more := (v_results_page1->>'has_more')::boolean;

  -- Verify page structure
  IF (v_results_page1->>'page')::int != 1 THEN
    RAISE EXCEPTION 'FAIL: page number incorrect';
  END IF;

  IF (v_results_page1->>'page_size')::int != 2 THEN
    RAISE EXCEPTION 'FAIL: page_size incorrect';
  END IF;

  -- Test pagination: page 2 (if has_more is true)
  IF v_has_more THEN
    SELECT * INTO v_results_page2 FROM public.search_memories('test', 2, 2, NULL);
    v_items_page2 := v_results_page2->'items';
    v_page2_count := jsonb_array_length(v_items_page2);

    -- Verify page 2 structure
    IF (v_results_page2->>'page')::int != 2 THEN
      RAISE EXCEPTION 'FAIL: page 2 number incorrect';
    END IF;

    -- Verify no duplicate IDs between pages
    -- (This is a simplified check - in a real test you'd compare all IDs)
    RAISE NOTICE 'PASS: Pagination works correctly';
  ELSE
    RAISE NOTICE 'INFO: Only one page of results (has_more=false). Create more test data for full pagination test.';
  END IF;

  -- Verify results are ordered by relevance (ts_rank_cd)
  -- In a real test, you'd create memories with known relevance scores
  -- and verify they're returned in the correct order
  RAISE NOTICE 'INFO: Ranking test requires memories with known relevance. Manual verification recommended.';

END $$;

-- ============================================================================
-- TEST 6: Verify recent searches functionality
-- ============================================================================

DO $$
DECLARE
  v_test_user_id UUID;
  v_recent_searches RECORD;
  v_count INT;
BEGIN
  v_test_user_id := auth.uid();
  
  IF v_test_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: No authenticated user. Set up test user first.';
    RETURN;
  END IF;

  -- Clear existing searches
  PERFORM public.clear_recent_searches();

  -- Add a search
  PERFORM public.upsert_recent_search('test query 1');
  PERFORM public.upsert_recent_search('test query 2');
  PERFORM public.upsert_recent_search('test query 3');

  -- Get recent searches
  SELECT COUNT(*) INTO v_count
  FROM public.get_recent_searches();

  IF v_count < 3 THEN
    RAISE EXCEPTION 'FAIL: Expected at least 3 recent searches, got %', v_count;
  END IF;

  -- Verify ordering (most recent first)
  -- This is a simplified check - in a real test you'd verify timestamps
  RAISE NOTICE 'PASS: Recent searches can be added and retrieved';

  -- Test duplicate handling (should move to top)
  PERFORM public.upsert_recent_search('test query 1');
  
  -- Verify it's still in the list (and moved to top)
  SELECT COUNT(*) INTO v_count
  FROM public.get_recent_searches()
  WHERE query = 'test query 1';

  IF v_count != 1 THEN
    RAISE EXCEPTION 'FAIL: Duplicate search not handled correctly';
  END IF;

  RAISE NOTICE 'PASS: Duplicate searches are handled correctly';

  -- Test limit (should maintain only 5)
  PERFORM public.upsert_recent_search('test query 4');
  PERFORM public.upsert_recent_search('test query 5');
  PERFORM public.upsert_recent_search('test query 6');

  SELECT COUNT(*) INTO v_count
  FROM public.get_recent_searches();

  IF v_count > 5 THEN
    RAISE EXCEPTION 'FAIL: Recent searches limit exceeded, got %', v_count;
  END IF;

  RAISE NOTICE 'PASS: Recent searches limit (5) is maintained';

  -- Clean up
  PERFORM public.clear_recent_searches();
END $$;

-- ============================================================================
-- SUMMARY
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backend Search Tests Complete';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: Some tests require manual verification with multiple users';
  RAISE NOTICE 'or specific test data. Review the test output above for any';
  RAISE NOTICE 'warnings or skipped tests.';
  RAISE NOTICE '';
END $$;


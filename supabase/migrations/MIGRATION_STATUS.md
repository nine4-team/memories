# Migration Status

## ✅ Active Migrations (Run in Order)

1. **20250116000000_extend_moments_table_for_text_media_capture.sql**
   - Creates `moments` table with `capture_type` enum
   - ✅ Safe to run

2. **20250118000000_add_story_filter_to_timeline_feed.sql**
   - Creates/updates `get_timeline_feed` function with old column names
   - ⚠️ Will be updated by migration #9 below
   - ✅ Safe to run (function will be fixed later)

3. **20250119000000_add_device_timestamp_to_moments.sql**
   - Adds `device_timestamp` and `metadata_version` columns
   - ✅ Safe to run

4. **20250120000000_create_unified_timeline_feed.sql**
   - Creates `get_unified_timeline_feed` function with old column names
   - ⚠️ Will be updated by migration #7 below
   - ✅ Safe to run (function will be fixed later)

5. **20251117130200_extend_stories_table_for_voice_processing.sql**
   - Adds story-specific columns to `moments` table
   - References `moments` table and `capture_type` column
   - ⚠️ Indexes reference `capture_type` which will be renamed by migration #6
   - ✅ Safe to run (indexes will be recreated by migration #6)

6. **20251118000000_rename_memory_capture_type_to_memory_type.sql** ⭐ **PHASE 6** ✅ **APPLIED**
   - Renames `moments` → `memories` (if not already renamed)
   - Renames `capture_type`/`memory_capture_type` → `memory_type_enum`
   - Renames column `capture_type` → `memory_type`
   - Recreates story indexes with new column names
   - ✅ **COMPLETED** - Applied to database

7. **20251118000001_normalize_memory_text_columns.sql** ⭐ **PHASE 6** ✅ **APPLIED**
   - Renames `text_description` → `input_text`
   - Adds `processed_text` column
   - ✅ **COMPLETED** - Applied to database

8. **20251118000002_update_unified_timeline_feed_for_text_normalization.sql** ⭐ **PHASE 6** ✅ **APPLIED**
   - Updates `get_unified_timeline_feed` function to use new column names
   - ✅ **COMPLETED** - Applied to database

9. **20251118000003_align_story_processing_with_text_normalization.sql** ⭐ **PHASE 6** ✅ **APPLIED**
   - Drops `narrative_text` column (uses `processed_text` instead)
   - Updates comments
   - ✅ **COMPLETED** - Applied to database

10. **20251118000004_update_timeline_feed_for_text_normalization.sql** ⭐ **PHASE 6** ✅ **APPLIED**
    - Updates `get_timeline_feed` function to use new column names
    - ✅ **COMPLETED** - Applied to database

11. **20251118000005_add_search_vector_to_memories.sql** 🔍 **SEARCH FUNCTIONALITY**
    - Adds `search_vector tsvector` column to `memories` table
    - Creates trigger function to automatically compute search_vector on INSERT/UPDATE
    - Creates GIN index `idx_memories_search_vector` for fast full-text search
    - Backfills search_vector for existing rows
    - ✅ Must run after migrations #6-7 (requires normalized text columns)

12. **20251118000006_create_search_functionality.sql** 🔍 **SEARCH FUNCTIONALITY**
   - Creates `search_memories` RPC function for full-text search with pagination and ranking
   - Creates `recent_searches` table to store last 5 distinct queries per user
   - Creates RPC functions: `get_recent_searches()`, `upsert_recent_search()`, `clear_recent_searches()`
   - Adds validation (rejects empty queries) and logging (slow queries >1s)
   - ✅ Must run after migration #11 (requires search_vector column)

13. **20251209100000_add_story_audio_upload_error.sql**
   - Adds `audio_upload_error` column to `story_fields` so we can persist client-side upload failure details
   - ✅ Safe to run

## ⚠️ Deprecated Migrations (DO NOT RUN)

See `_deprecated/` folder for migrations that should not be applied.

### `_deprecated/20251117173014_rename_moments_to_memories.sql`
- **Status**: Superseded by `20251118000000_rename_memory_capture_type_to_memory_type.sql`
- **Reason**: Phase 6 migration consolidates Phase 5 work and is idempotent
- **Action**: Do not apply - use migration #6 instead

### `_deprecated/20250118000000_add_story_filter_to_timeline_feed.sql`
- **Status**: Superseded by `20251118000004_update_timeline_feed_for_text_normalization.sql`
- **Reason**: Uses legacy `moments` table and `text_description` / `capture_type` columns
- **Action**: Do not apply - run migration #10 instead

### `_deprecated/20250120000000_create_unified_timeline_feed.sql`
- **Status**: Superseded by `20251118000002_update_unified_timeline_feed_for_text_normalization.sql`
- **Reason**: Uses legacy schema and would overwrite normalized RPC
- **Action**: Do not apply - run migration #8 instead

## Migration Order Summary

```
1. 20250116000000 (creates moments table)
2. 20250118000000 (creates get_timeline_feed - will be updated later)
3. 20250119000000 (adds device_timestamp)
4. 20250120000000 (creates get_unified_timeline_feed - will be updated later)
5. 20251117130200 (adds story columns)
6. 20251118000000 ⭐ (renames table/enum/column - CRITICAL)
7. 20251118000001 ⭐ (normalizes text columns)
8. 20251118000002 ⭐ (updates get_unified_timeline_feed)
9. 20251118000003 ⭐ (aligns story processing)
10. 20251118000004 ⭐ (updates get_timeline_feed)
11. 20251118000005 🔍 (adds search_vector and indexing)
12. 20251118000006 🔍 (creates search_memories RPC and recent_searches table)
13. 20251209100000_add_story_audio_upload_error
```

## Notes

- Migrations #6-10 are Phase 6 migrations ✅ **ALL COMPLETED**
- Migration #6 is idempotent and handles both cases (whether Phase 5 was applied or not)
- Functions created in migrations #2 and #4 use old column names but are updated by migrations #8 and #10 ✅ **COMPLETED**
- Story indexes created in migration #5 reference `capture_type` but are recreated by migration #6 with `memory_type` ✅ **COMPLETED**
- Migration #11 adds full-text search support and requires Phase 6 text normalization (migrations #6-7) ✅ **READY TO APPLY**
- Migration #12 creates search API functions and recent searches persistence, requires migration #11 ✅ **READY TO APPLY**

## Phase 6 Status: ✅ COMPLETE

All Phase 6 migrations (migrations #6-10) have been successfully applied to the database. The normalized text model is now in place:
- ✅ `memories` table exists with `memory_type` column (enum: moment, story, memento)
- ✅ `input_text` column (renamed from `text_description`) - canonical raw user text
- ✅ `processed_text` column - LLM-processed version of input_text
- ✅ `title`, `generated_title`, and `tags` columns as defined in Phase 6 spec
- ✅ All RPC functions updated to use new column names
- ✅ App models (`MomentDetail`, `TimelineMoment`) aligned with Phase 6 text model
- ✅ `MemorySaveService` writes `memory_type`, `input_text`, and leaves `processed_text` null on initial save


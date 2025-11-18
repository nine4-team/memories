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

6. **20251118000000_rename_memory_capture_type_to_memory_type.sql** ⭐ **PHASE 6**
   - Renames `moments` → `memories` (if not already renamed)
   - Renames `capture_type`/`memory_capture_type` → `memory_type_enum`
   - Renames column `capture_type` → `memory_type`
   - Recreates story indexes with new column names
   - ✅ **CRITICAL** - Must run before migrations #7-9

7. **20251118000001_normalize_memory_text_columns.sql** ⭐ **PHASE 6**
   - Renames `text_description` → `input_text`
   - Adds `processed_text` column
   - ✅ **CRITICAL** - Must run after migration #6

8. **20251118000002_update_unified_timeline_feed_for_text_normalization.sql** ⭐ **PHASE 6**
   - Updates `get_unified_timeline_feed` function to use new column names
   - ✅ Must run after migrations #6-7

9. **20251118000003_align_story_processing_with_text_normalization.sql** ⭐ **PHASE 6**
   - Drops `narrative_text` column (uses `processed_text` instead)
   - Updates comments
   - ✅ Must run after migrations #6-7

10. **20251118000004_update_timeline_feed_for_text_normalization.sql** ⭐ **PHASE 6**
    - Updates `get_timeline_feed` function to use new column names
    - ✅ Must run after migrations #6-7 (used by `timeline_provider.dart`)

## ⚠️ Deprecated Migrations (DO NOT RUN)

See `_deprecated/` folder for migrations that should not be applied.

### `_deprecated/20251117173014_rename_moments_to_memories.sql`
- **Status**: Superseded by `20251118000000_rename_memory_capture_type_to_memory_type.sql`
- **Reason**: Phase 6 migration consolidates Phase 5 work and is idempotent
- **Action**: Do not apply - use migration #6 instead

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
```

## Notes

- Migrations #6-10 are Phase 6 migrations and must run in order
- Migration #6 is idempotent and handles both cases (whether Phase 5 was applied or not)
- Functions created in migrations #2 and #4 use old column names but are updated by migrations #8 and #10
- Story indexes created in migration #5 reference `capture_type` but are recreated by migration #6 with `memory_type`


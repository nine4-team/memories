# Deprecated Migrations

⚠️ **DO NOT APPLY THESE MIGRATIONS**

Migrations in this folder are deprecated and should not be run. They are kept for reference only.

## Deprecated Migrations

### `20251117173014_rename_moments_to_memories.sql`
**Status**: Superseded by `20251118000000_rename_memory_capture_type_to_memory_type.sql`

**Reason**: Phase 6 migration consolidates Phase 5 work (table/enum renames) along with text normalization. The Phase 6 migration is idempotent and handles both cases (whether Phase 5 was applied or not).

**Action**: Use `20251118000000_rename_memory_capture_type_to_memory_type.sql` instead.


# Phase 5: Data Model Rename & Spec Updates

## Objective

Align terminology with reality by renaming the existing `moments` table (and related enum/types) to `memories`, then update every spec/task/doc to describe the unified `memories` table architecture explicitly.

## Current State

- Implementation already stores Moments, Stories, and Mementos in `public.moments` with a `capture_type` enum.
- Specs still describe a dedicated `mementos` table, causing confusion.
- The only misalignment is naming/communication—not behavior.

## Target State

1. Database objects are named `memories` (table), `memory_capture_type` (enum), etc.
2. Generated Supabase types and Dart models reference `memories`.
3. Specs/tasks talk about the `memories` table and explain how different memory types are filtered via `capture_type`.

## Implementation Steps

### Step 1: Prepare Migration Plan

- Create a migration to:
  1. Rename the enum `capture_type` → `memory_capture_type`.
  2. Update any columns using that enum.
  3. Rename `public.moments` → `public.memories`.
  4. Rename indexes, sequences, triggers, and foreign-key references whose names include `moments`.
- Draft rollback SQL (rename back) in case deployment fails.

### Step 2: Implement Supabase Migration

1. Add new migration `supabase/migrations/<timestamp>_rename_moments_to_memories.sql`.
2. SQL outline:
   - `ALTER TYPE capture_type RENAME TO memory_capture_type;`
   - `ALTER TABLE public.moments RENAME TO memories;`
   - Rename each index: `ALTER INDEX idx_moments_capture_type RENAME TO idx_memories_capture_type;`
   - Update comments/RLS policies referencing `moments`.
3. Test locally (`supabase db reset` or dev branch) before committing.

### Step 3: Regenerate Types/Clients

- Run `supabase gen types typescript --project-ref ...` (or existing script) so generated API clients reference `memories`.
- Update any Dart types generated from Supabase (if using `supabase` CLI or custom build steps).

### Step 4: Update Application Code

1. Search for `"moments"` in repo; update SQL queries, table constants, and Supabase client calls to `"memories"`.
2. Update any references to `capture_type` enum string if name changed.
3. Ensure services like `MemorySaveService`, timeline providers, etc., read/write the new table name.

### Step 5: Update Specs & Docs

For each document below, rewrite the “Data & Storage” sections to describe the `memories` table, not separate per-type tables. Emphasize that `capture_type` differentiates rows.

Files:
1. `agent-os/specs/2025-11-16-memento-creation-display/spec.md`
2. `agent-os/specs/2025-11-16-memento-creation-display/planning/requirements.md`
3. `agent-os/specs/2025-11-16-memento-creation-display/tasks.md`
4. `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`
5. `agent-os/specs/2025-11-16-moment-creation-text-media/planning/requirements.md`
6. `agent-os/specs/2025-11-16-story-list-detail-views/spec.md`
7. `agent-os/specs/2025-11-16-unified-timeline-feed/spec.md`
8. Any related implementation notes referencing “moments table.”

Also update:
- `docs/memory-implementation-issues.md` (mark issue resolved once migration ships).
- Create/Update `docs/data-model-decision.md` summarizing the rationale for unified naming.

### Step 6: QA & Verification

1. Apply migration to staging/dev Supabase branch; run automated DB tests if available.
2. Run full integration tests (capture → save → timeline) after code updates.
3. Manual QA scenarios:
   - Save each memory type (moment/story/memento).
   - Verify timeline feed queries show all types.
   - Ensure analytics/logging still receives the correct table names.
4. After deployment, monitor Supabase logs for queries still hitting `moments`.

## Risk Assessment

- **Risk Level**: Medium
- Risks: breaking queries that still reference `moments`, missing index renames, or stale generated types.
- Mitigations: comprehensive search/replace, automated tests, staging verification, rollback script.

## Success Criteria

- [ ] Supabase schema uses `memories` terminology everywhere.
- [ ] App/services/tests compile and run against new table name.
- [ ] Specs/tasks describe the unified `memories` table clearly.
- [ ] No runtime errors referencing `moments`.
- [ ] Issue #3 in `memory-implementation-issues.md` updated to “resolved”.

## Dependencies

- None on earlier phases, but schedule after Phase 2 so the `inputText` rename doesn’t collide with DB work.


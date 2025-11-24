# Plan: Manual Date Input for Memories

## Implementation Status

**Last Updated**: 2025-11-24 (Implementation complete - UI and backend finished)

### Completed ✅
- Backend migrations (database schema, RPC functions) - memory_date is now NOT NULL
- Backend functions updated to use memory_date directly (no COALESCE)
- Test data updated to have memory_date set
- Frontend models (MemoryDetail, TimelineMemory) - memoryDate is now non-nullable
- Service layer (MemorySaveService, MemoryDetailService, offline queue sync)
- Provider updates (CaptureStateNotifier, loadMemoryForEdit methods)
- Memory detail screen integration (passing memoryDate to edit flows)
- Timeline adapters updated to use effectiveDate
- Unified feed repository updated to sort by effectiveDate

### In Progress 🚧
- None

### Pending ⏳
- None

---

## Overview

Add a user-editable `memory_date` field that represents when the memory actually occurred. The timeline will prefer this user-specified date, falling back to `captured_at` (which uses `device_timestamp` or `created_at`) when not set.

---

## Memory Date Semantics

- `memory_date` represents **when the memory actually happened**, including time, in the user's local timezone.
- The user **always picks both a date and a time** when editing `memory_date` (capture screen and detail screen).
  - Default when creating: current local date & time.
  - Default when editing: current `memoryDate` converted to local time.
- We store the chosen local date & time as a `TIMESTAMPTZ` in UTC for consistency with the rest of the schema.
- In the UI we primarily show the **date**, and optionally show the time where it adds value (for example, births or specific moments).
- `memory_date` is **required** - all memories must have it set. No backwards compatibility - test data has been updated.

---

## 1. Backend Changes ✅

### 1.1 Database Schema Migration ✅

**Migration Files**: 
- `supabase/migrations/20251124144224_add_memory_date_to_memories.sql` ✅
- `make_memory_date_required` ✅

- Add `memory_date TIMESTAMPTZ` column to `public.memories` table
  - **NOT NULL** (required field)
  - Updated existing test data to use device_timestamp or created_at
  - Add index: `CREATE INDEX idx_memories_memory_date ON public.memories (memory_date DESC)`
  - Add comment: `COMMENT ON COLUMN public.memories.memory_date IS 'User-specified date and time when the memory occurred (stored as TIMESTAMPTZ in UTC). Required field. Used for timeline ordering and grouping.'`

### 1.2 Update Timeline Feed Function (`get_unified_timeline_feed`) ✅

**Migration Files**: 
- `supabase/migrations/20251124144225_update_timeline_feed_for_memory_date.sql` ✅
- `remove_coalesce_from_timeline_functions` ✅

- Change ordering logic:
  - Order by: `m.memory_date DESC` (memory_date is now required)
  - Update cursor pagination to use memory_date
- Update grouping fields:
  - Extract year/month/day/season from: `m.memory_date`
- Update `captured_at` output:
  - Return: `m.memory_date as captured_at`
- Update cursor parameters:
  - Use memory_date for cursor comparison

### 1.3 Update Memory Detail RPC (`get_memory_detail`) ✅

**Migration File**: `supabase/migrations/20251124144226_add_memory_date_to_memory_detail.sql` ✅

- Include `memory_date` in the SELECT statement
- Return `memory_date` in the response JSON

### 1.4 Update Years Function (`get_unified_timeline_years`) ✅

**Migration Files**: 
- `supabase/migrations/20251124144227_update_timeline_years_for_memory_date.sql` ✅
- `update_timeline_years_for_memory_date` ✅

- Extract years from: `m.memory_date` (memory_date is now required)
- Ensure DISTINCT years are returned correctly

### 1.5 API Contract Updates

- `memory_date` is optional in insert/update operations
- If provided, must be a valid ISO8601 timestamp
- Validation: Allow past dates (no restriction). For future dates, allow but require a single clear confirmation in the UI.

---

## 2. Frontend Model Changes ✅

### 2.1 Update `MemoryDetail` Model ✅

**File**: `lib/models/memory_detail.dart` ✅

- Add field: `final DateTime memoryDate;` (non-nullable, required)
- Update constructor to include required `memoryDate` parameter
- Update `fromJson` factory to parse `memory_date` field (required)
- Update getter `effectiveDate`:
  ```dart
  DateTime get effectiveDate => memoryDate;
  ```

### 2.2 Update `TimelineMemory` Model ✅

**File**: `lib/models/timeline_memory.dart` ✅

- Add field: `final DateTime memoryDate;` (non-nullable, required)
- Update constructor to include required `memoryDate` parameter
- Update `fromJson` factory to parse `memory_date` field (required)
- Update `effectiveDate` getter:
  ```dart
  DateTime get effectiveDate => memoryDate;
  ```

### 2.3 Update `CaptureState` Model ✅

**File**: `lib/models/capture_state.dart` ✅

- ✅ Add field: `final DateTime? memoryDate;`
- ✅ Update `copyWith` method to include `memoryDate`
- ✅ Add method: `void setMemoryDate(DateTime? date)` in the notifier (`lib/providers/capture_state_provider.dart`)

### 2.4 Update `QueuedMemory` Model ✅

**File**: `lib/models/queued_memory.dart` ✅

- Add field: `final DateTime? memoryDate;`
- Update `fromCaptureState` factory to include `memoryDate`
- Update `toCaptureState` method to include `memoryDate`
- Update JSON serialization/deserialization to handle `memoryDate`

---

## 3. Service Layer Changes ✅

### 3.1 Update `MemorySaveService` ✅

**File**: `lib/services/memory_save_service.dart` ✅

- ✅ Include `memory_date` in insert payload when set in `CaptureState`
- ✅ Include `memory_date` in update payload when editing existing memory

### 3.2 Update `MemoryDetailService` ✅

**File**: `lib/services/memory_detail_service.dart` ✅

- ✅ Include `memory_date` in update operations (added `updateMemoryDate` method)
- ✅ Ensure RPC calls handle the new field correctly (cache updated to include memory_date)

### 3.3 Update Offline Queue Sync ✅

**File**: `lib/services/offline_memory_queue_service.dart` ✅

- ✅ Include `memory_date` when syncing queued memories to server (handled via `toCaptureState` in QueuedMemory)
- ✅ Ensure `memory_date` is preserved during sync operations (serialization/deserialization updated)

---

## 4. UI Changes ✅

### 4.1 Capture Screen ✅

**File**: `lib/screens/capture/capture_screen.dart` ✅

**Date Picker UI:** ✅
- ✅ Location: As a dedicated, full-width, tappable bar **just above** the swipeable input container (`_SwipeableInputContainer` for dictation/type), and **below** any media/tags container.
- ✅ Default: Show current memory date/time (for new memories: now; for edits: existing `memoryDate`).
- ✅ Format: A full-width row such as `"Date & time   [Formatted Value]   [Chevron/Icon]"` that visually matches other metadata/setting rows in the app.
- ✅ When tapped: Open date & time picker flow (see below).

**Date & Time Picker Dialog:** ✅
- ✅ Use Flutter's `showDatePicker` followed by `showTimePicker` as a single flow.
- ✅ When the user taps the date field:
  1. Open `showDatePicker` (past dates allowed).
  2. After a date is chosen, immediately open `showTimePicker` for that same date.
- ✅ Default values:
  - When creating a new memory: current local date/time.
  - When editing: current `memoryDate` converted to local time.
- Note: `memory_date` is required, so date/time is always set (no clear option needed).

### 4.2 Memory Detail Screen ✅

**File**: `lib/screens/memory/memory_detail_screen.dart` ✅

**Date Display:** ✅
- ✅ Add date display in metadata section
- ✅ Show `memoryDate` (now required, no fallback needed)
- ✅ Format: "Date: [Formatted Date] [Edit Icon]" (if editable)

**Date Editing:** ✅
- ✅ Tap date to open date picker
- ✅ Update via API when changed (service method exists: `updateMemoryDate`)
- ✅ Show loading state during update
- ✅ Handle offline: Shows error message if offline (editing requires online connection)

### 4.3 Edit Mode ✅

**File**: `lib/providers/capture_state_provider.dart` ✅

- ✅ Update `loadMemoryForEdit`:
  - ✅ Include `memoryDate` when loading existing memory
- ✅ Update `loadOfflineMemoryForEdit`:
  - ✅ Include `memoryDate` for offline queued memories
- ✅ Updated `MemoryDetailScreen` to pass `memoryDate` when calling edit methods
- ✅ Updated `OfflineMemoryDetailProvider` to include `memoryDate` when converting from QueuedMemory

### 4.4 Metadata Widget ✅

**File**: `lib/widgets/memory_metadata_section.dart` ✅

- ✅ Update to show `memoryDate` (now required, no fallback needed)
- ✅ Make date tappable to edit (via optional `onDateTap` callback)
- ✅ Convert UTC to local time for display

---

## 5. Timeline Integration ⏳

### 5.1 Update Timeline Sorting ✅

**File**: `lib/services/unified_feed_repository.dart` ✅

- ✅ Ensure merged feed uses `effectiveDate` for sorting
- ✅ Update offline merge logic to use `effectiveDate`

### 5.2 Update Timeline Grouping ✅

**File**: `lib/screens/timeline/unified_timeline_screen.dart` ✅

- ✅ Backend already returns grouping fields based on memory_date
- ✅ Timeline adapters use effectiveDate (which is memoryDate)
- Note: Timeline screen should already work correctly since backend and adapters are updated

### 5.3 Update Adapters ✅

**Files**: 
- `lib/services/offline_queue_to_timeline_adapter.dart` ✅
- `lib/services/preview_index_to_timeline_adapter.dart` ✅

- ✅ `OfflineQueueToTimelineAdapter`: Uses `memoryDate` if available, falls back to `capturedAt`
- ✅ `PreviewIndexToTimelineAdapter`: Uses `capturedAt` as `memoryDate` (preview doesn't store separate memoryDate)

### 5.4 Search & Filtering Alignment ✅

- ✅ Updated `get_timeline_feed` function to use memory_date directly for search results
- ✅ Backend functions now consistently use `m.memory_date` for date operations (no COALESCE needed)
- ✅ This keeps search results and the timeline consistent about "when" a memory lives

---

## 6. Data Migration Strategy

### 6.1 Existing Memories ✅

- ✅ Migration completed: All existing test data has `memory_date` set
- ✅ `memory_date` is now required (NOT NULL)
- ✅ Timeline uses `memory_date` directly (no fallback)
- Users can manually set dates for old memories via edit

### 6.2 Optional: Bulk Date Import

- If importing historical memories, provide a way to set `memory_date` during import
- Consider a migration script if bulk date updates are needed

---

## 7. Edge Cases & Validation

### 7.1 Date Validation

- Allow past dates (no restriction)
- Future dates: Allow but show a warning and require a single explicit confirmation before saving
- Timezone: Store in UTC, display in user's local timezone

### 7.2 Offline Behavior

- Store `memory_date` in queued memory
- Sync `memory_date` when memory syncs to server
- Preserve `memory_date` during retries

### 7.3 Edit Behavior

- When editing, preserve `memory_date` (required field)
- Allow changing `memory_date` to any date/time
- Show "Today" quick action to reset to current date/time

---

## 8. User Experience Flow

### 8.1 Creating New Memory

1. User captures memory (default: current date/time)
2. User can tap date field to change it
3. Date picker opens, user selects date/time
4. Memory is saved with `memory_date` set
5. Timeline shows memory at selected date

### 8.2 Editing Existing Memory

1. User opens memory detail
2. User taps date in metadata section
3. Date picker opens with current `memory_date` (required field)
4. User changes date
5. Memory updates, timeline repositions if needed

### 8.3 Viewing Timeline

1. Timeline orders by `memory_date` (required field)
2. Timeline groups by `memory_date` (year/month)
3. Memories appear at their `memory_date` position

---

## 9. Testing Considerations

### 9.1 Unit Tests

- Test date fallback logic (`effectiveDate` getter)
- Test date serialization/deserialization
- Test date validation

### 9.2 Integration Tests

- Test timeline ordering with mixed dates (some with `memory_date`, some without)
- Test offline queue with `memory_date`
- Test edit flow with date changes

### 9.3 Edge Cases

- Test with future dates
- Test with very old dates
- Test timezone handling
- Note: `memory_date` is required, so NULL tests are no longer applicable

### 9.4 Backend / SQL Tests

- Test `get_unified_timeline_feed` ordering and cursor pagination using `memory_date` directly.
- Test `get_unified_timeline_years` to ensure years are derived from `memory_date`.
- Test any date-based search/filter endpoints to confirm they align with the timeline's memory_date behavior.

---

## 10. Implementation Order

1. ✅ **Backend**: Database migration + RPC updates
2. ✅ **Models**: Update all models to include `memory_date` (non-nullable)
3. ✅ **Services**: Update save/update services
4. ✅ **Integration**: Update timeline to use `effectiveDate`
5. ✅ **UI**: Add date picker to capture screen
6. ✅ **UI**: Add date display/edit to detail screen
7. ⏳ **Testing**: Verify end-to-end flow
8. ⏳ **Polish**: Small UX refinements (copy, formatting, minor layout tweaks)

---

## Summary

This plan adds:
- A required `memory_date` field in the database (NOT NULL)
- Timeline ordering/grouping that uses `memory_date` directly
- Date picker UI in capture and edit screens (pending)
- Offline support for date changes

**No backwards compatibility** - all memories must have `memory_date` set. Test data has been updated.


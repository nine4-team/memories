# Plan: Manual Date Input for Memories

## Overview

Add a user-editable `memory_date` field that represents when the memory actually occurred. The timeline will prefer this user-specified date, falling back to `captured_at` (which uses `device_timestamp` or `created_at`) when not set.

---

## 1. Backend Changes

### 1.1 Database Schema Migration

**New Migration File**: `supabase/migrations/[timestamp]_add_memory_date_to_memories.sql`

- Add `memory_date TIMESTAMPTZ` column to `public.memories` table
  - Nullable (existing memories won't have it)
  - No default value (user must explicitly set it)
  - Add index: `CREATE INDEX idx_memories_memory_date ON public.memories (memory_date DESC) WHERE memory_date IS NOT NULL`
  - Add comment: `COMMENT ON COLUMN public.memories.memory_date IS 'User-specified date when the memory occurred. Used for timeline ordering and grouping. Falls back to captured_at if not set.'`

### 1.2 Update Timeline Feed Function (`get_unified_timeline_feed`)

**File**: `supabase/migrations/[timestamp]_update_timeline_feed_for_memory_date.sql`

- Change ordering logic:
  - Order by: `COALESCE(m.memory_date, m.device_timestamp, m.created_at) DESC`
  - Update cursor pagination to use the same coalesced value
- Update grouping fields:
  - Extract year/month/day/season from: `COALESCE(m.memory_date, m.device_timestamp, m.created_at)`
- Update `captured_at` output:
  - Return: `COALESCE(m.memory_date, m.device_timestamp, m.created_at) as captured_at`
- Update cursor parameters:
  - Use the coalesced date for cursor comparison (not just `created_at`)

### 1.3 Update Memory Detail RPC (`get_memory_detail`)

**File**: `supabase/migrations/[timestamp]_add_memory_date_to_memory_detail.sql`

- Include `memory_date` in the SELECT statement
- Return `memory_date` in the response JSON

### 1.4 Update Years Function (`get_unified_timeline_years`)

**File**: Same migration as 1.2 or separate

- Extract years from: `COALESCE(m.memory_date, m.device_timestamp, m.created_at)`
- Ensure DISTINCT years are returned correctly

### 1.5 API Contract Updates

- `memory_date` is optional in insert/update operations
- If provided, must be a valid ISO8601 timestamp
- Validation: Allow past dates (no restriction), optionally warn on future dates (or allow with confirmation)

---

## 2. Frontend Model Changes

### 2.1 Update `MemoryDetail` Model

**File**: `lib/models/memory_detail.dart`

- Add field: `final DateTime? memoryDate;`
- Update constructor to include `memoryDate` parameter
- Update `fromJson` factory to parse `memory_date` field
- Add getter `effectiveDate`:
  ```dart
  DateTime get effectiveDate => memoryDate ?? capturedAt;
  ```

### 2.2 Update `TimelineMemory` Model

**File**: `lib/models/timeline_memory.dart`

- Add field: `final DateTime? memoryDate;`
- Update constructor to include `memoryDate` parameter
- Update `fromJson` factory to parse `memory_date` field
- Update `effectiveDate` getter (if exists) or add it:
  ```dart
  DateTime get effectiveDate => memoryDate ?? capturedAt;
  ```

### 2.3 Update `CaptureState` Model

**File**: `lib/models/capture_state.dart`

- Add field: `final DateTime? memoryDate;`
- Update `copyWith` method to include `memoryDate`
- Add method: `void setMemoryDate(DateTime? date)` in the notifier

### 2.4 Update `QueuedMemory` Model

**File**: `lib/models/queued_memory.dart`

- Add field: `final DateTime? memoryDate;`
- Update `fromCaptureState` factory to include `memoryDate`
- Update `toCaptureState` method to include `memoryDate`
- Update JSON serialization/deserialization to handle `memoryDate`

---

## 3. Service Layer Changes

### 3.1 Update `MemorySaveService`

**File**: `lib/services/memory_save_service.dart`

- Include `memory_date` in insert payload when set in `CaptureState`
- Include `memory_date` in update payload when editing existing memory

### 3.2 Update `MemoryDetailService`

**File**: `lib/services/memory_detail_service.dart`

- Include `memory_date` in update operations
- Ensure RPC calls handle the new field correctly

### 3.3 Update Offline Queue Sync

**File**: `lib/services/offline_memory_queue_service.dart`

- Include `memory_date` when syncing queued memories to server
- Ensure `memory_date` is preserved during sync operations

---

## 4. UI Changes

### 4.1 Capture Screen

**File**: `lib/screens/capture/capture_screen.dart`

**Date Picker UI:**
- Location: Below title/input area, above media section
- Default: Show current date/time
- Format: "Date: [Date Display] [Edit Button]"
- When tapped: Open date/time picker dialog

**Date Picker Dialog:**
- Use Flutter's `showDatePicker` + `showTimePicker`
- Allow date selection (past dates allowed)
- Optional: Allow time selection (default to current time or 12:00 PM)
- Show "Today" quick action button
- Show "Clear" button to remove custom date (fall back to auto)

**Visual Indicator:**
- Show badge/icon when date is manually set vs auto-generated
- Example: "📅 Custom date" vs "📅 Auto date"

### 4.2 Memory Detail Screen

**File**: `lib/screens/memory/memory_detail_screen.dart`

**Date Display:**
- Add date display in metadata section
- Show `effectiveDate` (prefer `memoryDate`, fall back to `capturedAt`)
- Show indicator if date is manually set
- Format: "Date: [Formatted Date] [Edit Icon]" (if editable)

**Date Editing:**
- Tap date to open date picker
- Update via API when changed
- Show loading state during update
- Handle offline: Queue date update if offline

### 4.3 Edit Mode

**File**: `lib/providers/capture_state_provider.dart`

- Update `loadMemoryForEdit`:
  - Include `memoryDate` when loading existing memory
- Update `loadOfflineMemoryForEdit`:
  - Include `memoryDate` for offline queued memories

### 4.4 Metadata Widget

**File**: `lib/widgets/memory_metadata_section.dart`

- Update to show `effectiveDate` instead of `capturedAt`
- Add visual indicator for manually set dates
- Make date tappable to edit (if user owns memory)

---

## 5. Timeline Integration

### 5.1 Update Timeline Sorting

**File**: `lib/services/unified_feed_repository.dart`

- Ensure merged feed uses `effectiveDate` for sorting
- Update offline merge logic to use `effectiveDate`

### 5.2 Update Timeline Grouping

**File**: `lib/screens/timeline/unified_timeline_screen.dart`

- Group by `effectiveDate` (year/month) instead of `capturedAt`
- Ensure year sidebar reflects `effectiveDate`

### 5.3 Update Adapters

**Files**: 
- `lib/services/offline_queue_to_timeline_adapter.dart`
- `lib/services/preview_index_to_timeline_adapter.dart`

- `OfflineQueueToTimelineAdapter`: Use `memoryDate` if available
- `PreviewIndexToTimelineAdapter`: Use `memoryDate` if available in preview

---

## 6. Data Migration Strategy

### 6.1 Existing Memories

- No migration needed initially
- `memory_date` will be NULL for existing memories
- Timeline will fall back to `captured_at` (current behavior)
- Users can manually set dates for old memories via edit

### 6.2 Optional: Bulk Date Import

- If importing historical memories, provide a way to set `memory_date` during import
- Consider a migration script if bulk date updates are needed

---

## 7. Edge Cases & Validation

### 7.1 Date Validation

- Allow past dates (no restriction)
- Future dates: Allow but show a warning (or require confirmation)
- Timezone: Store in UTC, display in user's local timezone

### 7.2 Offline Behavior

- Store `memory_date` in queued memory
- Sync `memory_date` when memory syncs to server
- Preserve `memory_date` during retries

### 7.3 Edit Behavior

- When editing, preserve `memory_date` if set
- Allow clearing `memory_date` to revert to auto date
- Show "Reset to capture date" option in date picker

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
3. Date picker opens with current `memory_date` (or `capturedAt` if not set)
4. User changes date
5. Memory updates, timeline repositions if needed

### 8.3 Viewing Timeline

1. Timeline orders by `effectiveDate` (prefers `memory_date`)
2. Timeline groups by `effectiveDate` (year/month)
3. Memories appear at their `effectiveDate` position

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

- Test with NULL `memory_date` (should use `captured_at`)
- Test with future dates
- Test with very old dates
- Test timezone handling

---

## 10. Implementation Order

1. **Backend**: Database migration + RPC updates
2. **Models**: Update all models to include `memory_date`
3. **Services**: Update save/update services
4. **UI**: Add date picker to capture screen
5. **UI**: Add date display/edit to detail screen
6. **Integration**: Update timeline to use `effectiveDate`
7. **Testing**: Verify end-to-end flow
8. **Polish**: Add visual indicators and UX refinements

---

## Summary

This plan adds:
- A nullable `memory_date` field in the database
- Timeline ordering/grouping that prefers `memory_date` over `captured_at`
- Date picker UI in capture and edit screens
- Visual indicators for manually set dates
- Offline support for date changes

The implementation maintains backward compatibility: existing memories without `memory_date` continue to work using `captured_at`.


# Phase 1: Fix Transcript → inputText Bug

## Objective

Fix the critical bug where dictation text populates `rawTranscript` but not the canonical text field, breaking the intended UX where dictation text should automatically appear in (and be saved as) the input text field.

## Current Behavior

- Dictation service populates `rawTranscript` via `capture_state_provider.dart`
- `description` remains separate and empty unless manually edited
- This violates the "no extra fields" promise and breaks validation logic

## Target Behavior

- When dictation produces text, it should automatically populate `inputText`
- The same text should appear in the input text UI
- `rawTranscript` field is removed entirely - no backward compatibility
- `description` field is renamed to `inputText` to match the unified field name

## Implementation Steps

### Step 1: Update CaptureState Model
**File**: `lib/models/capture_state.dart`

**Changes**:
1. Remove `rawTranscript` field entirely
2. Rename `description` → `inputText`
3. Update `canSave` getter to use `inputText`
4. Update all copyWith methods to remove `rawTranscript` and use `inputText`

### Step 2: Update CaptureStateProvider
**File**: `lib/providers/capture_state_provider.dart`

**Changes**:
1. Update `_transcriptSubscription` to set `inputText` directly (no `rawTranscript`)
2. Update `updateDescription()` → `updateInputText()`
3. Update `stopDictation()` to set `inputText` from final transcript
4. Update `loadMomentForEdit()` to use `inputText` parameter

### Step 3: Update CaptureScreen UI
**File**: `lib/screens/capture/capture_screen.dart`

**Changes**:
1. Update TextField controller binding to use `state.inputText`
2. Update `updateDescription` calls → `updateInputText`
3. Update dictation control to display `state.inputText` instead of `state.rawTranscript`

### Step 4: Update Save Service
**File**: `lib/services/moment_save_service.dart`

**Changes**:
1. Update `saveMoment()` to read `state.inputText` instead of `state.description`/`state.rawTranscript`
2. Remove `raw_transcript` from database insert
3. Update title generation logic to use `inputText` only

### Step 5: Update Moment Detail Screen
**File**: `lib/screens/moment/moment_detail_screen.dart`

**Changes**:
1. Update `loadMomentForEdit()` call to use `inputText` parameter instead of `description`

### Step 6: Update Tests
**Files**: 
- `test/providers/capture_state_provider_test.dart`

**Changes**:
- Update all tests to use `inputText` instead of `description` or `rawTranscript`
- Remove any assertions checking `rawTranscript`
- Verify validation logic works with `inputText` populated from dictation

## Files Modified (Phase 1 Complete)

1. ✅ `lib/models/capture_state.dart` - Renamed `description` → `inputText`, removed `rawTranscript`
2. ✅ `lib/providers/capture_state_provider.dart` - Updated to use `inputText`, removed `rawTranscript`
3. ✅ `lib/screens/capture/capture_screen.dart` - Updated to use `inputText`
4. ✅ `lib/services/moment_save_service.dart` - Updated to use `inputText`, removed `raw_transcript` from DB insert
5. ✅ `lib/screens/moment/moment_detail_screen.dart` - Updated `loadMomentForEdit()` call
6. ✅ `test/providers/capture_state_provider_test.dart` - Updated tests to use `inputText`

## Files Updated (Phase 1 Complete + Phase 2 Complete)

All files that referenced `rawTranscript` or `description` have been updated:

1. ✅ **Queue Models**:
   - ✅ `lib/models/queued_moment.dart` - Removed `rawTranscript`, renamed `description` → `inputText`
   - ✅ `lib/models/queued_story.dart` - Removed `rawTranscript`, renamed `description` → `inputText`
   - ✅ Updated `fromCaptureState` factory methods to use `state.inputText`
   - ✅ Updated `toCaptureState` methods to use `inputText`
   - ✅ Updated JSON serialization/deserialization to use `inputText` only (no backward compatibility)

2. ✅ **Timeline/Detail Models**:
   - ✅ `lib/models/timeline_moment.dart` - Removed `rawTranscript` field
   - ✅ `lib/models/moment_detail.dart` - Removed `rawTranscript` field
   - ✅ Updated JSON parsing to ignore `raw_transcript` (database still has column, but we use `text_description` only)

3. ✅ **Services**:
   - ✅ `lib/services/moment_detail_service.dart` - Removed `raw_transcript` from cache serialization
   - Note: `offline_queue_service.dart` doesn't directly reference these fields - it uses the queue models

4. ✅ **UI Screens**:
   - ✅ `lib/screens/moment/moment_detail_screen.dart` - Updated to use `textDescription` only, removed `rawTranscript` fallback

5. ✅ **Edge Functions**:
   - ✅ `supabase/functions/generate-title/index.ts` - Edge function receives `transcript` parameter from request body (not database column)
   - ✅ No changes needed - edge function works correctly with `inputText` → `text_description` flow

## Risk Assessment

**Risk Level**: Low
- Isolated change to capture state and related providers
- Doesn't affect database schema (still uses `text_description` column)
- Easy to rollback if issues arise
- Queue models and other downstream consumers will be updated in Phase 2

## Success Criteria

- [x] Dictation text automatically populates `inputText` field
- [x] Input text field displays dictation text in UI
- [x] Manual edits to input text field persist correctly
- [x] Validation logic works correctly for all memory types using `inputText`
- [x] All existing tests pass
- [x] New tests verify transcript→inputText flow
- [x] `rawTranscript` field removed from `CaptureState`
- [x] `description` field renamed to `inputText` in `CaptureState`

## Notes

- ✅ Phase 1 completed: `CaptureState` and immediate consumers (provider, UI, save service)
- ✅ Phase 2 completed: Queue models, timeline/detail models, and other downstream consumers
- Database column remains `text_description` (no schema changes needed)
- Queue models use `inputText` only in JSON serialization (no backward compatibility)
- Timeline/detail models ignore `raw_transcript` from database (use `text_description` only)
- All code now uses `inputText` as the single canonical field in `CaptureState` and queue models
- Edge functions work correctly - no changes needed

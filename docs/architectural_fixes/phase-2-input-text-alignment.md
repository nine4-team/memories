# Phase 2: input_text Alignment Refactor

## Objective

Replace the current `description`/`rawTranscript` split with one canonical `inputText` field that's shared by capture state, sync queues, Supabase tables, and analytics. Dictation pipes into it, manual edits happen there, and downstream consumers read the same value.

## Current State

- `CaptureState` has both `rawTranscript` and `description` fields
- `QueuedMoment` and `QueuedStory` have both fields
- Database uses `text_description` column
- Services read/write both fields inconsistently
- Analytics events may reference either field

## Target State

- Single `inputText` field in `CaptureState`
- Single `inputText` field in queue models
- Database column remains `text_description` for now (can rename later)
- All services read/write `inputText`
- Analytics events use `inputText`
- Dictation populates `inputText` directly
- Manual edits update `inputText` directly

## Implementation Steps

### Step 1: Update CaptureState Model
**File**: `lib/models/capture_state.dart`

**Changes**:
1. Remove `rawTranscript` field
2. Rename `description` → `inputText`
3. Update `canSave` getter to use `inputText`
4. Update all copyWith methods

**Migration Strategy**: 
- Keep old fields temporarily with `@Deprecated` annotations
- Add `inputText` getter that reads from `description` (for backward compatibility during transition)
- This allows gradual migration

**Better Approach**: Do a clean break - remove old fields entirely and update all call sites in one go.

### Step 2: Update CaptureStateProvider
**File**: `lib/providers/capture_state_provider.dart`

**Changes**:
1. Update `_transcriptSubscription` to set `inputText` instead of `rawTranscript`
2. Update `updateDescription()` → `updateInputText()`
3. Update `stopDictation()` to set `inputText` from final transcript
4. Update all state updates to use `inputText`

### Step 3: Update Queue Models
**Files**:
- `lib/models/queued_moment.dart`
- `lib/models/queued_story.dart`

**Changes**:
1. Remove `rawTranscript` field
2. Rename `description` → `inputText`
3. Update `fromCaptureState` factory methods
4. Update serialization/deserialization (JSON keys)
5. Update version number if breaking change

**Serialization**: Update JSON keys from `"description"` and `"rawTranscript"` to `"inputText"`. Handle migration of existing queued items.

### Step 4: Update Timeline/Detail Models
**Files**:
- `lib/models/timeline_moment.dart`
- `lib/models/moment_detail.dart`

**Changes**:
1. Rename `description` → `inputText` (if they have description fields)
2. Update fromJson/toJson methods
3. Check if they reference `rawTranscript` anywhere

### Step 5: Update Save Service
**File**: `lib/services/moment_save_service.dart`

**Changes**:
1. Update `saveMoment()` to read `state.inputText` instead of `state.description`/`state.rawTranscript`
2. Update database insert to use `text_description` column (map `inputText` → `text_description`)
3. Update title generation logic to use `inputText`
4. Update analytics events to use `inputText`

**Database Mapping**:
```dart
'text_description': state.inputText,  // Map inputText to DB column
// Remove raw_transcript field entirely or set to null
```

### Step 6: Update Offline Queue Service
**File**: `lib/services/offline_queue_service.dart`

**Changes**:
1. Update queue serialization to use `inputText`
2. Update queue deserialization to read `inputText`
3. Handle migration of existing queued items (convert old format to new)

**Migration Logic**:
```dart
// When deserializing old format:
final inputText = json['inputText'] ?? 
                  json['description'] ?? 
                  json['rawTranscript'] ?? 
                  null;
```

### Step 7: Update Capture Screen UI
**File**: `lib/screens/capture/capture_screen.dart`

**Changes**:
1. Update TextField controller binding to use `state.inputText`
2. Update `updateDescription` calls → `updateInputText`
3. Update any references to `rawTranscript` or `description`

### Step 8: Update Analytics/Events
**Files**: Search for analytics event calls

**Changes**:
1. Find all analytics events that reference `description` or `rawTranscript`
2. Update to use `inputText`
3. Update event parameter names if needed

### Step 9: Update All Tests
**Files**: All test files that reference `description` or `rawTranscript`

**Changes**:
1. Update test fixtures to use `inputText`
2. Update test assertions
3. Add tests for migration logic (old queue format → new format)
4. Update mock data

**Key Test Files**:
- `test/providers/capture_state_provider_test.dart`
- `test/models/capture_state_test.dart` (if exists)
- `test/services/moment_save_service_test.dart`
- `test/services/offline_queue_service_test.dart`
- `test/widgets/capture_screen_test.dart` (if exists)

### Step 10: Update Edge Functions (if needed)
**Files**: 
- `supabase/functions/generate-title/index.ts`

**Changes**:
1. Check if edge function expects `raw_transcript` parameter
2. Update to accept `input_text` or `text_description`
3. Update function documentation

### Step 11: Database Migration (Optional - Future)
**File**: Create new migration (defer to later phase)

**Note**: We can keep `text_description` column name in database for now. Later migration can rename it to `input_text` if desired, but that requires:
- Coordinated app deployment
- Type regeneration
- More complex migration

For Phase 2, we'll just map `inputText` → `text_description` in the app layer.

## Migration Strategy for Existing Data

### Queued Items
- When deserializing queued moments/stories, check for old format
- Convert `description`/`rawTranscript` → `inputText`
- Save in new format going forward

### Database
- Existing rows already have `text_description` populated
- No migration needed - just read from `text_description` into `inputText` field

## Files to Modify

1. `lib/models/capture_state.dart`
2. `lib/providers/capture_state_provider.dart`
3. `lib/models/queued_moment.dart`
4. `lib/models/queued_story.dart`
5. `lib/models/timeline_moment.dart` (if has description)
6. `lib/models/moment_detail.dart` (if has description)
7. `lib/services/moment_save_service.dart`
8. `lib/services/offline_queue_service.dart`
9. `lib/screens/capture/capture_screen.dart`
10. All test files
11. Analytics event calls (search codebase)

## Risk Assessment

**Risk Level**: Medium-High
- Large refactor touching many files
- Risk of missing some references
- Queue migration needs careful testing
- Requires thorough testing before shipping

**Mitigation**:
- Use IDE refactoring tools (find/replace with care)
- Run all tests after each major change
- Test queue migration thoroughly
- Manual QA of full capture flow

## Testing Strategy

1. **Unit Tests**: Update all existing tests
2. **Integration Tests**: 
   - Test capture → queue → sync flow
   - Test dictation → save flow
   - Test manual edit → save flow
3. **Migration Tests**:
   - Test deserializing old queue format
   - Test converting old format to new
4. **Manual QA**:
   - Full capture flow for all memory types
   - Offline queue and sync
   - Edit existing memories

## Success Criteria

- [ ] `CaptureState` has only `inputText` field (no `rawTranscript` or `description`)
- [ ] Dictation populates `inputText` directly
- [ ] Manual edits update `inputText` directly
- [ ] Queue models use `inputText` consistently
- [ ] Save service reads/writes `inputText`
- [ ] Database mapping works (`inputText` → `text_description`)
- [ ] Old queued items migrate correctly
- [ ] All tests pass
- [ ] No regressions in existing functionality

## Rollback Plan

If issues arise:
1. Revert commits for Phase 2
2. Keep Phase 1 changes (transcript→description fix)
3. Phase 2 can be retried after fixing issues

## Notes

- This is the largest refactor in the plan
- Consider doing this in smaller sub-phases if needed:
  - Sub-phase 2a: Update CaptureState only
  - Sub-phase 2b: Update providers/services
  - Sub-phase 2c: Update queue models and migration
- Database column rename can happen later (separate migration)


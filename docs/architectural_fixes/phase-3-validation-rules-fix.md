# Phase 3: Fix Validation Rules

## Objective

Update validation logic to match spec requirements:
- **Stories**: audio is the only required input
- **Moments & Mementos**: require at least one of {description text (now `inputText`), manually-entered title, or at least one media attachment}. Tags alone should not unlock save.

## Current Behavior

**From `capture_state.dart` (after Phase 1 temporary fix)**:
- Stories: require audio (correct)
- Mementos: require description OR media (correct)
- Moments: require description OR media (correct, but tags were removed in Phase 1)

**Original behavior (before Phase 1)**:
- Moments/Stories allowed save when *any* of transcript, description, photos, videos, or tags exist
- This meant tag-only or transcript-only saves were accepted

## Target Behavior

After Phase 2 (`inputText` is the canonical field):

- **Stories**: 
  - Require `audioPath != null && audioPath!.isNotEmpty`
  - `inputText`, media, and tags are optional

- **Moments**:
  - Require at least one of:
    - `inputText` is not empty (populated by dictation or manual entry)
    - At least one photo
    - At least one video
  - Tags alone are NOT sufficient
  - Note: Titles are auto-generated, so we don't check for manually-entered title in validation

- **Mementos**:
  - Require at least one of:
    - `inputText` is not empty
    - At least one photo
    - At least one video
  - Tags alone are NOT sufficient

## Implementation Steps

### Step 1: Update CaptureState.canSave
**File**: `lib/models/capture_state.dart`

**Current** (after Phase 1 temporary fix):
```dart
bool get canSave {
  // Stories: require audio
  if (memoryType == MemoryType.story) {
    return audioPath != null && audioPath!.isNotEmpty;
  }
  
  // Mementos: require description OR media
  if (memoryType == MemoryType.memento) {
    return (description?.trim().isNotEmpty ?? false) ||
        photoPaths.isNotEmpty ||
        videoPaths.isNotEmpty;
  }
  
  // Moments: require description OR media (tags alone not enough)
  return (description?.trim().isNotEmpty ?? false) ||
      photoPaths.isNotEmpty ||
      videoPaths.isNotEmpty;
}
```

**After** (using `inputText` from Phase 2):
```dart
bool get canSave {
  // Stories: audio is the only required input
  if (memoryType == MemoryType.story) {
    return audioPath != null && audioPath!.isNotEmpty;
  }
  
  // Mementos: require at least one of inputText, photo, or video
  if (memoryType == MemoryType.memento) {
    return (inputText?.trim().isNotEmpty ?? false) ||
        photoPaths.isNotEmpty ||
        videoPaths.isNotEmpty;
  }
  
  // Moments: require at least one of inputText, photo, or video
  // Tags alone are NOT sufficient
  return (inputText?.trim().isNotEmpty ?? false) ||
      photoPaths.isNotEmpty ||
      videoPaths.isNotEmpty;
}
```

### Step 2: Update Tests
**File**: `test/models/capture_state_test.dart` (create if doesn't exist) or `test/providers/capture_state_provider_test.dart`

**Add test cases**:

1. **Stories**:
   - ✅ Can save with audio only (no text, no media)
   - ✅ Can save with audio + text
   - ✅ Can save with audio + media
   - ❌ Cannot save without audio (even with text/media)

2. **Moments**:
   - ✅ Can save with `inputText` only
   - ✅ Can save with photo only
   - ✅ Can save with video only
   - ✅ Can save with `inputText` + media
   - ❌ Cannot save with tags only
   - ❌ Cannot save with empty state

3. **Mementos**:
   - ✅ Can save with `inputText` only
   - ✅ Can save with photo only
   - ✅ Can save with video only
   - ✅ Can save with `inputText` + media
   - ❌ Cannot save with tags only
   - ❌ Cannot save with empty state

### Step 3: Update UI Feedback
**File**: `lib/screens/capture/capture_screen.dart`

**Verify**: Save button is disabled when `!state.canSave`

**Check**: Any error messages or hints that guide users on what's required should be updated to reflect new rules.

### Step 4: Update Documentation/Comments
**Files**: 
- `lib/models/capture_state.dart`
- `lib/screens/capture/capture_screen.dart`

**Add comments** explaining validation rules:
```dart
/// Determines if the current capture state can be saved.
/// 
/// Validation rules:
/// - Stories: require audio (audioPath must be set)
/// - Moments: require at least one of {inputText, photo, video}
/// - Mementos: require at least one of {inputText, photo, video}
/// 
/// Tags alone are never sufficient to unlock save.
bool get canSave {
  // ...
}
```

## Edge Cases to Consider

1. **Whitespace-only inputText**: 
   - `inputText?.trim().isNotEmpty` handles this correctly
   - Empty string after trim = cannot save

2. **Audio file path exists but file is missing**:
   - Current check: `audioPath != null && audioPath!.isNotEmpty`
   - This only checks path exists, not file existence
   - Consider: Should we verify file exists? (Probably not in validation - let save service handle)

3. **Photo/video paths in array but files missing**:
   - Current check: `photoPaths.isNotEmpty`
   - Only checks array length, not file existence
   - Save service will handle missing files during upload

4. **Tags with empty inputText and no media**:
   - Should NOT allow save (per spec)
   - Current logic correctly rejects this

## Files to Modify

1. `lib/models/capture_state.dart` - Update `canSave` getter
2. Test files - Add comprehensive validation tests
3. `lib/screens/capture/capture_screen.dart` - Verify UI binding (may not need changes)
4. Documentation/comments - Add validation rule explanations

## Risk Assessment

**Risk Level**: Low
- Logic changes only
- No data model changes
- Easy to test
- Easy to rollback

## Testing Strategy

1. **Unit Tests**: Test `canSave` getter with all combinations
2. **Widget Tests**: Test save button enabled/disabled states
3. **Integration Tests**: Test full capture flow with various inputs
4. **Manual QA**: 
   - Try to save with tags only (should fail)
   - Try to save story without audio (should fail)
   - Try to save moment with only text (should succeed)
   - Try to save memento with only photo (should succeed)

## Success Criteria

- [ ] Stories require audio to save
- [ ] Moments require inputText OR media (tags alone insufficient)
- [ ] Mementos require inputText OR media (tags alone insufficient)
- [ ] All validation test cases pass
- [ ] UI correctly reflects validation state
- [ ] No regressions in existing functionality

## Dependencies

- **Requires**: Phase 1 (transcript→description fix) and Phase 2 (input_text alignment)
- **Can be done**: Immediately after Phase 2 completes

## Notes

- This phase is straightforward once Phase 2 is complete
- The validation logic is already mostly correct after Phase 1 temporary fix
- Main change is switching from `description` to `inputText` reference
- Consider adding helpful error messages in UI to guide users (future enhancement)


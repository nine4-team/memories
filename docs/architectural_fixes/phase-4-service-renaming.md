# Phase 4: Service Renaming (MomentSaveService → MemorySaveService)

## Objective

Rename `MomentSaveService` to `MemorySaveService` to accurately reflect that it handles all memory types (Moments, Stories, Mementos), not just Moments.

## Current State

- Service class: `MomentSaveService` in `lib/services/moment_save_service.dart`
- Provider: `momentSaveServiceProvider` (generated)
- Result class: `MomentSaveResult`
- File: `moment_save_service.g.dart` (generated)
- Used by: Capture screen, offline queue service, etc.

## Target State

- Service class: `MemorySaveService` in `lib/services/memory_save_service.dart`
- Provider: `memorySaveServiceProvider` (generated)
- Result class: `MemorySaveResult`
- File: `memory_save_service.g.dart` (generated)
- All references updated throughout codebase

## Implementation Steps

### Step 1: Rename Service Class and File
**Action**: Rename file and update class name

**File**: `lib/services/moment_save_service.dart` → `lib/services/memory_save_service.dart`

**Changes**:
1. Rename class `MomentSaveService` → `MemorySaveService`
2. Rename class `MomentSaveResult` → `MemorySaveResult`
3. Update `part"../phases"` directive: `part '../phases/memory_save_service.g.dart';`
4. Update provider function name: `momentSaveService` → `memorySaveService`
5. Update provider annotation: `@riverpod MemorySaveService memorySaveService(...)`

### Step 2: Update Method Names/Comments
**File**: `lib/services/memory_save_service.dart`

**Changes**:
1. Update method name: `saveMoment()` → `saveMemory()` (or keep as `saveMoment` for backward compatibility? Check usage)
2. Update method documentation to reference "memory" instead of "moment"
3. Update comments throughout file

**Decision**: Check if `saveMoment()` is called from many places. If so, consider:
- Option A: Rename to `saveMemory()` and update all call sites
- Option B: Keep `saveMoment()` as alias, add `saveMemory()` that calls it (deprecated approach)
- **Recommendation**: Option A - clean rename, update all call sites

### Step 3: Regenerate Generated File
**Action**: Run code generation

**Command**: `dart run build_runner build --delete-conflicting-outputs`

**Result**: New file `memory_save_service.g.dart` with `memorySaveServiceProvider`

### Step 4: Update All Usages
**Files to search and update**:

1. **Capture Screen**:
   - `lib/screens/capture/capture_screen.dart`
   - Update provider reference: `momentSaveServiceProvider` → `memorySaveServiceProvider`
   - Update service variable names if any

2. **Offline Queue Service**:
   - `lib/services/offline_queue_service.dart`
   - Update provider reference
   - Update method calls if method was renamed

3. **Story Queue Service** (if exists):
   - Search for `momentSaveServiceProvider` references
   - Update to `memorySaveServiceProvider`

4. **Any other services**:
   - Search codebase for `momentSaveServiceProvider`
   - Update all references

### Step 5: Update Tests
**Files**:
- `test/services/moment_save_service_test.dart` → `test/services/memory_save_service_test.dart`

**Changes**:
1. Rename test file
2. Update imports
3. Update provider references in tests
4. Update class name references in test descriptions
5. Update any mock/service variable names

### Step 6: Update Documentation/Comments
**Files**: Any documentation that references the service

**Changes**:
- Update references from "MomentSaveService" to "MemorySaveService"
- Update any architecture diagrams or docs

## Files to Modify

1. `lib/services/moment_save_service.dart` → `lib/services/memory_save_service.dart` (rename + update)
2. `lib/screens/capture/capture_screen.dart`
3. `lib/services/offline_queue_service.dart`
4. `test/services/moment_save_service_test.dart` → `test/services/memory_save_service_test.dart`
5. Any other files referencing `momentSaveServiceProvider` (search codebase)

## Search Patterns

Use these patterns to find all references:

```bash
# Find provider references
grep -r "momentSaveServiceProvider" lib/ test/

# Find class references
grep -r "MomentSaveService" lib/ test/

# Find result class references
grep -r "MomentSaveResult" lib/ test/

# Find file imports
grep -r "moment_save_service" lib/ test/
```

## Risk Assessment

**Risk Level**: Low
- Mostly find/replace operation
- No logic changes
- Easy to verify with tests
- Easy to rollback

**Potential Issues**:
- Missing a reference somewhere (mitigated by thorough search)
- Generated file conflicts (handled by build_runner --delete-conflicting-outputs)

## Testing Strategy

1. **Compile Check**: Ensure code compiles after rename
2. **Unit Tests**: Run all service tests
3. **Integration Tests**: Test capture → save flow for all memory types
4. **Manual QA**: 
   - Save a Moment
   - Save a Story
   - Save a Memento
   - Verify all work correctly

## Success Criteria

- [ ] Service class renamed to `MemorySaveService`
- [ ] File renamed to `memory_save_service.dart`
- [ ] Provider renamed to `memorySaveServiceProvider`
- [ ] Generated file updated
- [ ] All references updated throughout codebase
- [ ] All tests pass
- [ ] No regressions in save functionality

## Dependencies

- **Independent**: Can be done at any time, doesn't depend on other phases
- **Recommended**: Do after Phase 2 to avoid conflicts with larger refactor

## Rollback Plan

If issues arise:
1. Revert file rename
2. Revert class name changes
3. Regenerate old file
4. Revert all reference updates

## Notes

- This is a straightforward rename operation
- Consider using IDE refactoring tools for safety
- Double-check generated file is updated correctly
- Verify no hardcoded strings reference old name (e.g., in error messages)


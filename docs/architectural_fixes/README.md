# Memory Implementation Fix Phases

This directory contains detailed planning documents for fixing the memory implementation issues identified in `../memory-implementation-issues.md`.

## Overview

See the master plan: [`../memory-implementation-fix-plan.md`](../memory-implementation-fix-plan.md)

## Phase Documents

1. **[Phase 1: Transcript → Description Fix](./phase-1-transcript-to-description-fix.md)**
   - **Priority**: CRITICAL
   - **Risk**: Low
   - Fixes bug where dictation text doesn't populate description field
   - Should be done first

2. **[Phase 2: input_text Alignment](./phase-2-input-text-alignment.md)**
   - **Priority**: High
   - **Risk**: Medium-High
   - Large refactor unifying `description`/`rawTranscript` into `inputText`
   - Depends on Phase 1

3. **[Phase 3: Validation Rules Fix](./phase-3-validation-rules-fix.md)**
   - **Priority**: High
   - **Risk**: Low
   - Updates validation to match spec requirements
   - Depends on Phases 1 & 2

4. **[Phase 4: Service Renaming](./phase-4-service-renaming.md)**
   - **Priority**: Medium
   - **Risk**: Low
   - Renames `MomentSaveService` → `MemorySaveService`
   - Independent, can be done anytime

5. **[Phase 5: Data Model Rename](./phase-5-data-model-changes.md)** ⚠️ SUPERSEDED
   - **Status**: Consolidated into Phase 6
   - **See**: [Phase 5 Incomplete Status](./phase-5-incomplete-status.md) for details
   - Original plan to rename `moments` → `memories` and `capture_type` → `memory_capture_type`

6. **[Phase 6: Text Model Normalization](./phase-6-text-model-normalization.md)** ✅ COMPLETED
   - **Priority**: High
   - **Risk**: Medium (DB migration)
   - Normalizes text model: `text_description` → `input_text`, adds `processed_text`
   - Renames enum: `capture_type`/`memory_capture_type` → `memory_type_enum`
   - Renames column: `capture_type` → `memory_type`
   - Consolidates Phase 5 work (table/enum renames)
   - **Status**: Implementation complete, migrations ready to apply

## Execution Order

```
Phase 1 (Critical Bug Fix)
    ↓
Phase 2 (Foundation Refactor)
    ↓
Phase 3 (Validation Fix)
    ↓
Phase 4 (Service Rename) ──┐
    ↓                      │ (Independent)
Phase 6 (DB Normalization) ┘ (Consolidates Phase 5)
```

**Note**: Phase 5 was superseded by Phase 6, which consolidates the table/enum renames along with text normalization.

## Quick Reference

| Phase | Files Changed | Risk | Dependencies | Status |
|-------|--------------|------|--------------|--------|
| 1 | 2-4 files | Low | None | ✅ |
| 2 | 10+ files | Medium-High | Phase 1 | ✅ |
| 3 | 2-3 files | Low | Phases 1 & 2 | ✅ |
| 4 | 5-6 files | Low | None | ✅ |
| 5 | 8+ spec files + DB migration | Medium | None | ⚠️ Superseded |
| 6 | Models + Services + 4 DB migrations | Medium | None | ✅ Complete |

## Getting Started

1. Read [`../memory-implementation-issues.md`](../memory-implementation-issues.md) to understand the problems
2. Read [`../memory-implementation-fix-plan.md`](../memory-implementation-fix-plan.md) for the overall strategy
3. Start with Phase 1 and work through phases sequentially
4. Each phase document includes:
   - Detailed implementation steps
   - Files to modify
   - Testing strategy
   - Success criteria
   - Risk assessment

## Questions?

If you encounter issues or need clarification:
1. Review the phase document for that specific phase
2. Check the master plan for overall context
3. Review the original issues document for problem statements


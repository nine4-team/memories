# Phase 6 Spec Alignment Analysis

## Summary

After implementing Phase 6 database migrations (text model normalization), we've identified **significant misalignments** between the specs and the actual database schema. The specs were written before Phase 6 and still reference old column names and terminology.

## Root Cause Assessment

**The issue was BOTH spec and implementation misalignment:**

1. **Specs were written with incorrect assumptions** about the database schema (using `capture_type`, `text_description`)
2. **Implementation followed the specs**, which led to incorrect database column references
3. **Phase 6 migrations corrected the database** but specs were never updated

## Key Changes Required

### Column Name Changes

| Old (in Specs) | New (Phase 6) | Impact |
|----------------|--------------|--------|
| `capture_type` | `memory_type` | All filtering, queries, API contracts |
| `memory_capture_type` enum | `memory_type_enum` | Enum type references |
| `text_description` | `input_text` | Raw user text field |
| N/A | `processed_text` | NEW: LLM-processed text (missing from most specs) |

### Semantic Changes

1. **Text Model Normalization:**
   - `input_text`: Raw user text from capture UI (replaces `text_description`)
   - `processed_text`: LLM-processed version (NEW - for stories this is narrative, for moments this is cleaned description)
   - Display logic: prefer `processed_text`, fallback to `input_text`

2. **Type Naming:**
   - All references to "capture type" should be "memory type"
   - Enum type uses `_enum` suffix pattern (`memory_type_enum`)

## Specs Requiring Updates

### Critical (API Contracts)
1. ✅ `agent-os/specs/2025-11-16-story-list-detail-views/implementation/api-contract.md`
   - Uses `capture_type`, `text_description`
   - Missing `processed_text` field

2. ✅ `agent-os/specs/2025-11-16-moment-detail-view/implementation/api-contract.md`
   - Uses `capture_type`, `text_description`
   - Missing `processed_text` field

3. ✅ `agent-os/specs/2025-11-16-moment-list-timeline-view/implementation/api-contract.md`
   - Uses `capture_type`, `text_description`
   - Missing `processed_text` field

### Main Specs
4. ✅ `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`
   - Uses `capture_type`, `memory_capture_type` enum
   - References `text_description` (should be `input_text`)

5. ✅ `agent-os/specs/2025-11-16-story-list-detail-views/spec.md`
   - Uses `memory_type` in some places (correct) but `capture_type` in others
   - Missing `processed_text` semantics

6. ✅ `agent-os/specs/2025-11-16-moment-detail-view/spec.md`
   - References "rich text body" but doesn't specify `input_text` vs `processed_text`

7. ✅ `agent-os/specs/2025-11-16-moment-list-timeline-view/spec.md`
   - Uses `capture_type` terminology
   - Missing `processed_text` in search description

8. ✅ `agent-os/specs/2025-11-16-unified-timeline-feed/spec.md`
   - Uses `capture_type` and `memory_capture_type` enum
   - Missing `processed_text` field

9. ✅ `agent-os/specs/2025-11-16-memento-creation-display/spec.md`
   - Uses `capture_type`, `memory_capture_type` enum
   - Uses `text_description` (should be `input_text`)

10. ✅ `agent-os/specs/2025-11-17-search-functionality-full-text/spec.md`
    - Uses `capture_type` terminology
    - References `text_description` in search indexing

### Implementation Docs
11. ✅ `agent-os/specs/2025-11-16-story-list-detail-views/implementation/story-detail-audit.md`
    - Uses `capture_type`, `text_description`
    - Missing `processed_text` field

12. ✅ `agent-os/specs/2025-11-16-voice-story-recording-processing/implementation/storage-bucket-structure.md`
    - Uses `capture_type` in path structure

13. ✅ Various task files and implementation summaries
    - Multiple references to old column names

## Impact Assessment

### High Impact
- **API Contracts**: These directly affect implementation. Wrong field names will cause runtime errors.
- **Main Specs**: These guide feature development. Incorrect assumptions lead to wrong implementations.

### Medium Impact
- **Implementation docs**: These document current state but may confuse future developers.
- **Task files**: Historical but may be referenced for context.

## Recommended Update Strategy

1. **Update API contracts first** (highest priority - affects current implementation)
2. **Update main specs** (guides future work)
3. **Update implementation docs** (for accuracy)
4. **Add notes to task files** (historical context preserved)

## Display Text Logic (Critical)

All specs should document the display text fallback logic:

```dart
String? get displayText {
  if (processedText != null && processedText!.trim().isNotEmpty) {
    return processedText!.trim();
  }
  if (inputText != null && inputText!.trim().isNotEmpty) {
    return inputText!.trim();
  }
  return null;
}
```

This ensures:
- Stories show processed narrative when available
- Moments show cleaned description when available
- Fallback to raw input text if processing hasn't completed
- Consistent behavior across all memory types

## Next Steps

1. ✅ Create this analysis document
2. ✅ Update all API contracts with correct field names
3. ✅ Update all main specs with correct terminology
4. ✅ Add `processed_text` semantics where missing
5. ✅ Document display text fallback logic in relevant specs

## Update Summary

### API Contracts Updated ✅
- `agent-os/specs/2025-11-16-story-list-detail-views/implementation/api-contract.md`
- `agent-os/specs/2025-11-16-moment-detail-view/implementation/api-contract.md`
- `agent-os/specs/2025-11-16-moment-list-timeline-view/implementation/api-contract.md`

### Main Specs Updated ✅
- `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`
- `agent-os/specs/2025-11-16-story-list-detail-views/spec.md`
- `agent-os/specs/2025-11-16-moment-detail-view/spec.md`
- `agent-os/specs/2025-11-16-moment-list-timeline-view/spec.md` (minor search text update may be needed)
- `agent-os/specs/2025-11-16-unified-timeline-feed/spec.md`
- `agent-os/specs/2025-11-16-memento-creation-display/spec.md`
- `agent-os/specs/2025-11-17-search-functionality-full-text/spec.md`

### Key Changes Applied
1. **Column Names**: `capture_type` → `memory_type`, `text_description` → `input_text`, added `processed_text`
2. **Enum Names**: `memory_capture_type` → `memory_type_enum`
3. **Display Logic**: Documented fallback from `processed_text` to `input_text`
4. **Search**: Updated to reference `processed_text` and `input_text` instead of generic "descriptions"

### Remaining Work (Low Priority)
- Some implementation docs and task files may still reference old terminology (historical context preserved)
- Consider updating `agent-os/specs/2025-11-16-moment-list-timeline-view/spec.md` line 34 if search text needs clarification


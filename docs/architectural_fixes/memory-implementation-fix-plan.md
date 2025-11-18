# Memory Implementation Plan (Issues + Fix Strategy)

One document to track every outstanding gap and exactly how we plan to close it.

---

## Current Gaps vs Spec

### 1. Capture Validation Rule Clarification
- **Intended rule**
  - **Stories:** audio is the only required input (dictation/recording provides everything else).
  - **Moments & Mementos:** require at least one of {description text (auto-populated by dictation), manually-entered title, or ≥1 media attachment}. Tags alone should never unlock Save.
- **Current behavior:** `CaptureState.canSave` enforces “description or media” only for Mementos. Moments/Stories still allow save when *any* of transcript, description, photos, videos, or tags exist, so tag-only or transcript-only saves are accepted.
- **Fix summary:** After transcript → description wiring is fixed, validation must be updated so Moments/Mementos check the canonical text field or media, and Stories check audio presence only.

### 1a. Transcript Must Populate Description (Bug)
- Dictation currently writes into `rawTranscript`, leaving `description` empty unless the user copies text manually—violating the “single text field” promise and breaking the Memento validation rule.
- **Action:** When dictation emits text, set the canonical text field immediately (and display it in the editable input). Keep `rawTranscript` temporarily only for backward compatibility until the `inputText` refactor lands.

### 1b. `input_text` Alignment Plan
Goal: replace the `description`/`rawTranscript` split with a single `inputText` field everywhere (capture state, queue models, Supabase payloads, analytics).
1. **Frontend state/UI:** Rename `description` → `inputText` in `CaptureState`, providers, controllers, serialization.
2. **Queue & DTO models:** Update `QueuedMoment`, `QueuedStory`, `TimelineMoment`, detail models, etc., to read/write the unified field (mapped to `text_description` in the DB until the column is renamed).
3. **Services/APIs:** Adjust save services, RPC payloads, analytics events to consume/emit `inputText`.
4. **Tests/fixtures:** Update all mocks/fixtures/assertions to use the canonical field.
5. **Future:** When ready, rename the Supabase column to `input_text` with a migration + regenerated types.

### 2. Shared Save Service Naming
- The spec talks about saving “memories” generically; the implementation already uses one service (`MomentSaveService`) for all capture types via `capture_type`.
- **Gap:** Names imply Moments-only responsibility, confusing readers/spec alignment.
- **Action:** Rename the service/provider/generated code to `MemorySaveService` to match reality (no behavior change).

### 3. Data Model: Table Naming Doesn’t Match Scope
- Specs expected a dedicated `mementos` table, but all memory types are stored in `public.moments` with a `capture_type` enum.
- **Gap:** Behavior already matches a unified “memories” table, but the name is wrong and causes confusion.
- **Decision:** Keep the unified design but rename `moments` → `memories` (including enums, types, docs) so terminology and intent align. Requires DB migration, regenerated clients, and spec updates.

---

## Phased Execution Plan

| Phase | Focus | Priority/Risk | Dependencies |
|-------|-------|---------------|--------------|
| 1 | Transcript → description bug fix | Critical / Low | None |
| 2 | `inputText` refactor | High / Medium-High | Phase 1 |
| 3 | Validation rules realignment | High / Low | Phases 1–2 |
| 4 | Service rename (`MemorySaveService`) | Medium / Low | None |
| 5 | DB rename to `memories` + spec updates | Medium / Medium | None (but coordinate with backend release) |

Work sequentially through Phases 1–3 (they build on each other), then schedule 4 and 5 when convenient.

---

## Phase Details

### Phase 1 — Transcript → Description Bug (Critical)
**Objective:** Ensure dictation text automatically populates the editable text field so the UX and validation rules behave as designed.

**Implementation Highlights**
- Update `capture_state_provider.dart`
  - `_transcriptSubscription`: set both `rawTranscript` and `description`.
  - `stopDictation()`: on final result, copy transcript into `description` when non-empty.
- Confirm `capture_screen.dart` description TextField binds to `state.description` and reflects updates.
- Temporary validation tweak: Stories require audio; Moments/Mementos require description or media (tags no longer unlock save).

**Files / Systems**
- `lib/providers/capture_state_provider.dart`
- `lib/models/capture_state.dart`
- `lib/screens/capture/capture_screen.dart`
- Associated provider/widget tests

**Testing / QA**
- Unit: provider updates, `canSave` logic.
- Manual: start dictation, confirm text appears instantly; ensure edits persist; verify save buttons enablement for each memory type.

**Risk:** Low (isolated to capture state). Unlocks later phases.

---

### Phase 2 — `inputText` Alignment Refactor
**Objective:** Collapse `description` + `rawTranscript` into a single canonical `inputText` across app state, queues, services, analytics, and serialization.

**Implementation Highlights**
1. **CaptureState & Provider**
   - Replace fields with `inputText`.
   - Update copyWith, persistence, selectors, and dictation handlers.
2. **Models & Queues**
   - `QueuedMoment`, `QueuedStory`, timeline/detail models: rename fields, bump versions, handle migration of existing serialized data (fallback to `description`/`rawTranscript` if `inputText` missing).
3. **Services / APIs**
   - `moment_save_service.dart` (soon `memory_save_service`): send `inputText` under `text_description`, update title generation to use it, drop references to `rawTranscript`.
   - Offline queue service serialization/deserialization.
   - Analytics events / RPC payloads referencing description/transcript.
4. **UI**
   - Capture screen controllers call `updateInputText`.
   - Ensure any bindings/listeners use the new field.
5. **Edge Functions / Backend contracts**
   - Verify title-generation edge function parameters (update if they expect `raw_transcript`).

**Tests / QA**
- Update all affected tests (providers, services, offline queue, widgets).
- Add migration tests for legacy queued items.
- Manual regression of capture → queue → sync for each memory type, both online/offline.

**Risk:** Medium-High (touches many files). Use incremental commits + comprehensive testing.

---

### Phase 3 — Validation Rules Realignment
**Objective:** Once `inputText` exists, make validation match the spec precisely.

**Implementation Highlights**
- `CaptureState.canSave`:
  - Stories: `audioPath` must be present.
  - Moments/Mementos: require `(inputText?.trim().isNotEmpty) || photoPaths.isNotEmpty || videoPaths.isNotEmpty`.
  - Tags never unlock save alone.
- Update capture screen button enabling/error hints if needed.
- Expand tests to cover every combination (audio only, text only, media only, tags only, empty).

**Files**
- `lib/models/capture_state.dart`
- Tests (`test/models/capture_state_test.dart`, provider/widget tests)
- UI copy if hints/tooltips mention requirements

**Risk:** Low. Ships alongside/after Phase 2 to avoid double work.

---

### Phase 4 — Service Rename (`MemorySaveService`)
**Objective:** Rename the shared save service/provider to reflect that it handles all memory types.

**Implementation Highlights**
- Rename file/class/result/provider: `moment_save_service` → `memory_save_service`.
- Decide whether to rename `saveMoment()` to `saveMemory()` (preferred) and update all call sites (capture screen, offline queue, tests, etc.).
- Regenerate `memory_save_service.g.dart` via `dart run build_runner build --delete-conflicting-outputs`.
- Update documentation/comments referencing the old name.

**Risk:** Low (find/replace + regenerated code). Can run anytime after Phase 2 to avoid churn.

---

### Phase 5 — Database Rename to `memories` + Spec Updates
**Objective:** Align terminology by renaming the Supabase `moments` table + enum to `memories`, then update every spec/docs reference to the unified storage strategy.

**Implementation Highlights**
1. **Migration**
   - Rename enum `capture_type` → `memory_capture_type`.
   - Rename table `public.moments` → `public.memories`.
   - Rename indexes/policies/comments accordingly.
   - Provide rollback SQL.
2. **Code / Generated Types**
   - Regenerate Supabase client/types (TS + Dart) so references point to `memories`.
   - Update queries/services to hit the new table name and enum strings.
3. **Specs & Docs**
   - Update “Data & Storage” sections in:
     - `agent-os/specs/2025-11-16-memento-creation-display/spec.md`
     - `agent-os/specs/2025-11-16-memento-creation-display/planning/requirements.md`
     - `agent-os/specs/2025-11-16-memento-creation-display/tasks.md`
     - `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`
     - `agent-os/specs/2025-11-16-moment-creation-text-media/planning/requirements.md`
     - `agent-os/specs/2025-11-16-story-list-detail-views/spec.md`
     - `agent-os/specs/2025-11-16-unified-timeline-feed/spec.md`
   - Document the rename rationale in `docs/data-model-decision.md` (or inline here once complete).
4. **QA**
   - Apply migration to staging/dev, run regression tests, verify all queries succeed, monitor logs for lingering `moments` references.

**Risk:** Medium (DB migration). Coordinate with backend release windows.

---

## Global Testing & Rollout Checklist

1. **Automated tests**: Run the full Flutter/Dart test suite after each phase.
2. **Manual capture QA**: For every release, cover:
   - Story with audio-only
   - Moment with dictation-only
   - Memento with photo-only
   - Offline capture → queue → sync
3. **Analytics sanity**: Confirm events still emit expected payloads after field/table renames.
4. **Supabase verification**: Inspect rows to ensure `inputText` persists correctly and `capture_type` filters still work post-rename.

---

## Success Criteria (Definition of Done)
- Dictation text instantly populates the editable field (and persists) for all memory types.
- The app, services, analytics, and Supabase share a single `inputText` concept.
- Validation rules enforce the intended requirements (audio for stories, text/media for others).
- Save service naming matches its real scope (`MemorySaveService`).
- Database/schema/docs consistently refer to the unified `memories` table.
- Specs/tasks are updated so future work references accurate architecture.
- All automated tests pass and manual capture scenarios regress cleanly.


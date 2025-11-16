# Tasks: Moment Creation (Text + Media)

## Phase 1 – Architecture & Data Preparation
1. **Schema updates for capture metadata**
   - Extend `moments` table with `raw_transcript`, `generated_title`, `title_generated_at`, `tags text[]`, `captured_location`, `location_status`, `capture_type`.
   - Add necessary enums and indexes (e.g., tags GIN, capture_type enum).
2. **Supabase Edge Function for title generation**
   - Define API contract (inputs: transcript, memory type; outputs: title, status).
   - Implement LLM call, truncation, fallback logic, and logging.
3. **Storage cleanup automation**
   - Ensure orphaned media cleanup hook/process is defined (can reuse existing scripts if any).

## Phase 2 – Flutter Capture Experience
4. **Unified capture sheet UI**
   - Build full-screen Riverpod-managed widget with mic control, media tray, tagging chips, and Save/Cancel actions.
   - Implement memory-type toggles (Moment default) and ensure state persists when switching.
5. **Dictation plugin integration**
   - Wire up in-house dictation plugin lifecycle (start/stop, transcript stream, error handling).
   - Persist raw transcript in state and prep payload for backend.
6. **Media attachment module**
   - Integrate camera plugin + image_picker with caps (10 photos, 3 videos) and preview/removal controls.
   - Surface limit helper text and disable add buttons when caps reached.
7. **Tagging input component**
   - Build subtle freeform chip input (case-insensitive, trimmed) with keyboard-friendly UX.
   - Store tags in state for payload.

## Phase 3 – Metadata & Save Flow
8. **Passive metadata capture**
   - Hook into geolocation APIs with permission prompts; record coordinates or denial status.
   - Track capture timestamps: start and save moments.
9. **Save pipeline & Supabase integration**
   - Validate presence of transcript, media, or tags before enabling Save.
   - On Save: upload media to Supabase Storage, call Supabase RPC to create Moment with metadata, enqueue title generation.
   - Show progress indicator + retry flows.
10. **Title generation + edit UX**
    - After backend responds with generated title, present inline edit affordance before navigating away.
    - Store `title_generated_at` timestamp and raw transcript locally for future regen.

## Phase 3b – Offline Capture & Sync
11. **Offline queue data layer**
    - Add persistent queue model storing transcript, metadata, media URIs, and deterministic local IDs.
    - Ensure Save writes to the queue immediately when offline (or when uploads fail) and marks status for UI.
12. **Sync engine & status UX**
    - Build background/foreground sync worker that retries uploads with exponential backoff and telemetry.
    - Surface queued/syncing/error states in the capture confirmation UI plus manual “Sync now” action.

## Phase 4 – Post-Save and QA
13. **Navigation & confirmation states**
    - Route to Moment detail screen on success; display toast summarizing uploads and metadata capture status.
    - Handle cancellation/discard prompts.
14. **Accessibility & localization review**
    - Verify toggles, tags, and thumbnails meet accessibility and localization standards.
15. **Testing & instrumentation**
    - Add Riverpod unit/widget tests for capture view, dictation handler, media limits, save pipeline, and offline queue/sync flows.
    - Instrument analytics/logging for dictation start/stop, media additions, errors, save outcomes, and queue flush results.

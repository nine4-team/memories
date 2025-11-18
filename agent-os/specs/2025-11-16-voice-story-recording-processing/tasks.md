# Tasks: Voice Story Recording & Processing

## Phase 1 – Data & Platform Foundations
- [x] 1. **Stories schema + storage conventions**
   - [x] Add columns for `status`, `raw_transcript`, `narrative_text`, `title`, `title_generated_at`, `audio_path`, processing timestamps, and any retry counters.
   - [x] Define Supabase Storage bucket/folder structure for story audio (`stories/audio/{userId}/{storyId}/{timestamp}.m4a`) and ensure RLS-secured signed URL access.
   - [x] Write migrations + seed data updates, including indexes on `status` and processing timestamps.
- [x] 2. **Queue + metadata model definitions**
   - [x] Specify local persistence models (Hive/SQLite) for queued stories capturing transcript, audio file URI, media attachments, retry counts, and memory type.
   - [x] Outline serialization/versioning strategy so queued payloads survive app upgrades.

## Phase 2 – Dictation Plugin Integration
- [x] 3. **Adopt latest plugin build**
   - [x] Integrate NativeDictationService from flutter_dictation plugin that surfaces raw-audio references while keeping streaming transcripts/event channels unchanged.
   - [x] Wire Riverpod services to subscribe to status/result/audio-level streams, reset waveform state, and surface permission errors per README guidance.
   - [x] Implement elapsed timer tracking (updates every second, displayed as M:SS format).
   - [x] Track locale separately from platform locale (plugin doesn't provide it).
   - [x] Refactor UI to match plugin pattern: cancel (X) left, waveform middle, timer + confirm (checkmark) right.
   - [x] Gate the new behavior behind a feature flag so QA can compare legacy vs. new plugin output before broad rollout.
- [x] 4. **Audio persistence hooks**
   - [x] When `stopListening` resolves, grab the plugin-provided audio file reference + metadata and store it in local cache/queue with durability guarantees.
   - [x] Ensure cleanup of temporary files on cancel/discard flows and reuse audio when retries occur (no duplicate recordings).
   - [x] Add unit/widget tests covering plugin adapter, error propagation, and lifecycle teardown.

## Phase 3 – Unified Capture Experience Updates
- [x] 5. **Story selection + attachments on capture sheet**
   - [x] Keep shared transcript field/mic UI; ensure switching to Story toggles downstream routing without clearing text/media.
   - [x] Allow attaching photos/videos before submission; reuse Moments limits (10 photos / 3 videos) with consistent UX states.
- [x] 6. **Offline queue writing**
   - [x] On Save (Story selected), persist transcript, audio URI, attachments, and metadata into the queue whenever uploads cannot proceed.
   - [x] Surface queued/syncing badges in confirmation UI and block duplicate submissions via deterministic local IDs.

## Phase 4 – Sync & Submission Pipeline
7. **Background sync engine**
   - Implement worker that prioritizes transcript upload, then audio, then attachments once connectivity returns.
   - Handle resumable uploads, exponential backoff, telemetry, and manual “Sync now” action hooks.
8. **Immediate Story creation API**
   - Create Supabase RPC/service that accepts transcript + initial metadata, creates a `stories` row with `status=processing`, and links placeholder attachment records.
   - Ensure API idempotency for replays from the queue.

## Phase 5 – Narrative Processing Backend
9. **Edge Function for story processing**
   - Watch for new `stories` rows, fetch transcript/audio, validate uploads, and run LLM narrative+title generation.
   - Store outputs, timestamps, and telemetry; mark story `status=complete` or `status=failed` with error context.
   - Provide admin/CLI hook to reprocess using stored audio.
10. **Notification + retry triggers**
    - Emit push notifications (deep-link to story detail) when processing succeeds; send in-app toast if foregrounded.
    - On failure, keep raw audio reference and expose retry endpoint the client can call.

## Phase 6 – Story Detail & Editing UX
11. **Processing state UI**
    - Display placeholder title/body (“Processing your story…”) while still showing transcript and attachments.
    - Keep screen interactive: allow adding/removing media, navigating elsewhere, and viewing status chips.
12. **Post-processing editing & reprocess controls**
    - Enable inline edits to generated title/body with optimistic updates and `updated_at` tracking.
    - Add overflow action to trigger reprocessing using stored audio; handle confirmation + feedback.

## Phase 7 – QA, Accessibility, and Instrumentation
13. **Testing coverage**
    - Write unit/widget tests for plugin adapters, offline queue, sync ordering, story detail states, and failure retries.
    - Add backend tests for Edge Function happy-path, delayed audio arrival, and failure scenarios.
14. **Telemetry, accessibility, localization**
    - Instrument analytics for dictation start/stop, queue status, processing durations, and retries.
    - Verify mic controls, waveform, and status chips meet accessibility guidelines; externalize user-facing strings for localization.

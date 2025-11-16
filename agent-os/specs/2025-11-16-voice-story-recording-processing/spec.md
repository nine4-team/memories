# Specification: Voice Story Recording & Processing

## Goal
Deliver a unified, voice-first capture experience that stores both transcript and raw audio for Story memories, then processes them into narrative titles and bodies without blocking the user.

## User Stories
- As a busy storyteller, I want to tap the mic on the unified capture sheet and keep typing or attaching media so I can record a Story in seconds without switching screens.
- As an offline traveler, I want my dictated Story (audio, transcript, and attachments) to queue locally and sync automatically later so nothing is lost when I regain service.
- As a memory keeper, I want to be notified when the polished narrative is ready and jump straight to the Story detail so I can review and edit it immediately.

## Specific Requirements

**Unified Capture Entry Point**
- Reuse the single capture canvas (text field, mic button, type selector) shared with Moments/Mementos; Story is just one selection in the toggle.
- Dictation dumps text into the shared input; selecting Story simply changes downstream routing while preserving existing content and attachments.
- Keep waveform UI with left cancel (X) and right confirm (check) controls per plugin guidelines.
- Allow media attachments (photos/videos) prior to submission without leaving this screen.

**Dictation Plugin Enhancements** 
(NOT DONE BY US - DONE BY PLUGIN TEAM OUTSIDE OF THIS PROJ)
- Extend the in-house plugin to emit both streaming transcription and a reference to the raw audio buffer once recording stops.
- Persist audio locally (PCM/WAV or compressed) with metadata (duration, locale, timestamp) so it can be uploaded or retried later.
- Ensure plugin lifecycle still supports <100 ms start latency, waveform streaming, and permission handling on iOS.
- Provide hooks so Riverpod state can read recording status, elapsed timer, and any plugin errors for UI messaging.

**Offline Capture & Queueing**
- When offline, store transcript text, audio file path, attachments, and selected memory type inside a durable queue (SQLite/Hive) with retry counts.
- On connectivity restoration, automatically upload transcript payload first, then enqueue audio upload, followed by attachments.
- Preserve ordering guarantees so backend processing can start as soon as transcript lands even if audio is still syncing.
- Surface queued/syncing states in the capture confirmation UI so users know their Story is safe.

**Story Submission & Storage**
- Upon user tapping Save with Story selected, create a `stories` row immediately (status = `processing`) even if media uploads are pending.
- Store Supabase Storage paths for audio under `stories/audio/{userId}/{storyId}/{timestamp}.m4a` once upload succeeds.
- Persist initial transcript text, capture timestamp, attachment metadata, and references to any related Moments/Mementos if linked later.
- Enforce RLS so users only access their own audio/transcripts.

**Narrative Processing Pipeline**
- Supabase Edge Function listens for new Story submissions, fetches transcript + audio, and runs transcription validation plus LLM narrative shaping.
- LLM prompt outputs both cleaned paragraphs and a concise title (<60 chars) that reflects brand voice; record `title_generated_at` and `narrative_generated_at`.
- If audio upload is delayed, the function should recheck until both transcript + audio exist, then proceed.
- Write processing telemetry (duration, model used, errors) for observability.

**Media Attachments & Uploads**
- Allow attaching photos/videos before submission; reuse Moment media limits unless Story-specific caps are defined (default to 10 photos / 3 videos).
- Upload attachments to Supabase Storage with resumable transfers; maintain associations to the Story entry via arrays.
- When offline, store media URIs and attempt background uploads once online, updating Story record as each succeeds.
- Keep the Story detail editable so users can continue attaching/removing media while narrative generation runs.

**Story Detail States & Editing**
- Story detail screen shows placeholder title/body (“Processing your story…”) until narrative arrives, but still displays transcript text and attachments.
- Once processing finishes, replace placeholder with generated content and allow inline editing of both title and body without reprocessing audio.
- Maintain edit history or `updated_at` timestamps so later edits are tracked.
- Provide affordances to attach additional media or related memories even post-processing.

**Notifications & Failure Recovery**
- Emit push notifications with deep links when processing completes; show in-app toast if user is active.
- On processing failure, surface an actionable banner with retry button that reuses stored audio + transcript.
- Keep raw audio accessible for manual reprocessing requests initiated from the Story detail overflow menu.
- Log failures (upload issues, transcription errors, LLM failures) with user-friendly copy and telemetry for debugging.

## Visual Design
No visual assets were provided; follow existing unified capture styling and plugin waveform layout.

## Existing Code to Leverage

**Flutter Dictation Plugin (`/Users/benjaminmackenzie/Dev/flutter_dictation/README.md`)**
- Provides the NativeDictationService, waveform widgets, and control patterns (mic, cancel, confirm) required for the capture UI.
- Documents event channel payloads (`status`, `result`, `audioLevel`) that should drive the capture state machine.
- Includes guidance on low-latency audio engine setup, permission prompts, and waveform smoothing to reuse.
- Contains troubleshooting guides for latency/permission issues that should inform error handling.

**Moment Creation (Text + Media) Spec (`agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`)**
- Defines the unified capture sheet architecture, toggles between memory types, and offline queuing patterns to mirror.
- Describes media attachment limits, upload progress UX, and tagging approaches that should stay consistent.
- Establishes LLM-based title generation conventions (length, audit timestamps) that Stories should follow for parity.

**Voice Dictation for Notes Spec (`/Users/benjaminmackenzie/Dev/vip/agent-os/specs/2025-11-16-voice-dictation-for-notes`)**
- Captures lessons learned about waveform controls, cancel/confirm UX, and dictation flagging applicable to Stories.
- Outlines offline dictation expectations and retry flows that can be adapted to the Memories queue.
- Highlights the need for microphone permission education and simplified data storage (transcript vs. audio) to reference.

## Out of Scope
- Android implementation or legacy plugin integration until the native plugin gains parity.
- Multi-language transcription controls, profanity filtering, or advanced voice commands (undo/delete) in this release.
- Background recording when the app is minimized or screen-locked.
- Sharing/export workflows triggered directly from the capture sheet.
- Collaborative editing, comments, or narrator attribution beyond single-user stories.
- Deleting raw audio automatically after processing (must remain available for retries).
- Automatic suggestion of memory type based on transcript content.
- Server-side attachment editing beyond storing paths provided by the client.

# Specification: Moment Creation (Text + Media)

## Goal
Deliver a unified, dictation-first capture experience that lets users record a Moment (or switch to Story/Memento) with optional description, quick media attachments, passive metadata capture, and seamless Supabase storage so memories can be saved in seconds and refined later.

## User Stories
- As a parent on the go, I want to hold down a single capture control, dictate what happened, and snap a few photos without dealing with multiple screens so that I never miss a moment.
- As a storyteller, I want the app to draft a sensible title from what I said while still letting me edit it afterward so I can keep the flow uninterrupted but maintain accuracy.
- As a memory keeper, I want the capture form to remember when and where I was, plus let me tag the memory, so I can organize everything without manual data entry.
- As a traveler who is often offline, I want the app to queue whatever I captured so nothing is lost and everything syncs automatically when service returns.

## Experience Overview
- Launching capture opens a full-screen Flutter sheet centered on the in-house dictation plugin.
- The sheet defaults to `Moment` mode with pill-style toggles to switch to `Story` or `Memento` at any time; switching updates copy/help text but keeps the current transcript/media selections.
- Users press/hold (or tap) a microphone control to dictate; transcription text is visible and editable. Description input is optional and can remain blank.
- Title is generated after Save via the LLM from the captured transcript; users can edit the title later from the detail view.
- Media tray sits beneath the transcript with buttons for `Camera`, `Gallery`, and `Voice-only`. Camera opens the built-in capture experience (reusing existing plugin dependencies where possible). Gallery uses `image_picker`. Selected items show as thumbnails with remove icons.
- Primary action is `Save` (enabled once there is at least transcript text, media, or tags). Secondary actions: `Cancel`, `Discard draft` (if content exists).

## Functional Requirements

### Unified Capture Canvas
- Single Riverpod-backed widget handles all three memory types; pass the selected type with each save to downstream services.
- Persist unsaved state in-memory while the sheet is open; if the user closes without saving, prompt to discard.

### Voice Dictation & Title Generation
- Use the in-house dictation plugin for audio capture and real-time transcription; ensure the microphone UI matches accessibility spacing guidelines.
- Store both the raw audio transcript and the generated title for each Moment. Expose API for future re-generation of titles from stored transcripts.
- Title creation pipeline: send trimmed transcript to LLM service, apply product voice guidelines, truncate to ≤60 chars, and fall back to “Untitled Moment” if LLM fails. Record `title_generated_at` timestamp for auditing.

### Media Handling
- Support up to **10 photos** and **3 videos** per Moment. Enforce limits client-side (disable add buttons and show subtle helper text when limits reached).
- Allow immediate preview and removal of each asset. Videos show length badges; photos show aspect-fit thumbnails.
- Camera option should reuse Flutter camera plugin; ensure we avoid bespoke native code beyond plugin configuration. If advanced native work becomes necessary, gate it behind a feature flag.
- Defer uploads to Supabase Storage until the user taps Save. During upload, show unified progress indicator with per-file retries.

### Metadata & Tagging
- Capture `captured_at` timestamp at the moment Save is pressed; also store `device_timestamp` when the first asset or transcript starts for auditing drift.
- Attempt passive location capture via platform geolocation APIs (with OS permission prompts). If permission denied, mark `location_status=denied` and proceed.
- Provide a subtle freeform tagging component (chips with typeahead). Tags must be optional, case-insensitive, and trimmed; store separately for reuse.

### Save Flow & Draft Behavior
- Save is allowed even if description is empty; the presence of audio transcript, media, or tags counts as "content."
- After Save completes, navigate to the relevant detail screen and surface a toast summarizing uploads.

### Offline Capture & Queueing
- Allow users to complete the full capture experience without an internet connection; Save persists all transcript text, selected media (paths + metadata), and tags into a durable local queue.
- Show clear status chips (“Queued”, “Syncing”, “Needs Attention”) on the confirmation state so users know the Moment is safe even if uploads are pending.
- Automatically retry queued Moments once connectivity is restored; retries must be resumable (partial uploads continue) and respect media caps.
- Expose a manual “Sync now” action inside the capture sheet overflow for edge cases where automatic retry is delayed.
- Block duplicate submissions by tagging queue entries with deterministic local IDs that map to server IDs after sync.

### Validation & Error Handling
- Ensure at least one of: transcript text, photo, video, or tag exists before enabling Save.
- Show inline errors for failed uploads, transcript generation issues, or location denials. Allow retry without losing other data.
- Respect accessibility: minimum hit areas, voice-over labels for toggles and thumbnails.

## Data & Storage
- All memory types (Moments, Stories, and Mementos) are stored in the unified `memories` table with a `memory_type` field (`memory_type_enum` enum) that differentiates rows.
- The `memories` table includes `raw_transcript text`, `generated_title text`, `title_generated_at timestamptz`, `tags text[]`, `captured_location geography(Point,4326)` (nullable), `location_status text`, `memory_type memory_type_enum` enum('moment','story','memento'), `input_text text` (raw user text from capture UI), and `processed_text text` (LLM-processed text, nullable until processing completes).
- Moments are filtered via `memory_type = 'moment'` when querying the `memories` table.
- **Text Model**: `input_text` stores raw user input from the capture UI. `processed_text` stores LLM-processed cleaned descriptions (for moments) or narratives (for stories) once processing completes. On initial save, `processed_text` is NULL.
- Media arrays (`photo_urls`, `video_urls`) continue to store Supabase Storage paths. Ensure server-side functions clean up orphaned files on deletion.
- Supabase Edge Function handles LLM title generation to keep keys server-side; client only sends transcript + memory type.
- Maintain a local persistent queue (e.g., `QueuedMoment` Hive box/SQLite table) that stores payloads, local media URIs, retry counts, and timestamps until server confirmation arrives.

## Technical Considerations
- Riverpod providers manage capture state, plugin controllers, and Save actions; isolate dictation lifecycle to avoid memory leaks.
- Implement optimistic UI while uploads run, but block duplicate submissions.
- Use Supabase Storage signed URLs for previews; cache in-memory until the Moment detail view refreshes.
- Provide a foreground service/background task that watches connectivity changes and flushes queued Moments with exponential backoff and telemetry so failures are diagnosable.
- Logging: trace dictation start/stop, media adds/removals, Save success/failure for analytics.
- Localization-ready strings (title suggestions, helper text) per conventions standard.

## Visual Design
- No visual assets were provided; follow mission guidance for a clean, scrapbook-inspired UI. Use soft card backgrounds for media thumbnails and clear contrast for mic controls.
- Tag chips should match existing design tokens (rounded corners, subtle shadows) to maintain consistency.

## Existing Code to Leverage
- None identified; treat as greenfield but plan to reuse tagging and capture components elsewhere once built.

## Out of Scope
- Autosaving drafts beyond the “save without description” flow.
- Automatic inference of memory type from transcript (manual toggles only).
- Advanced native camera customizations beyond what Flutter plugins support out of the box.
- Collaborative tagging or shared editing flows.
- Rich text formatting in descriptions.

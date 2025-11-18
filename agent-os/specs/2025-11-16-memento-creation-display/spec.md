# Specification: Memento Creation & Display

## Goal
Deliver a Memento experience that mirrors the polish and behavior of existing Stories and Moments: capture through the unified sheet without extra fields, generate titles automatically, surface Mementos inside the timeline with consistent badges, and render a Moment-quality detail page with matching metadata, actions, and offline resilience.

## User Stories
- As a sentimental collector, I need to snap a photo or write a quick note about an object without filling out extra fields so nothing stops me from saving it.
- As a timeline browser, I expect every memory card (Story, Moment, Memento) to look and behave the same so I can scan the feed without relearning controls.
- As someone revisiting memories, I want the Memento detail page to show the same metadata, tags, and media presentation I already know from Moments so the experience feels cohesive.

## Experience Overview
- **Creation:** Users open the existing capture sheet, toggle to `Memento`, and rely on the mic control, description text box, and media tray already implemented. Save becomes available when the user has provided either description text or at least one media asset. No dedicated title field is shown; titles are generated post-save via the LLM pipeline and can be edited later in the detail view.
- **Timeline:** The unified timeline feed renders Mementos using the same card container, shadows, and spacing as Stories/Moments. Each card shows the generated title (or “Untitled Memento”), the friendly timestamp, and the `Memento` badge, plus the primary thumbnail derived from the first photo/video. No extra metadata rows or category chips are added in this spec.
- **Detail View:** Opening a Memento presents the exact Moment detail layout—hero media carousel (even if only one asset), location/timestamp/tag metadata rows, share/edit/delete pills, and the same typography. Related-memory chips remain hidden until the future linking spec is delivered.

## Functional Requirements

### Unified Capture Sheet Behavior
- The capture sheet’s `Memento` mode shares the same Riverpod-backed controller as Stories/Moments; switching modes preserves current transcript/media selections.
- Inputs available: push-to-talk microphone (dictation plugin), description multiline text field, media tray with `Camera`, `Gallery`, and `Voice-only` buttons (voice-only simply allows text-only submission).
- Validation rule: enable `Save` when at least one of the following exists: description text (>=1 non-whitespace character) or at least one photo/video. Audio-only entries route to the Story flow, so Memento save requires visual or text content.

### Title Generation & Editing
- Remove the manual title input for Mementos. On save, send the captured description text (trimmed) plus optional tag/context to the existing LLM title-generation edge function.
- Generated titles truncate to ≤60 characters, follow product voice guidelines, and fall back to “Untitled Memento” if generation fails.
- Users can edit titles from the detail view using the same inline edit control as Stories/Moments; edits overwrite the generated value but keep `title_generated_at` metadata for auditing.

### Media & Metadata Handling
- Support up to 10 photos and 3 videos per Memento (matching Moment caps). Enforce limits client-side with disabled add buttons and helper text.
- Capture metadata identical to Moments: `captured_at`, `device_timestamp`, passive location (city/state + coordinates) when permission granted, tag chips with typeahead, and capture type flag set to `memento`.
- Store media paths in Supabase Storage arrays and persist tags/location fields in the existing schema so queries stay unified.

### Save Flow & Offline Behavior
- Defer uploads until `Save` is tapped; queue payloads offline when connectivity is unavailable using the same durable queue structure (local IDs, retry counts, resumable uploads).
- Present the same progress indicators, queued/syncing status chips, and manual “Sync now” option described in the Moment creation spec.
- Prevent duplicate submissions by reusing the deterministic local ID mapping approach already implemented for other memory types.

### Timeline Integration
- Filtered or unified timeline views must treat Mementos as first-class entries using the shared provider and pagination behavior (reverse chronological, date headers, skeleton loaders, pull-to-refresh).
- Card layout requirements:
  - Leading thumbnail from primary media asset (photo or poster frame for video) with the same aspect handling as Moments.
  - Title text (generated/edited) limited to one line with ellipsis; fallback string “Untitled Memento”.
  - Friendly timestamp format identical to Stories (e.g., `3d ago • Nov 13, 2025`).
  - `Memento` badge styled exactly like the other memory badges; positioned consistently across cards.
  - No description snippet or additional metadata in this release.

### Detail View Structure
- Reuse the Moment detail screen scaffold: app bar with back + share icons, `CustomScrollView` body, hero carousel with `PageView` + `InteractiveViewer`, metadata band, tag chips, and floating edit/delete pills.
- Content order: generated/edited title → description text (markdown subset with “Read more” fold) → media carousel (photos/videos, pinch-to-zoom, inline playback) → metadata band (timestamp, location, tag list) → action pills.
- Disable related-memory section until the linking feature exists; hide the row entirely to avoid empty placeholders.

### Actions & Sharing
- Share icon triggers the same Supabase share-link generation used by Moments. If share link creation fails, show the existing “Sharing unavailable” toast and disable until refresh.
- Edit opens the capture sheet in edit mode with existing data preloaded; ensure the title field remains hidden/editable via inline control only.
- Delete behavior, confirmation sheets, and event logging mirror the Moment detail spec.

### Accessibility & Consistency
- Maintain 44px tap targets, VoiceOver strings, and localization patterns as described in the Moment/Story specs.
- Ensure that toggling to `Memento` updates accessibility labels (e.g., “Capture memento microphone”).
- Friendly timestamps respect locale; metadata rows hide when data is absent to avoid awkward spacing.

### Error & Edge States
- Loading skeletons for detail view mirror Moment detail placeholders.
- If media fails to load, show inline retry controls identical to Moments.
- When offline, disable share/edit/delete according to existing offline policy (edit/delete only if queue-supported, otherwise show explanatory tooltip/badge).

## Data & Storage
- All memory types (Moments, Stories, and Mementos) are stored in the unified `memories` table with a `memory_type` field (`memory_type_enum` enum) that differentiates rows.
- The `memories` table stores `id`, `user_id`, `input_text` (raw user text from capture UI), `processed_text` (LLM-processed cleaned description, nullable), `photo_urls`, `video_urls`, and all shared fields:
  - `raw_transcript` (optional, if dictation used for description), `generated_title`, `title_generated_at`.
  - `photo_urls text[]`, `video_urls text[]` (arrays for multiple media).
  - `tags text[]`, `captured_location geography(Point,4326)`, `location_status text`, `memory_type memory_type_enum` enum('moment','story','memento').
  - `device_timestamp` for audit, `metadata_version` for future migrations.
- Mementos are filtered via `memory_type = 'memento'` when querying the `memories` table.
- **Display Text Logic**: Prefer `processed_text` (LLM-processed cleaned description) for display, falling back to `input_text` (raw user text) if `processed_text` is null or empty.
- Storage pipeline reuses Supabase Storage buckets and thumbnail generation functions (if any). When Save succeeds, trigger thumbnail generation for timeline previews.

## Technical Considerations
- Riverpod providers: extend the unified capture provider to treat `captureType=memento` with the adjusted validation rule (description or media). Ensure state serialization covers the tags/location fields.
- Reuse the title-generation edge function; only parameter change is `context='memento'` so copy tone fits object-centered stories.
- Timeline/detail providers should share caches so edits/delete propagate seamlessly; emit events on successful edit/delete to update lists.
- Telemetry: log capture mode, media counts, auto-title success/failure, offline queue events, and detail view interactions for parity with other memory types.
- Testing: add widget tests that confirm Save button enables with description-only or photo-only states, and integration tests covering offline queue/resume for Mementos.

## Visual Design
- No new assets provided; follow the Moment visual system exactly—soft card backgrounds, badge styling, carousel drop shadows, metadata row icons.
- Ensure the `Memento` badge color token aligns with the existing palette (likely same as `Moment` unless differentiated previously).

## Existing Code to Leverage
- `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md` for capture sheet behavior, offline queue, and validation patterns.
- `agent-os/specs/2025-11-16-moment-detail-view/spec.md` for detail layout, metadata rows, action pills, and media carousel implementation.
- `agent-os/specs/2025-11-16-story-list-detail-views/spec.md` for timeline card consistency, friendly timestamp format, and share/edit behaviors.

## Out of Scope
- Related-memory linking UI or backend logic (handled in the future “Link Related Memories” initiative).
- New metadata types (categories, monetary value, acquisition date) beyond what Moments already capture.
- Experimental capture inputs such as 3D scanning, AR placement previews, or bespoke camera interfaces.
- Desktop/web-specific layouts outside the mobile-first Flutter experience.

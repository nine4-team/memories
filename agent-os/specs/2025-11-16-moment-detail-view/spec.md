# Specification: Moment Detail View

## Goal
Create a premium-quality Moment detail experience that showcases every piece of captured context (text, photos, videos, metadata) in an elegant layout, while giving users safe controls to edit, delete, and share memories without leaving the mobile app.

## User Stories
- As a parent capturing milestones, I need to open a Moment and relive every photo, video, and note in one place so I can share it with family.
- As a curator of my own history, I want edit/delete actions close at hand but guarded by confirmation so I can correct mistakes without fear of losing memories.
- As someone who shares memories with people outside the app, I need a share button that generates a public-friendly experience so others can view the Moment easily.

## Experience Overview
- Entry: Tapping any Moment card (timeline or search results) pushes this full-screen Flutter route with a standard back arrow and share icon in the app bar.
- Content stack: Title → rich description (collapsible “Read more”) → media carousel block. The carousel renders all photos/videos in capture order; tapping any media opens a lightbox overlay.
- Context band: Under the media, a metadata section shows human-readable timestamp, location (City, State), and linked related Memories (Stories/Mementos). Rows render only when data exists.
- Actions: Share lives in the app bar; Edit/Delete appear as persistent pill icons floating near the lower-right edge of the scroll area. Delete always opens a confirmation sheet.
- Scrolling: Entire page scrolls; media carousel occupies full width but keeps aspect ratio; text uses elegant typography scales aligned with product standards.

## Functional Requirements

### Screen Structure & Navigation
- Route name `moment/detail/<id>` accessible from timeline, search, notifications, or share deep links.
- App bar: back arrow (pop), title ellipsis (one line), share icon. Share triggers current share flow (native sheet) and gracefully handles backend unavailability.
- Content uses `CustomScrollView` with padded `SliverList`; ensure safe area insets.
- Preserve scroll offset/state when user edits Moment and returns.

### Text & Typography
- Title uses display font, multi-line with graceful wrapping. If empty, show "Untitled Moment".
- **Display Text Logic**: Prefer `processed_text` (LLM-processed cleaned description) for display, falling back to `input_text` (raw user text) if `processed_text` is null or empty. For moments, `processed_text` contains the LLM-cleaned version once processing completes.
- Description supports bold, italic, bulleted lists, and hyperlinks. Render markdown/RTF subset with consistent spacing.
- "Read more" collapse triggers after ~6 lines; expand animates height smoothly and maintains scroll anchor.

### Media Presentation
- Primary carousel leverages `PageView` + `InteractiveViewer` for swipe + pinch-to-zoom per asset.
- Photo slide: fit width, dark background, double-tap zoom in/out, tap opens full-screen lightbox with background dim and indicators.
- Video slide: poster frame thumbnail with inline controls (play/pause, scrubber). Videos never autoplay; audio respects device mute switch.
- Lightbox: vertical dismissal gesture, indicator dots, share + save actions (optional future) but must at least support close/back.
- Media ordering follows `media_position` data; fallback to upload order.

### Context Panel
- Timestamp displayed as `Nov 3, 2025 at 4:12 PM` (device locale aware). Include relative label (“3 weeks ago”) beneath when feasible.
- Location row shows “City, State” with location pin icon; tap optional map deeplink placeholder (disabled until map spec ready).
- Related memories section lists linked Stories/Mementos with pill chips; tapping navigates to respective detail routes.
- Hide any row without data; collapse spacing accordingly.

### Actions & Safeguards
- Edit icon (pencil) opens existing Moment edit flow modally. Keep icon persistent at lower-right, above safe area.
- Delete icon (trash) triggers confirmation bottom sheet with summary (“Delete ‘Trip to Big Sur’?”) and secondary warning text before irreversible action.
- Share icon uses OS share sheet. When backend share link unavailable, show inline toast “Sharing unavailable. Try again later.” and disable action until next refresh.

### Error, Offline, and Loading States
- While loading, show skeleton placeholders for text blocks and carousel aspect box.
- If media fails to load, display retry button within slide and a generic placeholder image/video icon.
- Offline mode allows viewing cached data; disable share and show offline badge. Edit/Delete queue locally only if upstream workflow supports it (otherwise disable with tooltip explaining requirement).

## Data & Storage
- Detail endpoint must return: id, title, `input_text` (raw user text), `processed_text` (LLM-processed cleaned description, nullable), rich text body (markdown or HTML subset derived from display text logic), ordered photo list (URL, width/height, caption), ordered video list (URL, duration, poster), capture timestamp, capture timezone, location (city, state, lat/long), related Story IDs, related Memento IDs, share link (optional), `memory_type`, and `updated_at` for cache busting.
- Media URLs should be signed Supabase Storage paths with expiry long enough for detail sessions; client refreshes tokens when expired.
- Share action requests/creates a `public_share_token` if absent; API responds with shareable URL for downstream UI or returns error state handled above.

## Technical Considerations
- Flutter + Riverpod: create `MomentDetailController` that fetches data, exposes async state, and manages share/edit/delete flows.
- Use `Hero` transitions for the primary image/video from the timeline card to maintain continuity.
- Leverage `InteractiveViewer` with constrained scale (1x–3x) to keep zoom manageable.
- Persist edit/delete/share analytics events via existing logging service.
- Delete action should optimistically pop the detail view and inform upstream lists to remove the Moment (e.g., event bus or shared provider).
- Ensure lightbox and inline video both respect memory constraints; dispose controllers when off-screen.

## Visual Design Notes
- Aim for “coffee table book” aesthetics: generous whitespace, high-contrast typography, and subtle drop shadows under the carousel.
- Keep action icons minimalistic, with rounded pills matching brand accent color and soft shadow to float above content.
- Metadata rows use muted label text with icons; when rows are hidden, separators adjust to avoid gaps.
- Darkened backdrop for lightbox should include blur for premium feel; provide indicator dots for multi-asset context.

## Existing Code to Leverage
- Reuse image/video rendering primitives from Moment creation preview components if available.
- Timeline cards already fetch capture date/location; extend their repository/service to provide the richer dataset for detail view.
- Reuse global markdown/rich-text renderer for description formatting to maintain typographic consistency.

## Out of Scope
- Comments, reactions, and inline replies.
- Advanced media editing (reordering, caption editing) from the detail view.
- Map previews or navigation for locations beyond text display.
- Batch actions, multi-select, or cross-memory editing from this screen.
- Sharing management UI (link expiry, permissions) beyond the single share action.

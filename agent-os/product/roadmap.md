# Product Roadmap

## MVP - Core Memory Capture & Viewing

1. [x] **User Authentication & Profile** — Implemented (2025-01-17). Supabase Auth + profiles complete; see `agent-os/specs/2025-11-16-user-auth-and-profile/tasks.md` and `docs/release_notes_auth.md`. `XS`

2. [x] **Moment Creation (Text + Media)** — Implemented (2025-11-17). Core capture flow with title generation, media upload to Supabase Storage, offline queue & sync, location capture, and basic detail navigation complete; see `agent-os/specs/2025-11-16-moment-creation-text-media/implementation/remaining-work.md`. `S`

3. [ ] **Moment List & Timeline View** — Display all user's Moments in reverse chronological feed with date grouping headers; show thumbnails for media-rich moments and text preview for text-only moments. `S`

4. [ ] **Moment Detail View** — Full-screen view of individual Moment showing title, text, photos (gallery view), and videos (inline player); include edit and delete options. `XS`

5. [ ] **Voice Story Recording & Processing** — Integrate in-house Flutter dictation plugin; record audio, save to Supabase Storage, process transcription, and transform into narrative format (backend processing); create Story object with title and narrative text. `M`

6. [ ] **Story List & Detail Views** — Display Stories in timeline feed with audio waveform icon and narrative preview; full Story detail view shows complete narrative with audio playback option; include edit and delete. `S`

7. [ ] **Memento Creation & Display** — Create Mementos with title (required), object photo (required), and description text; display in timeline feed with visual badge; detail view shows large image with description. `S`

8. [ ] **Unified Timeline Feed** — Combine Stories, Moments, and Mementos in single reverse-chronological feed with visual differentiation; add filter tabs (All/Stories/Moments/Mementos) at top. `S`

9. [ ] **Search Functionality** — Implement full-text search across all Stories, Moments, and Mementos using PostgreSQL text search; persistent search bar in app header with instant results. `S`

## Phase 2 - Associations & Enhanced Organization

10. [ ] **Link Related Memories** — Enable many-to-many relationships between Stories/Moments/Mementos via junction tables; UI to add/remove links when viewing or editing any memory; display "Related Memories" section on detail screens. `M`

11. [ ] **Fast Capture Floating Action Button** — Implement FAB with quick-action menu: Record Story (immediate dictation), Capture Moment, Save Memento; optimize for speed and minimal friction. `S`

12. [ ] **Enhanced Timeline Filtering & Sorting** — Add date range filters, sort options (newest/oldest), and ability to filter by media type (has photos, has videos, text-only). `S`

13. [ ] **Batch Media Upload** — Allow multiple photos/videos to be selected and uploaded at once for a single Moment; gallery-style organization of media within Moments. `S`

## Phase 3 - Sharing & Collaboration

14. [ ] **Share Individual Memory** — Generate shareable link or export for any Story/Moment/Memento; recipients can view beautifully rendered memory without requiring account (public view). `M`

15. [ ] **Invite Collaborators** — Allow users to invite others (via email) to contribute to specific Stories or Moments; collaborators can add comments, link related memories, or add their own perspective. `M`

16. [ ] **Shared Memory Collections** — Create collaborative albums where multiple users can contribute Stories, Moments, and Mementos (e.g., family album, friend group trip memories). `L`

17. [ ] **Privacy Controls** — Set privacy levels per memory (Private, Shared with specific people, Public link); manage collaborator permissions (view-only vs. can-edit). `M`

## Phase 4 - Memory Digests & Social Features

18. [ ] **Periodic Memory Digests** — Auto-generate monthly, seasonal, and yearly summaries of memories; beautiful presentation with selected highlights; ability to manually curate and share digests. `L`

19. [ ] **Social Media Integration** — Enable one-tap sharing of Moments to Instagram with formatted image/caption; explore APIs for other platforms (Facebook, Twitter). `M`

20. [ ] **Memory Notifications & Reminders** — "On this day" style reminders of past memories; gentle prompts to capture new memories during quiet periods; customizable notification preferences. `S`

> Notes
> - Order prioritizes getting core capture and viewing functionality working first (Moments, Stories, Mementos)
> - Phase 2 adds organizational power and speed optimizations
> - Phase 3 enables the social/sharing aspects that make memories more valuable
> - Phase 4 brings advanced features that increase engagement over time
> - Each item represents an end-to-end functional and testable feature




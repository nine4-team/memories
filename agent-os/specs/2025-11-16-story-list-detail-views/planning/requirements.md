# Spec Requirements: Story List & Detail Views

## Initial Description
**Story List & Detail Views** — Display Stories in timeline feed with audio waveform icon and narrative preview; full Story detail view shows complete narrative with audio playback option; include edit and delete.

## Requirements Discussion

### First Round Questions

**Q1:** I assume the Story List is a dedicated screen that shows only Stories in reverse chronological order (using `created_at`) instead of sharing the unified feed component. Is that correct, or should we reuse the upcoming unified timeline container and just filter it to Stories?
**Answer:** Reuse the unified timeline container and simply filter it to Stories so we benefit from the shared layout/logic.

**Q2:** I’m thinking each Story card should include the title, friendly timestamp, 1–2 sentence narrative preview, and an inline audio waveform/duration indicator for quick recognition. Should we also surface tags or related memory badges on the card, or keep the card minimal for now?
**Answer:** Keep the card minimal—only title and friendly timestamp. No narrative preview, waveform/duration indicator, tags, or related-memory badges.

**Q3:** For loading behavior, I assume we’ll mirror the Moment List pattern: infinite scroll batches of ~20 Stories with skeleton loaders and pull-to-refresh. Should we instead use explicit pagination or add list-level filters (e.g., narrator, tagged people) in this first release?
**Answer:** Use the same infinite scroll approach from the unified timeline; no additional filters or pagination changes are needed now.

**Q4:** On the detail view, I’m assuming the narrative text leads the page with a sticky audio player near the top using our `audioplayers` plugin. Is that hierarchy right, or do you prefer the audio waveform hero first with text content below?
**Answer:** Title should be at the top, audio player next (can be between title and narrative), and narrative text below. Open to the audio player being sticky if that’s easiest.

**Q5:** I’m assuming edit/delete actions live in an overflow menu on the detail view that routes to the Voice Story editor and confirms deletions inline. Should we duplicate those controls in the list (e.g., swipe actions or long-press) so users can act without opening the detail view?
**Answer:** Follow the Moment Detail pattern: persistent edit/delete icons near the bottom along with metadata. No extra list-level actions. Also, please explain what you mean by “voice story editor” and “inline confirmation” using clearer language.

**Q6:** Are there any aspects you explicitly want to exclude for this iteration (for example sharing/export, collaborative comments, linking related memories, or transcription editing)?
**Answer:** No specific exclusions mentioned beyond keeping the list card minimal; focus on parity with Moments for now.

### Existing Code to Reference

**Similar Features Identified:**
- Feature: Moment Detail View spec - Path: `agent-os/specs/2025-11-16-moment-detail-view/spec.md`
- Components to potentially reuse: Detail action pill layout, metadata rows, share icon placement, infinite scroll behaviors from unified timeline implementation.
- Backend logic to reference: Same data-fetching patterns used by the unified timeline and Moment detail flows.

### Follow-up Questions

**Follow-up 1:** Should the audio player stay visible (mini sticky player) while people scroll through the narrative, or is it fine to keep it fixed between the title and the text without stickiness?
**Answer:** Make it sticky on scroll if it’s easy; otherwise leave it in place.

**Follow-up 2:** For the edit/delete pills that mirror the Moment detail view, do you also want the share icon and metadata rows to mirror the exact order/visual treatment from `agent-os/specs/2025-11-16-moment-detail-view/spec.md`, or is there anything you’d like to change for Stories?
**Answer:** Keep the share icon and metadata rows consistent with the Moment detail view.

## Visual Assets

No visual assets provided.

## Requirements Summary

### Functional Requirements
- Story List reuses the unified timeline container, filtered to Story entries only.
- Story cards show title + friendly timestamp only.
- Unified timeline behaviors (infinite scroll, pull-to-refresh, skeleton states) apply without changes.
- Story Detail layout: title, sticky audio player (when feasible), narrative text.
- Edit/Delete controls appear as persistent pills near the bottom alongside metadata, matching Moment detail behavior.
- Share icon and metadata rows mirror Moment detail view placement and styling.

### Reusability Opportunities
- Reuse unified timeline infrastructure for filtering and batching.
- Borrow Moment detail UI components (action pills, metadata rows, share icon positioning).
- Leverage existing audio player component and controller patterns from voice recording/ Moment experiences.

### Scope Boundaries
**In Scope:**
- Story List filtered view, minimal cards, infinite scroll.
- Story Detail layout updates (sticky audio player, consistent metadata/actions).
- Sharing consistent with Moment detail behavior.

**Out of Scope:**
- Additional filters, tags, or badges on Story cards.
- Narrative previews, waveform thumbnails, or card-level actions.
- New sharing/export workflows or collaboration tools.

### Technical Considerations
- Ensure filtering leverages existing unified timeline queries (likely `memory_type = 'story'`).
- Sticky audio player should reuse Flutter audio components and respect the Moment detail UX for consistency.
- Edit/Delete flows should call the same backend endpoints as current Story management, with confirmations matching Moment patterns.
- Maintain accessibility parity with Moment detail controls (tap targets, labels, friendly timestamps).

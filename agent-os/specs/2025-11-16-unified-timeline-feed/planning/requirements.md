# Spec Requirements: Unified Timeline Feed

## Initial Description
**Unified Timeline Feed** — Combine Stories, Moments, and Mementos in single reverse-chronological feed with visual differentiation; add filter tabs (All/Stories/Moments/Mementos) at top.

## Requirements Discussion

### First Round Questions

**Q1:** I’m assuming the unified feed should interleave Stories, Moments, and Mementos strictly by each record’s `created_at` (newest first). Is that correct, or should any type get pinned or promoted (e.g., most recent Story stays above newer Moments)?  
**Answer:** No type should be pinned or promoted—just show everything in order by date.

**Q2:** For the All/Stories/Moments/Mementos filter tabs, I’m thinking of a segmented control pinned beneath the app bar that updates the list immediately and remembers the last tab per session. Should we instead open a separate filter sheet or reset to “All” every time the screen loads?  
**Answer:** Segmented tabs that update immediately and remember the selection are perfect; no separate sheet needed.

**Q3:** To visually differentiate entries, I plan to reuse each feature’s existing card styles (story waveform icon, moment media thumbnails, memento badge) with consistent padding and add a subtle type chip. Would you rather design a brand-new unified card layout before reusing what we have?  
**Answer:** Reuse the existing card styles, style them consistently, and add the subtle type chip.

**Q4:** I’m assuming we’ll show date headers whenever the calendar day changes, with month breaks automatically emerging from those headers. Should we introduce any additional grouping (e.g., “Earlier this week”, “Last month”) or keep it purely date-based?  
**Answer:** Don’t use daily headers; group by Year > Season > Month as previously requested.

**Q5:** For pagination, I’m planning to load ~20 items at a time via a combined Supabase query and fetch more as the user scrolls. Do you want any pull-to-refresh or manual “Load more” controls instead of infinite scrolling?  
**Answer:** That pagination approach is fine.

**Q6:** When a user taps a card, I’m assuming we push to the existing Story/Moment/Memento detail screens and only surface quick actions (like edit/delete) inside those screens, not inline on the feed. Should we surface any inline actions (e.g., swipe to delete, quick share) directly on the feed cards?  
**Answer:** Navigate to the detail screens and do not show any actions on the cards.

**Q7:** Are there any specific interactions or data points you explicitly want to exclude from this first version (e.g., related-memory links, batch operations, pinned filters)?  
**Answer:** Nothing specific needs to be excluded.

### Existing Code to Reference
No similar existing features identified for reference.

### Follow-up Questions

**Follow-up 1:** For the year/season/month groupings, can you confirm the hierarchy (e.g., Year > Season > Month) and whether we should use standard meteorological seasons (Winter = Dec–Feb, etc.) or your own definitions?  
**Answer:** Use Year > Season > Month with standard meteorological seasons.

**Follow-up 2:** Are there existing list screens or components for Stories, Moments, or Mementos that we should mirror for consistency (paths or file names help), or should we treat this as a fresh build?  
**Answer:** Treat this as a fresh build but create shared widgets/components so everything is easy to update.

## Visual Assets

### Files Provided:
No visual assets provided.

## Requirements Summary

### Functional Requirements
- Unified feed interleaves Stories, Moments, and Mementos strictly by `created_at`.
- Filter tabs (All/Stories/Moments/Mementos) use segmented control, persist last selection, and update immediately.
- Cards reuse each memory type’s existing design language with consistent spacing and a type chip.
- Timeline grouping hierarchy: Year > Season (standard meteorological) > Month; no per-day headers.
- Infinite scrolling loads ~20 entries per request with additional fetches on scroll.
- Tapping any card navigates to its existing detail screen; no inline actions.

### Reusability Opportunities
- Build shared widgets/components for the feed so layout updates propagate across memory types.
- No specific existing screens were identified for reuse beyond staying stylistically consistent.

### Scope Boundaries
**In Scope:**
- Combined timeline, segmented filters, shared card styling, grouping logic, pagination, navigation to detail screens.

**Out of Scope:**
- Inline actions (edit/delete/share) on feed cards.
- Additional interaction patterns like related-memory links or batch operations in this version.

### Technical Considerations
- Requires unified query across Stories/Moments/Mementos ordered by timestamp with pagination.
- Grouping logic must translate timestamps into Year/Season/Month buckets using standard season definitions.
- Shared components should align with Flutter theming and remain easy to extend.


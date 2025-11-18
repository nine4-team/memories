# Spec Requirements: Memento Creation & Display

## Initial Description
**Memento Creation & Display** — Create Mementos with title (required), object photo (required), and description text; display in timeline feed with visual badge; detail view shows large image with description.

## Requirements Discussion

### First Round Questions

**Q1:** Since the unified capture sheet already supports switching to `Memento` mode (per the Moment creation spec), can we reuse that flow and simply enforce that a title + at least one photo exist before Save, or do you envision a dedicated creation surface with different controls?
**Answer:** Use the exact same controls already defined for the capture sheet (microphone, description text box, photo/video picker) with no separate UI; do not enforce both title and photo because a memento can have a title, description, or image (any of those is fine) and titles should be auto-generated so users don’t have to enter one.

**Q2:** The existing capture experience defers uploads until Save and queues offline entries; should the Memento photo follow the same pipeline (local queue + Supabase Storage upload + retry states), or do you want immediate upload/commit because only one asset is required?
**Answer:** Follow the exact same plan used for Moments and Stories—same capture flow, deferred uploads, offline queueing, and retry behavior.

**Q3:** On the timeline, I’m assuming we reuse the same card container from the unified feed with a “Memento” badge, hero thumbnail, and friendly timestamp (matching the Story list spec). Would you also like to show a sentimental category or short description snippet on the card, or keep it as title + badge + time for consistency?
**Answer:** Yes to reusing the existing card pattern with the badge and thumbnail; no extra metadata beyond what the other memory types already display—keep it simple for consistency.

**Q4:** For the detail view, can we mirror the Moment detail layout (hero media carousel, metadata band, edit/delete pills) but simplify it to a single photo, title, description, and related-memory chips—or do you want a lighter-weight card presentation without the full metadata band?
**Answer:** Match the Moment detail layout exactly (hero media, metadata band, action pills, etc.) without stripping anything down.

**Q5:** Metadata: Moments capture location, tags, and capture timestamps automatically. Should Mementos inherit any of those (e.g., passive location, tagging, acquisition date) or just store title/photo/description for now?
**Answer:** Mementos should inherit the same metadata model as Moments—capture tags, timestamps, location, and display the same metadata rows so every memory type stays consistent.

**Q6:** Are we treating Mementos as linkable entities right away (so they can show “Related Stories/Moments” like the Moment detail spec), or should relationship management wait until the later “Link Related Memories” feature?
**Answer:** Push relationship management off until the dedicated “Link Related Memories” feature; no related-memory editing/viewing in this spec.

**Q7:** Anything you explicitly want to postpone in this first pass (e.g., multiple photos per memento, 3D object scanning, AR placement previews, category taxonomies)?
**Answer:** Nothing is explicitly postponed beyond the items already called out (like linking); prioritize keeping Stories, Moments, and Mementos consistent. 3D scanning was just an example and isn’t realistic right now, but overall consistency is the key requirement.

### Existing Code to Reference

**Similar Features Identified:**
- Feature: Moment Creation (Text + Media) capture sheet - Path: `agent-os/specs/2025-11-16-moment-creation-text-media/spec.md`
- Feature: Moment Detail View layout - Path: `agent-os/specs/2025-11-16-moment-detail-view/spec.md`
- Feature: Story List & Detail layout conventions - Path: `agent-os/specs/2025-11-16-story-list-detail-views/spec.md`

### Follow-up Questions
No follow-up questions were needed.

## Visual Assets
No visual assets provided.

## Requirements Summary

### Functional Requirements
- Reuse the unified capture sheet controls (mic, description input, photo/video picker) for Mementos with no additional screens.
- Allow saving when at least one of description text or media exists; titles are auto-generated via LLM and editable later.
- Ensure the capture “Description/Input” field is the single canonical text surface—dictation writes into it automatically, manual edits happen there, and any cleaned transcript we persist comes from that same field.
- Apply the same deferred upload, offline queueing, and retry logic already defined for Moments/Stories.
- Use the unified timeline card pattern with a “Memento” badge, hero thumbnail, friendly timestamp, and no extra metadata.
- Detail screen mirrors the Moment detail layout including hero media carousel, metadata rows (timestamp, location, tags), action pills, and share/edit/delete behavior.
- Capture and display the same metadata as Moments (timestamps, tags, passive location) so all memory types stay consistent.
- Relationship/linked-memory management is deferred until the dedicated linking feature ships.

### Reusability Opportunities
- Leverage the existing capture sheet implementation for Moments/Stories, including its Riverpod controllers and offline queue pipeline.
- Mirror the Moment detail screen components (carousel, metadata rows, action pills) for Memento details.
- Reuse the unified timeline card container and styling already built for other memory types.

### Scope Boundaries
**In Scope:**
- Adapting the current capture, timeline, and detail experiences to support Mementos with the same UX/metadata patterns.
- Auto-generating titles via LLM and letting users edit later.
- Renaming/synching the capture text surface to `input_text` (or equivalent) across app state, APIs, Supabase interactions, and analytics so all memory types share one text pipeline.
- Ensuring metadata (tags, timestamps, location) and timeline presentation stay in sync with other memory types.

**Out of Scope:**
- Managing or displaying related memories until the “Link Related Memories” feature is implemented.
- New experimental inputs such as 3D scanning or AR visualization beyond what the current capture sheet supports.

### Technical Considerations
- Tie into the existing LLM title-generation pipeline so Mementos receive generated titles without manual input fields.
- Share the same deferred upload/offline queue infrastructure to avoid bespoke storage logic.
- Maintain consistent metadata schemas/tables with Moments (e.g., tags arrays, location columns) for easier unified queries.
- Ensure the timeline and detail Riverpod providers can treat Mementos as first-class entries without diverging code paths.

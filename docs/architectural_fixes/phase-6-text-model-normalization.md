# Phase 6: Memory Text Model Normalization

## Objective

Define a clear, consistent text model for memories across database, backend, and app:

- **`memory_type`**: the kind of memory (moment, story, memento).
- **`input_text`**: raw user text from dictation or typing, edited in the capture UI.
- **`processed_text`**: LLM‑processed version of `input_text` (cleaned description or narrative).
- **Titles**: generated once from text by default, then owned by the user if they edit them; never part of the capture UI.

There is **no legacy data to preserve**, so this plan is intentionally non‑backwards‑compatible.

---

## Target Data Model (Database)

### 1. Core columns on `public.memories`

We standardize on the following columns for text and type:

- **`memory_type memory_type_enum NOT NULL DEFAULT 'moment'::memory_type_enum`**
  - Enum of the memory’s type: `'moment' | 'story' | 'memento'`.
  - Used everywhere (specs, code, DB) instead of “capture type”.

- **`input_text TEXT`**
  - Canonical, raw text from the user.
  - Populated directly from the capture UI (`CaptureState.inputText`).
  - May be `NULL` if the memory is purely media, or if the user did not enter text.

- **`processed_text TEXT`**
  - LLM‑processed version of `input_text`.
  - For **stories** (`memory_type = 'story'`): full narrative text (this *is* the story narrative).
  - For **moments / mementos**: cleaned‑up description text.
  - **Always represents processed text** – if the LLM has not run yet or fails, this stays `NULL`.

- **Titles**
  - `title TEXT` — **current display title** (what the user actually sees everywhere, and may edit later).
  - `generated_title TEXT` — last LLM‑generated title suggestion (for audit/debug).
  - `title_generated_at TIMESTAMPTZ` — when `generated_title` was created.

Other existing columns (`tags`, media URLs, location, timestamps, etc.) remain unchanged.

### 2. Enum type naming

We normalize enum type naming with an `*_enum` suffix:

- Enum type: **`memory_type_enum`**
  - Values: `'moment'`, `'story'`, `'memento'`.
- Column: **`memory_type memory_type_enum NOT NULL`**

If additional enums are added later (e.g., `story_status_enum`), they follow the same pattern.

### 3. Semantic rules (DB‑level view)

- `memory_type` says *what kind of memory* this row represents.
- `input_text` is **raw**; `processed_text` is **LLM‑processed**.
- Story narrative lives in `processed_text` for `memory_type = 'story'`.
- All memory types are eligible for processing:
  - `input_text` holds raw text.
  - `processed_text` holds the cleaned/narrative version, once available.

---

## Database Migration Plan

> There is no existing production data to preserve, so we prioritize clarity over backwards compatibility.

### Step 1: Rename enum type and column

We remove “capture” from the vocabulary and standardize on “memory type”.

1. **Rename enum type**:

```sql
ALTER TYPE memory_capture_type RENAME TO memory_type_enum;
```

2. **Rename column on `memories`**:

```sql
ALTER TABLE public.memories
  RENAME COLUMN capture_type TO memory_type;
```

3. **Update comments**:

```sql
COMMENT ON COLUMN public.memories.memory_type IS
  'Memory type: moment (standard capture), story (narrative with audio), or memento (curated collection).';
```

All queries, RLS policies, and RPCs that reference `capture_type` must be updated to use `memory_type` instead.

### Step 2: Normalize text columns

Create a new migration (e.g. `20251118000000_normalize_memory_text_columns.sql`) that:

1. **Rename `text_description` → `input_text`**:

```sql
ALTER TABLE public.memories
  RENAME COLUMN text_description TO input_text;
```

2. **Add `processed_text` column**:

```sql
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS processed_text TEXT;
```

3. **Update comments**:

```sql
COMMENT ON COLUMN public.memories.input_text IS
  'Canonical raw user text from dictation or typing. Edited in capture UI.';

COMMENT ON COLUMN public.memories.processed_text IS
  'LLM-processed version of input_text (cleaned description or narrative). For stories, full narrative; for other types, cleaned description.';
```

4. **Do not backfill `processed_text` from `input_text`**.  
   `processed_text` must **only** contain LLM‑processed content. Until the LLM pipeline runs successfully, `processed_text` stays `NULL`.

### Step 3: Update unified timeline RPC

**File**: `supabase/migrations/20250120000000_create_unified_timeline_feed.sql` (or a new replacement migration that drops/recreates the function).

Changes:

1. **Return `memory_type`, `input_text`, and `processed_text`**:

In the `RETURNS TABLE (...)` signature:

```sql
RETURNS TABLE (
  id UUID,
  user_id UUID,
  title TEXT,
  input_text TEXT,
  processed_text TEXT,
  raw_transcript TEXT,
  generated_title TEXT,
  tags TEXT[],
  memory_type TEXT,
  ...
)
```

2. **Select the new columns** from `memories`:

```sql
SELECT
  m.id,
  m.user_id,
  m.title,
  m.input_text,
  m.processed_text,
  m.raw_transcript,
  m.generated_title,
  COALESCE(m.tags, '{}'::TEXT[]) as tags,
  m.memory_type::TEXT,
  ...
```

3. **Update `snippet_text` to respect processed vs input text**:

Replace the old `snippet_text` logic:

```sql
LEFT(
  COALESCE(
    NULLIF(trim(m.text_description), ''),
    NULLIF(trim(m.raw_transcript), '')
  ),
  200
) AS snippet_text,
```

with:

```sql
LEFT(
  COALESCE(
    NULLIF(trim(m.processed_text), ''),
    NULLIF(trim(m.input_text), '')
  ),
  200
) AS snippet_text,
```

4. **Update filters to use `memory_type`**:

Where the function currently filters by `capture_type`, update to:

```sql
AND (
  v_memory_type_filter IS NULL
  OR m.memory_type::TEXT = v_memory_type_filter
)
```

### Step 4: Align story‑processing migrations

Once `memory_type`, `input_text`, and `processed_text` exist:

- Update the story voice‑processing migration (`extend_stories_table_for_voice_processing.sql`) so that:
  - It **does not** introduce a separate `narrative_text` column.
  - It uses **`processed_text`** as the place to store story narrative text.
  - Any story‑specific status/timestamp/retry columns remain story‑only, keyed on `memory_type = 'story'`.

This keeps the model simple: **all LLM‑processed descriptive or narrative text, regardless of type, lives in `processed_text`.**

---

## Application Alignment Plan

### 1. Models (`MomentDetail`, `TimelineMoment`, etc.)

**Files**:

- `lib/models/moment_detail.dart`
- `lib/models/timeline_moment.dart`

**Changes**:

1. Replace `textDescription` with `inputText` and `processedText`:

```dart
final String? inputText;
final String? processedText;
final String memoryType; // 'moment' | 'story' | 'memento'
```

From JSON:

```dart
inputText: json['input_text'] as String?,
processedText: json['processed_text'] as String?,
memoryType: json['memory_type'] as String? ?? 'moment',
```

2. Add a unified descriptive‑text getter:

```dart
String? get displayText {
  if (processedText != null && processedText!.trim().isNotEmpty) {
    return processedText!.trim();
  }
  if (inputText != null && inputText!.trim().isNotEmpty) {
    return inputText!.trim();
  }
  return null;
}
```

3. Ensure all UI that currently renders descriptions/narratives uses `displayText` instead of `textDescription`.

### 2. Save service (`MemorySaveService`)

**File**: `lib/services/memory_save_service.dart`

**Changes**:

1. Update the insert map to the normalized columns:

```dart
'memory_type': state.memoryType.apiValue, // already exists conceptually
'input_text': state.inputText,
// On initial save, processed_text should be NULL until LLM processing completes.
// We do NOT pre-fill processed_text with raw input_text.
'processed_text': null,
```

2. Title generation behavior (one‑shot semantics):

- On initial save, generate a title using the same text we would feed to the LLM (typically `state.inputText`).
- On success:

```dart
title: generatedTitle,            // display title (user-facing)
generated_title: generatedTitle,  // last LLM-generated title suggestion
title_generated_at: generatedAt,
```

- On failure, set a fallback `title` like `"Untitled Moment" / "Untitled Story" / "Untitled Memento"`, and **do not** set `generated_title`.

3. Later, when the story‑processing and description‑cleanup pipelines are wired up:

- Backend edge functions update:
  - `processed_text` (story narrative for stories, cleaned description for other types).
  - Story‑specific status fields (if/when added for voice‑processing).

### 3. Capture UI

**Files**:

- `lib/models/capture_state.dart`
- `lib/screens/capture/capture_screen.dart`

**Requirements**:

- `CaptureState` exposes `inputText` as the only editable text field for the capture UI (already true conceptually).
- The capture UI:
  - Binds its text field only to `state.inputText`.
  - Does **not** show or edit any title.

### 4. Detail UI (title editing)

**Files**:

- Story / moment / memento detail screens.

**Requirements**:

- Title editing, if supported, happens **only** in detail views:
  - Editing modifies `title`.
  - We never write user edits back into `generated_title`.
  - We do **not** automatically re‑run title generation after a user edit; once the user has edited `title`, it is the source of truth.

---

## Execution Order

Recommended sequence (dev → prod):

1. **DB migrations (dev branch / local)**:
   - Apply enum + column rename (`memory_capture_type` → `memory_type_enum`, `capture_type` → `memory_type`).
   - Apply normalize‑text migration (`text_description` → `input_text`, add `processed_text`, update comments).
   - Replace/update `get_unified_timeline_feed` to return `memory_type`, `input_text`, and `processed_text`, and to build `snippet_text` from processed/input text.
   - Update story‑processing migration to use `processed_text` instead of a separate `narrative_text` column.

2. **App changes**:
   - Update models (`MomentDetail`, `TimelineMoment`) to use `memoryType`, `inputText`, `processedText`, and `displayText`.
   - Update `MemorySaveService` to write `memory_type`, `input_text`, and leave `processed_text` null on initial save.
   - Verify capture UI and detail UI respect the new semantics (no title in capture; title only in details).

3. **Tests / QA**:
   - Unit tests for:
     - Text model mapping (`inputText` ↔ `input_text`, `processedText` ↔ `processed_text`).
     - `displayText` fallback logic.
   - Integration tests for:
     - Capture → save → timeline item shows correct descriptive text.
     - Story capture → later processing populates `processed_text` (once edge functions are wired).

4. **Apply to main Supabase project** once dev branch is green.

---

## Search & Full‑Text Indexing (Forward‑Looking)

When full‑text search is implemented, the search vector will:

- Include **`title`, `generated_title`, `processed_text`, and `input_text` with equal weight**.
- Optionally include **`tags`** with equal or slightly lower weight.

The intent is:

- No single text field gets special treatment; titles, cleaned text, and raw text all contribute.
- For stories, narrative search is driven by `processed_text`; for other types, by cleaned descriptions where available and `input_text` otherwise.



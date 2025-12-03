## Memory Processing Edge Functions – Auth Simplification (Remove Unused External/JWT Mode)

**Date:** 2025-12-02  
**Status:** 🟠 Planned fix – design agreed, implementation pending (no code changes yet)  

This doc captures a *design decision and implementation plan* to simplify auth in the
memory‑processing edge functions by **removing the unused “external/JWT mode”** and
treating them as **internal worker functions only**.

> **Important:** This document is *intentionally* non‑code‑changing. It describes
> what should be done and why, so that a future implementation pass can apply the
> change deliberately (and atomically) across functions and environments.

---

## 1. Current Situation (After Dispatcher Fix)

Relevant edge functions:

- `dispatch-memory-processing`
- `process-moment`
- `process-memento`
- `process-story`

### 1.1 Internal worker path (currently correct)

- `dispatch-memory-processing` is invoked from database triggers / function hooks
  (e.g. via `pg_net`) **without a user**.
- It:
  - Uses `SUPABASE_SERVICE_ROLE_KEY` to claim scheduled jobs from
    `memory_processing_status`.
  - Calls the appropriate processor (`process-moment` / `process-memento` /
    `process-story`) using an **internal header** (e.g. `X-Internal-Trigger: true`),
    *not* a user JWT.
- The processors, in “internal mode”:
  - Detect `X-Internal-Trigger: true`.
  - Use `SUPABASE_SERVICE_ROLE_KEY`.
  - Do *not* call `auth.getUser` or rely on a user JWT.
  - Operate as **backend workers** over the `memories` table plus
    `memory_processing_status` / `story_fields`.

This is the correct, modern pattern for **background jobs**:

- No JWT.
- Service‑role key for privileged internal work.
- Access constrained by schema design and explicit logic, not user sessions.

### 1.2 External “user mode” (currently legacy / unused)

Each processor also contains an **alternate code path** intended for
“user‑initiated” calls:

- If `X-Internal-Trigger` is *not* present:
  - Read `Authorization: Bearer <token>` from the request.
  - Parse out the bearer token manually.
  - Call `auth.getUser(token)` to obtain `user.id`.
  - Scope queries with `.eq("user_id", user.id)` or rely on that user id.
- This was meant to support hypothetical future flows like “Retry processing”
  from the client app directly calling `process-moment` etc.

**Today:** those flows do not exist. All processing is triggered internally by
the dispatcher, which runs in service‑role mode.

---

## 2. Problem / Smell

### 2.1 Unnecessary complexity and confusion

- The coexistence of:
  - An **internal worker mode** (service role, no JWT), and
  - An **external/user mode** (manual JWT handling)  
  makes the functions harder to reason about and debug.

- Supabase is evolving away from “you hand‑parse JWTs and feed them back into
`auth.getUser` everywhere” and toward:
  - **Client** attaches `Authorization` header.
  - **Edge function** treats it as opaque and relies on RLS / policies,
    not low‑level JWT code.

The current external path is very much the “old school” explicit JWT style.

### 2.2 Features we don’t have yet

- There is **no current user‑initiated processing endpoint** that needs this
external path.
- Keeping speculative infrastructure “for later” has already caused confusion
around:
  - Why JWT errors are appearing in worker logs.
  - What “external mode” is supposed to do.

### 2.3 Risk surface

- Having a partially implemented external mode increases the risk that:
  - Someone wires it up incorrectly later (e.g. without proper RLS/policies).
  - Future debugging is harder because there is dead or confusing code.

---

## 3. Decision

**We will keep the external “user mode” but modernize it, instead of removing it.**

Concretely:

- We retain **two call modes** for the processors:
  - **Internal worker mode** (current behavior, triggered by dispatcher):
    - Uses `SUPABASE_SERVICE_ROLE_KEY`.
    - Does not depend on user identity or JWT.
  - **External user mode** (future‑facing, for possible user‑initiated flows):
    - Treats the `Authorization` header as an **opaque bearer token**.
    - Uses a Supabase client with the **anon key**, forwarding the incoming
      `Authorization` header.
    - Relies on **RLS policies** (`auth.uid()`) to enforce per‑user access,
      instead of manually parsing JWTs or calling `auth.getUser`.

We will **remove explicit JWT parsing and `auth.getUser` calls** from the
external path and replace them with this RLS‑centric, opaque‑Authorization
pattern. This keeps the door open for future user‑initiated processing (e.g.
“Retry processing”) without carrying forward the legacy JWT‑centric auth style.

---

## 4. Target State (Auth Model for Memory Processing)

### 4.1 Dispatcher

- **Caller:** database trigger / function hook / scheduled function.
- **Auth mechanism:**
  - Platform: `verify_jwt = false` (configured in `supabase/config.toml`).
  - Code: uses `SUPABASE_SERVICE_ROLE_KEY` to create a `supabase-js` client.
- **Responsibility:**
  - Claim jobs from `memory_processing_status` (state `scheduled`).
  - Call `process-*` functions with an internal header
    (e.g. `X-Internal-Trigger: true`).

### 4.2 Processors (`process-moment`, `process-memento`, `process-story`)

These functions support **two caller types**, but with clearly separated auth
behavior:

- **Internal worker callers** (dispatcher, other trusted backends):
  - **Platform:** `verify_jwt = false`.
  - **Code:**
    - Detect internal header (e.g. `X-Internal-Trigger: true`).
    - Use `SUPABASE_SERVICE_ROLE_KEY` for all DB access.
    - Ignore any `Authorization` token.
  - **Behavior:**
    - Operate on `memories` / `memory_processing_status` based on `memoryId`
      only.
    - No user concept; purely backend job processing.

- **External user callers** (potential future app flows):
  - **Platform:** may use `verify_jwt = true` or equivalent Supabase‑level
    token validation.
  - **Code:**
    - Do **not** parse JWTs or call `auth.getUser` directly.
    - Create a Supabase client with the **anon key**.
    - Forward the incoming `Authorization` header into the client’s global
      headers (so that RLS sees the user).
  - **Behavior:**
    - Rely on RLS policies (e.g. `auth.uid() = memories.user_id`) to ensure
      the caller can only operate on their own memories.
    - Queries should not manually inject `user_id` from parsed tokens; they
      simply query by `memoryId` and let policies decide access.

### 4.3 Client‑side responsibilities

- The Flutter app:
  - Creates/updates `memories`.
  - Inserts `memory_processing_status` rows (`state = 'scheduled'`) as needed.
  - Never calls `process-*` directly.
  - Reads status from `memory_processing_status` to drive UI badges
    (“Scheduled for processing”, “Processing”, etc.).

All user‑scoped access control continues to be enforced on regular client
queries to Supabase via **RLS** and standard Supabase client usage, not inside
the workers.

---

## 5. Implementation Plan (For Future Work)

> **Note:** This is a TODO list for a future code change. No code has been
> modified as part of this troubleshooting doc.

### 5.1 Modernize external user mode to RLS‑centric pattern

For each of:

- `supabase/functions/process-moment/index.ts`
- `supabase/functions/process-memento/index.ts`
- `supabase/functions/process-story/index.ts`

Do the following *in a single, cohesive change*:

1. **Refine internal vs external branching (keep both):**
   - Keep a single entrypoint, but:
     - Internal calls are identified via `X-Internal-Trigger` (or similar).
     - External calls are everything else.
   - Ensure internal calls:
     - Use `SUPABASE_SERVICE_ROLE_KEY`.
     - Ignore `Authorization`.
   - Ensure external calls:
     - Do *not* inspect/parse JWT payloads.
     - Treat `Authorization` as an opaque bearer value.

2. **Standardize DB clients for each mode:**
   - Internal mode:
     - Create `supabase-js` client with `SUPABASE_SERVICE_ROLE_KEY`.
     - Use it for all worker‑style queries/updates.
   - External mode:
     - Create `supabase-js` client with `SUPABASE_ANON_KEY`.
     - Forward incoming `Authorization` header into the client’s global
       headers so RLS sees the authenticated user.

3. **Remove explicit `auth.getUser` and manual `user_id` filters:**
   - Delete calls to `supabaseClient.auth.getUser(token)` in processors.
   - Remove any `.eq("user_id", user.id)` filters that rely on parsed tokens.
   - For external mode, queries should typically be:
     - `.from("memories").select(...).eq("id", requestBody.memoryId)`  
       with RLS handling whether the caller is allowed to see that row.

4. **Keep input validation and type checks:**
   - Preserve checks like:
     - “This is a moment/memento/story”
     - “`input_text` is non‑empty / has meaningful content”
   - These are still important for robustness and good error messages.

### 5.2 Confirm Supabase function config

In `supabase/config.toml`, verify (and, if needed, update) that:

- `dispatch-memory-processing`, `process-moment`, `process-memento`,
  `process-story` all have:
  - `verify_jwt = false`

After changes, deploy via:

- `supabase functions deploy dispatch-memory-processing`
- `supabase functions deploy process-moment`
- `supabase functions deploy process-memento`
- `supabase functions deploy process-story`

### 5.3 Validate behavior end‑to‑end

After implementation and deployment:

1. **Create new memories with input text** from the app:
   - Confirm:
     - `memories` rows are created.
     - `memory_processing_status` rows appear with `state = 'scheduled'`.

2. **Verify dispatcher + processors run without auth noise:**
   - In Supabase logs:
     - `dispatch-memory-processing` should run without any JWT‑related
       errors/warnings.
     - `process-*` functions should run successfully or fail only with
       *domain* errors (LLM errors, DB issues), not auth issues.

3. **Check status transitions:**
   - In `memory_processing_status`, states for new jobs should flow:
     - `scheduled` → `processing` → `complete` (or → `failed` on real errors).
   - Timeline UI should:
     - Show “Scheduled for processing” / “Processing” chips appropriately.
     - Not get stuck in “Scheduled” because jobs fail on auth.

4. **Run regression checks on RLS / client data access:**
   - Confirm that regular app usage (viewing, listing, editing memories)
     remains governed by existing RLS policies and is unaffected by these
     worker changes.

---

## 6. Future: If/When We Expose User‑Initiated Processing

With the modernized external mode in place, if we later add features like a
“Retry processing” button:

- The app can safely call the same `process-*` functions directly:
  - The Supabase client will attach `Authorization` for the logged‑in user.
  - The processor’s external path will:
    - Use the anon key + forwarded `Authorization`.
    - Rely on RLS to enforce that the caller can only affect their own
      `memories` rows.
- Alternatively, we can still create a thin user‑facing wrapper function that:
  - Validates additional business rules (limits, quotas, etc.).
  - Enqueues/updates `memory_processing_status`.
  - Relies on the same internal worker mode for actual processing.

Either way, the core principles remain:

- **Internal mode:** service‑role workers, no JWT, no user.
- **External mode:** opaque `Authorization`, RLS‑driven per‑user access,
  no manual JWT parsing.



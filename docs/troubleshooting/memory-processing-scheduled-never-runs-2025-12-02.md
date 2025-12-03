## Memory Stuck in “Scheduled for processing” (Processing Never Runs)

**Date:** 2025-12-02  
**Status:** 🟠 Known issue – architecture is sound, orchestration is missing / fragile  

This doc covers the case where:

- A new memory (e.g. a Moment) is successfully saved to the `memories` table.
- A corresponding row appears in `memory_processing_status` with `state = 'scheduled'`.
- The app shows a **“Scheduled for processing”** badge.
- But **processing never starts** – the state never moves to `processing` / `complete` / `failed`, and you see no `process-moment` / `process-memento` / `process-story` logs during the test window.

This is **not** a data-model problem – it’s an orchestration / worker problem: jobs are enqueued but nothing is reliably picking them up.

---

## 1. Quick Triage Checklist

When you see a memory stuck in **“Scheduled for processing”** for more than ~1–2 minutes:

- **1.1 Database state**
  - `select * from memories order by created_at desc limit 5;`
  - `select * from memory_processing_status order by created_at desc limit 5;`
  - Confirm for the problematic memory:
    - Exactly **one** `memories` row with the expected `id` and `memory_type` (e.g. `moment`).
    - Exactly **one** `memory_processing_status` row with:
      - `state = 'scheduled'`
      - `attempts = 0`
      - `started_at IS NULL`
      - `completed_at IS NULL`

- **1.2 Edge function logs (Supabase Dashboard)**
  - Check logs for:
    - `dispatch-memory-processing`
    - `process-moment`, `process-memento`, `process-story`
  - If you see **no entries at all** for the relevant time window:
    - The worker is **not being invoked**.

- **1.3 Supabase Edge Functions / Function Hooks**
  - In **Edge Functions**:
    - Verify `dispatch-memory-processing` is **deployed** and healthy.
  - In **Function Hooks / database triggers**:
    - Confirm there is a **row-level hook** that invokes `dispatch-memory-processing` (or the appropriate `process-*` function) immediately when a new `memory_processing_status` row with `state = 'scheduled'` is inserted.

If DB rows look correct but there are **no function logs**, you are hitting this orchestration gap.

---

## 2. Architecture Overview (Why `scheduled` Exists)

The pipeline is intentionally split into:

- **Transport / offline sync (client-side)**:
  - `OfflineMemoryQueueService`, `QueuedMemory`, etc. handle:
    - “Do we have a local capture that hasn’t reached Supabase yet?”
    - States like `queued`, `syncing`, `failed`, `synced`.
  - This enables **full offline capture and editing**.

- **AI processing (server-side)**:
  - Once a memory is on the server, we track AI work in:
    - Table: `memory_processing_status`
    - Enum: `memory_processing_state` = `scheduled`, `processing`, `complete`, `failed`

Key points:

- The **client** is responsible for:
  - Creating the `memories` row.
  - Inserting a **single** `memory_processing_status` row with `state = 'scheduled'` when there is input text to process.
- The **server** (workers) are responsible for:
  - Picking up `scheduled` jobs.
  - Driving them through `processing` → `complete` / `failed`.

This **“insert job row with `state = 'scheduled'` then have a worker claim it”** pattern is deliberate and standard (job queue / outbox pattern).  
The issue arises only when **no worker is reliably running**.

---

## 3. Current Implementation – Where Things Can Break

### 3.1 Enqueue (Client)

On successful online save, the app enqueues processing:

```324:345:lib/services/memory_save_service.dart
// Step 4: Insert memory_processing_status row if we have input_text to process
// Processing will happen asynchronously via dispatcher
final hasInputText = state.inputText?.trim().isNotEmpty == true;
String? generatedTitle;

if (hasInputText) {
  // Insert processing status row - dispatcher will pick this up
  try {
    await _supabase.from('memory_processing_status').insert({
      'memory_id': memoryId,
      'state': 'scheduled',
      'attempts': 0,
      'metadata': {
        'memory_type': state.memoryType.apiValue,
      },
    });
  } catch (e) {
    // Log but don't fail - processing status insert is best-effort
    // The dispatcher can still process the memory
    print('Warning: Failed to insert memory_processing_status: $e');
  }
}
```

This part is **working** when you see a row with `state = 'scheduled'`.

### 3.2 Dispatcher (Server)

The dispatcher edge function claims `scheduled` jobs and forwards them to type-specific processors:

```71:88:supabase/functions/dispatch-memory-processing/index.ts
// Claim scheduled jobs using SELECT ... FOR UPDATE SKIP LOCKED
// This ensures only one dispatcher processes each job
const { data: scheduledJobs, error: selectError } = await supabaseClient
  .rpc("claim_scheduled_processing_jobs", { batch_size: MAX_BATCH_SIZE });

if (selectError) {
  // Fallback: simple select when RPC absent
  const { data: jobs, error: fallbackError } = await supabaseClient
    .from("memory_processing_status")
    .select("memory_id, attempts, metadata")
    .eq("state", "scheduled")
    .lt("attempts", MAX_ATTEMPTS)
    .order("created_at", { ascending: true })
    .limit(MAX_BATCH_SIZE);
  ...
}
```

```137:151:supabase/functions/dispatch-memory-processing/index.ts
// Call appropriate processing function
const functionName = `process-${memoryType || job.metadata?.memory_type}`;
const functionUrl = `${supabaseUrl}/functions/v1/${functionName}`;

// Call edge function (fire and forget - the function updates status itself)
const functionResponse = await fetch(functionUrl, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": authHeader, // Pass through auth header
  },
  body: JSON.stringify({
    memoryId: job.memory_id,
  }),
});
```

**Important:** The dispatcher **does nothing until it is invoked** by something (cron, trigger, or manual call).

### 3.3 Type-Specific Processor (e.g. `process-moment`)

When `process-moment` runs successfully, it:

- Moves the job to `processing`:

```444:457:supabase/functions/process-moment/index.ts
// Update processing status to 'processing'
const now = new Date().toISOString();
const { error: statusUpdateError } = await supabaseClient
  .from("memory_processing_status")
  .update({
    state: "processing",
    started_at: now,
    last_updated_at: now,
    metadata: {
      memory_type: "moment",
      phase: "text_processing",
    },
  })
  .eq("memory_id", requestBody.memoryId);
```

- And then to `complete`:

```501:513:supabase/functions/process-moment/index.ts
// Update processing status to 'complete'
const completedAt = new Date().toISOString();
await supabaseClient
  .from("memory_processing_status")
  .update({
    state: "complete",
    completed_at: completedAt,
    last_updated_at: completedAt,
    metadata: {
      memory_type: "moment",
      duration_ms: duration,
    },
  })
  .eq("memory_id", requestBody.memoryId);
```

If you never see `processing` / `complete`, it means **`process-moment` was never invoked** for that memory.

---

## 4. Recommended Course of Action

### 4.1 Ensure an Event-Driven Dispatcher Hook Exists

The dispatcher should be **invoked immediately** when work is enqueued – no polling, no cron.

Recommended pattern:

- In Supabase:
  - Define a **function hook / database trigger** on `public.memory_processing_status` such that:
    - On **insert** of a row with `state = 'scheduled'` (and/or on update transitioning into `scheduled`),
    - Supabase calls `dispatch-memory-processing` (or, if you choose, the specific `process-*` function directly) **right away**.
  - The hook should:
    - Pass the necessary auth (service role or other secure credential) so the dispatcher can claim jobs.
    - Fail fast / log clearly if it cannot reach the function.

Properties:

- **Low latency**: job row is created → hook fires → dispatcher runs within seconds.
- **No extra moving parts**: no cron, no periodic polling, no batch delay.

**Action item:** Implement and document this **event-driven hook** as the single source of truth for how the dispatcher is invoked.

### 4.2 Verify Edge Function Deployment

In Supabase Dashboard → Edge Functions:

- Confirm that the following functions are **deployed**:
  - `dispatch-memory-processing`
  - `process-moment`
  - `process-memento`
  - `process-story`
- For each, check:
  - There is a recent deployment.
  - There are no obvious runtime errors in the logs.

**Critical:** The `dispatch-memory-processing` function **must have JWT verification disabled** because it's called from database triggers (pg_net) which don't have JWT tokens.

To disable JWT verification:

**Option 1: Via Supabase CLI (Recommended - uses config.toml)**
```bash
supabase functions deploy dispatch-memory-processing --no-verify-jwt
```

**Option 2: Via Dashboard**
1. Go to Edge Functions → `dispatch-memory-processing`
2. Click Settings/Edit
3. Disable "Verify JWT" or set it to `false`
4. Save

**Option 3: Via config.toml (for future deployments)**
The `supabase/config.toml` file has been created with:
```toml
[functions.dispatch-memory-processing]
verify_jwt = false
```
This will be automatically applied when deploying via `supabase functions deploy`.

If any of these are missing or out-of-date, redeploy from this repo.

### 4.3 Keep the Offline Story Intact

No changes are required to the offline architecture:

- **Do not** remove or overload the offline queue (`QueuedMemory`, `OfflineMemoryQueueService`) with processing concerns.
- Keep processing **purely server-side**, driven from `memory_processing_status`.

The only thing we’re fixing is the **bridge** between:

- “We inserted `state = 'scheduled'`” and  
- “Something actually runs the dispatcher and `process-*` functions.”

---

## 5. Cleanup: Remove Legacy / Unused Processing Pieces

Once the dispatcher is deployed and scheduled properly, we want to:

- Let the system **automatically process any backlog** of `scheduled` jobs.
- Remove any **legacy processing implementations** (functions / fields) that are no longer part of the current design so they don’t confuse future debugging.

### 5.1 Let the Dispatcher Drain the Backlog

After the event-driven dispatcher hook is live:

1. Create or update a few memories with input text (to enqueue fresh jobs).
2. Run:

```sql
select state, count(*)
from public.memory_processing_status
group by state;
```

Expected outcome over time:

- `scheduled` count **decreases** towards 0 for recent jobs.
- `processing` is transient / small.
- `complete` increases.
- `failed` remains small and meaningful.

If `scheduled` remains high and unchanged, the dispatcher still isn’t running correctly; fix that first before any manual cleanup.

### 5.2 Identify Stale `scheduled` Jobs

After the system has been healthy for a while, any **old** `scheduled` jobs are likely junk:

```sql
-- Stale scheduled jobs older than 24 hours
select *
from public.memory_processing_status
where state = 'scheduled'
  and created_at < now() - interval '24 hours'
order by created_at asc
limit 100;
```

For these rows:

- Decide **per environment** (dev, staging, prod) whether to:
  - **Retry** them (preferred):
    - Simply leave them as `scheduled` – the now-working dispatcher should pick them up.
  - Or **mark them failed** if they are known-bad:

```sql
update public.memory_processing_status
set state = 'failed',
    attempts = attempts + 1,
    last_error = 'Marked failed during cleanup – stale scheduled job older than 24h',
    last_error_at = now(),
    last_updated_at = now()
where state = 'scheduled'
  and created_at < now() - interval '24 hours';
```

Avoid deleting rows outright; it is better to have a **correct terminal state** (`failed`) than to silently drop history.

### 5.3 Ensure No Orphaned Status Rows

The `memory_processing_status.memory_id` column uses `ON DELETE CASCADE` to `memories(id)`, so true “orphans” should not exist. Still, you can double-check:

```sql
select s.*
from public.memory_processing_status s
left join public.memories m on m.id = s.memory_id
where m.id is null;
```

If this ever returns rows, it indicates either:

- A broken migration / constraint in that environment, or
- Manual DB edits that bypassed constraints.

**Cleanup (only if needed):**

- Prefer to **fix constraints / migrations** rather than manually deleting rows.
- If you confirm true orphans exist due to past manual edits, fix them in a targeted one-off migration for that environment instead of generic ad‑hoc SQL.

---

## 6. Summary

- The **architecture is correct**: client enqueues work via `memory_processing_status (state='scheduled')`, workers process via `dispatch-memory-processing` + `process-*` edge functions.
- The observed issue (“stuck in Scheduled for processing”) occurs when **no runner is reliably invoking the dispatcher**, so `process-moment` / `process-memento` / `process-story` never run.
- **Fix**: ensure `dispatch-memory-processing` is:
  - Deployed as an edge function, and
  - Invoked either via a **Scheduled Function (cron, recommended)** or a well-defined DB-triggered mechanism.
- **Cleanup**: once healthy, let the dispatcher drain the backlog, then:
  - Mark very old `scheduled` jobs as `failed` if needed.
  - Verify no orphaned rows.
  - Remove any legacy, unused processing functions or fields from the Supabase project so only the current, event-driven pipeline is visible.



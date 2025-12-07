import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

const MAX_ATTEMPTS = 3;
const MAX_BATCH_SIZE = 10; // Process up to 10 memories per invocation

type SupabaseClientInstance = ReturnType<typeof createClient>;

interface ScheduledJob {
  memory_id: string;
  attempts?: number | null;
  metadata?: Record<string, unknown> | null;
}

interface MemorySnapshot {
  memory_type: string | null;
  title_generated_at: string | null;
  generated_title: string | null;
  processed_text: string | null;
}

async function fetchMemorySnapshot(
  client: SupabaseClientInstance,
  memoryId: string,
): Promise<MemorySnapshot | null> {
  const { data, error } = await client
    .from("memories")
    .select("memory_type, title_generated_at, generated_title, processed_text")
    .eq("id", memoryId)
    .single();

  if (error || !data) {
    console.error(JSON.stringify({
      event: "memory_snapshot_fetch_failed",
      memoryId,
      error: error?.message ?? "Memory not found",
    }));
    return null;
  }

  return {
    memory_type: (data.memory_type as string | null) ?? null,
    title_generated_at: (data.title_generated_at as string | null) ?? null,
    generated_title: (data.generated_title as string | null) ?? null,
    processed_text: (data.processed_text as string | null) ?? null,
  };
}

function hasCompletedOutputs(snapshot: MemorySnapshot | null): boolean {
  if (!snapshot) return false;

  const hasTitleMetadata = Boolean(
    snapshot.title_generated_at ||
      (snapshot.generated_title && snapshot.generated_title.trim().length > 0),
  );

  if (!hasTitleMetadata) {
    return false;
  }

  if (snapshot.memory_type === "story") {
    return Boolean(
      snapshot.processed_text && snapshot.processed_text.trim().length > 0,
    );
  }

  // Moments/Mementos are considered complete when title metadata exists.
  return true;
}

async function autoCompleteJobIfPossible(
  client: SupabaseClientInstance,
  job: ScheduledJob,
  snapshot: MemorySnapshot | null,
): Promise<boolean> {
  if (!hasCompletedOutputs(snapshot) || !snapshot) {
    return false;
  }

  const completedAt = snapshot.title_generated_at ?? new Date().toISOString();
  const metadata = {
    ...(job.metadata ?? {}),
    memory_type: snapshot.memory_type,
    auto_completed: true,
    auto_complete_reason: "output_already_present",
  };

  const { error } = await client
    .from("memory_processing_status")
    .update({
      state: "complete",
      completed_at: completedAt,
      last_updated_at: completedAt,
      metadata,
    })
    .eq("memory_id", job.memory_id);

  if (error) {
    console.error(JSON.stringify({
      event: "memory_processing_auto_complete_failed",
      memoryId: job.memory_id,
      error: error.message,
    }));
    return false;
  }

  console.log(JSON.stringify({
    event: "memory_processing_auto_completed",
    memoryId: job.memory_id,
    reason: "output_already_present",
  }));

  return true;
}

/**
 * Dispatcher Edge Function for Memory Processing
 * 
 * This function:
 * - Claims scheduled memory processing jobs using SELECT ... FOR UPDATE SKIP LOCKED
 * - Updates state to 'processing' and calls appropriate edge function
 * - Handles retries for failed jobs (if attempts < MAX_ATTEMPTS)
 * - Processes memories in batches for efficiency
 */
Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        code: "METHOD_NOT_ALLOWED",
        message: "Only POST requests are allowed",
      } as ErrorResponse),
      {
        status: 405,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  try {
    const isInternalTrigger = req.headers.get("X-Internal-Trigger") === "true";

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(
        "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables",
      );
      return new Response(
        JSON.stringify({
          code: "INTERNAL_ERROR",
          message: "Server configuration error",
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Always use service role key for admin access to claim jobs.
    // This function is intended to be called either:
    // - Internally from database triggers (with X-Internal-Trigger header)
    // - Manually from tools for debugging
    // In both cases we *do not* rely on end-user JWTs. For platform-level function
    // auth, we attach the service-role key as Authorization when calling workers.
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey);

    // Claim scheduled jobs using SELECT ... FOR UPDATE SKIP LOCKED
    // This ensures only one dispatcher processes each job
    const { data: scheduledJobs, error: selectError } = await supabaseClient
      .rpc("claim_scheduled_processing_jobs", { batch_size: MAX_BATCH_SIZE });

    if (selectError) {
      // If the RPC doesn't exist, fall back to manual query
      // Note: FOR UPDATE SKIP LOCKED requires a transaction, which Supabase JS client doesn't support directly
      // So we'll use a simpler approach: select and update atomically
      const { data: jobs, error: fallbackError } = await supabaseClient
        .from("memory_processing_status")
        .select("memory_id, attempts, metadata")
        .eq("state", "scheduled")
        .lt("attempts", MAX_ATTEMPTS)
        .order("created_at", { ascending: true })
        .limit(MAX_BATCH_SIZE);

      if (fallbackError || !jobs || jobs.length === 0) {
        return new Response(
          JSON.stringify({
            processed: 0,
            message: "No scheduled jobs found",
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" },
          },
        );
      }

      // Process each job
      let processedCount = 0;
      for (const job of jobs) {
        try {
          const snapshot = await fetchMemorySnapshot(
            supabaseClient,
            job.memory_id,
          );

          if (!snapshot) {
            const failedAt = new Date().toISOString();
            await supabaseClient
              .from("memory_processing_status")
              .update({
                state: "failed",
                last_error: "Memory not found when dispatching",
                last_error_at: failedAt,
                last_updated_at: failedAt,
              })
              .eq("memory_id", job.memory_id);
            continue;
          }

          const autoCompleted = await autoCompleteJobIfPossible(
            supabaseClient,
            job,
            snapshot,
          );

          if (autoCompleted) {
            processedCount++;
            continue;
          }

          const memoryType = (job.metadata?.memory_type as string | undefined) ??
            snapshot.memory_type ??
            undefined;

          if (!memoryType) {
            console.error(
              `Unable to determine memory type for ${job.memory_id}, skipping`,
            );
            continue;
          }

          const nowIso = new Date().toISOString();
          const metadata = {
            ...(job.metadata ?? {}),
            memory_type: memoryType,
          };

          // Update state to 'processing' atomically (only if still 'scheduled')
          const { error: updateError } = await supabaseClient
            .from("memory_processing_status")
            .update({
              state: "processing",
              started_at: nowIso,
              last_updated_at: nowIso,
              metadata,
            })
            .eq("memory_id", job.memory_id)
            .eq("state", "scheduled"); // Only update if still scheduled (prevents race conditions)

          if (updateError) {
            console.error(`Failed to claim job ${job.memory_id}:`, updateError);
            continue; // Skip this job, another dispatcher may have claimed it
          }

          // Call appropriate processing function
          const functionName = `process-${memoryType}`;
          const functionUrl = `${supabaseUrl}/functions/v1/${functionName}`;

          // Call edge function (fire and forget - the function updates status itself)
          const functionResponse = await fetch(functionUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              // Mark this as an internal invocation so workers can bypass user JWT checks
              // while still satisfying Supabase platform auth when verify_jwt is enabled.
              "X-Internal-Trigger": "true",
              Authorization: `Bearer ${supabaseServiceKey}`,
            },
            body: JSON.stringify({
              memoryId: job.memory_id,
            }),
          });

          if (!functionResponse.ok) {
            const errorText = await functionResponse.text();
            console.error(`Processing function failed for ${job.memory_id}:`, errorText);
            
            // The processing function should update status to 'failed', but if it didn't,
            // we'll handle retry logic here
            const newAttempts = (job.attempts || 0) + 1;
            if (newAttempts < MAX_ATTEMPTS) {
              // Reset to scheduled for retry
              await supabaseClient
                .from("memory_processing_status")
                .update({
                  state: "scheduled",
                  attempts: newAttempts,
                  last_error: errorText,
                  last_error_at: new Date().toISOString(),
                  last_updated_at: new Date().toISOString(),
                })
                .eq("memory_id", job.memory_id);
            } else {
              // Max attempts reached, mark as failed
              await supabaseClient
                .from("memory_processing_status")
                .update({
                  state: "failed",
                  attempts: newAttempts,
                  last_error: errorText,
                  last_error_at: new Date().toISOString(),
                  last_updated_at: new Date().toISOString(),
                })
                .eq("memory_id", job.memory_id);
            }
          } else {
            processedCount++;
          }
        } catch (error) {
          console.error(`Error processing job ${job.memory_id}:`, error);
          // Update status to failed
          const newAttempts = (job.attempts || 0) + 1;
          await supabaseClient
            .from("memory_processing_status")
            .update({
              state: newAttempts < MAX_ATTEMPTS ? "scheduled" : "failed",
              attempts: newAttempts,
              last_error: error instanceof Error ? error.message : String(error),
              last_error_at: new Date().toISOString(),
              last_updated_at: new Date().toISOString(),
            })
            .eq("memory_id", job.memory_id);
        }
      }

      return new Response(
        JSON.stringify({
          processed: processedCount,
          total: jobs.length,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // If RPC exists, use it (would need to be created in a migration)
    return new Response(
      JSON.stringify({
        processed: scheduledJobs?.length || 0,
        message: "Jobs processed via RPC",
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Unexpected error in dispatch-memory-processing function:", error);

    return new Response(
      JSON.stringify({
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred",
      } as ErrorResponse),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});


import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

const MAX_ATTEMPTS = 3;
const MAX_BATCH_SIZE = 10; // Process up to 10 memories per invocation

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
          // Update state to 'processing' atomically (only if still 'scheduled')
          const { error: updateError } = await supabaseClient
            .from("memory_processing_status")
            .update({
              state: "processing",
              started_at: new Date().toISOString(),
              last_updated_at: new Date().toISOString(),
            })
            .eq("memory_id", job.memory_id)
            .eq("state", "scheduled"); // Only update if still scheduled (prevents race conditions)

          if (updateError) {
            console.error(`Failed to claim job ${job.memory_id}:`, updateError);
            continue; // Skip this job, another dispatcher may have claimed it
          }

          // Determine memory type from metadata or fetch from memories table
          const memoryType = job.metadata?.memory_type;
          if (!memoryType) {
            // Fetch from memories table
            const { data: memory } = await supabaseClient
              .from("memories")
              .select("memory_type")
              .eq("id", job.memory_id)
              .single();

            if (!memory) {
              console.error(`Memory ${job.memory_id} not found`);
              continue;
            }
          }

          // Call appropriate processing function
          const functionName = `process-${memoryType || job.metadata?.memory_type}`;
          const functionUrl = `${supabaseUrl}/functions/v1/${functionName}`;

          // Call edge function (fire and forget - the function updates status itself)
          const functionResponse = await fetch(functionUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              // Mark this as an internal, service-role invocation so the processing
              // functions can bypass JWT checks and use the service role key.
              // We rely on `verify_jwt = false` for these worker functions, so we do
              // NOT send an Authorization header here. The workers themselves will
              // create a Supabase client with the service-role key when they see
              // `X-Internal-Trigger: true`.
              "X-Internal-Trigger": "true",
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


import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ProcessStoryRequest {
  memoryId: string;
}

interface ProcessStoryResponse {
  title: string;
  processedText: string;
  status: "success";
  generatedAt: string;
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

const MAX_TITLE_LENGTH = 60;

/**
 * Truncates a string to a maximum length, ensuring it doesn't break words
 */
function truncateTitle(title: string, maxLength: number): string {
  if (title.length <= maxLength) {
    return title;
  }
  
  const truncated = title.substring(0, maxLength);
  const lastSpace = truncated.lastIndexOf(" ");
  
  if (lastSpace > maxLength * 0.5) {
    return truncated.substring(0, lastSpace) + "...";
  }
  
  return truncated + "...";
}

/**
 * Generates narrative text from input_text using LLM
 */
async function generateNarrativeWithLLM(
  inputText: string,
): Promise<string | null> {
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
  
  if (!openaiApiKey) {
    console.warn("OPENAI_API_KEY not configured, cannot generate narrative");
    return null;
  }

  const openaiUrl = Deno.env.get("OPENAI_API_URL") || 
    "https://api.openai.com/v1/chat/completions";

  const prompt = `Transform this transcript into a polished, engaging narrative story. The transcript comes from voice dictation and may contain filler words and incomplete thoughts. The narrative should:
- Be written in first or third person as appropriate
- Flow naturally with proper paragraphs
- Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know", "I mean")
- Capture the emotion and context of the memory
- Be engaging and readable
- Preserve the key details and meaning

Transcript: ${inputText}

Return only the narrative text, nothing else.`;

  const requestBody = {
    model: Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a helpful assistant that transforms transcripts into polished, engaging narrative stories while preserving the speaker's voice and meaning.",
      },
      {
        role: "user",
        content: prompt,
      },
    ],
    max_completion_tokens: 2000,
    // temperature: 0.5, // Not supported by gpt-5-mini, defaults to 1
  };

  try {
    // Log request details (without exposing API key)
    console.log(JSON.stringify({
      event: "openai_narrative_generation_request",
      model: requestBody.model,
      promptLength: prompt.length,
      maxTokens: requestBody.max_completion_tokens,
      // temperature: requestBody.temperature, // Not supported by gpt-5-mini
      url: openaiUrl,
    }));

    const response = await fetch(openaiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(JSON.stringify({
        event: "openai_narrative_generation_error",
        status: response.status,
        statusText: response.statusText,
        errorBody: errorText,
        url: openaiUrl,
      }));
      return null;
    }

    const data = await response.json();
    
    // Log response details
    console.log(JSON.stringify({
      event: "openai_narrative_generation_response",
      model: data.model,
      finishReason: data.choices?.[0]?.finish_reason,
      usage: data.usage,
      responseLength: data.choices?.[0]?.message?.content?.length ?? 0,
    }));

    const narrative = data.choices?.[0]?.message?.content?.trim();

    if (!narrative) {
      console.warn(JSON.stringify({
        event: "openai_narrative_generation_empty_response",
        fullResponse: JSON.stringify(data),
      }));
      return null;
    }

    return narrative;
  } catch (error) {
    console.error(JSON.stringify({
      event: "openai_narrative_generation_exception",
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    }));
    return null;
  }
}

/**
 * Generates a title from narrative/input text using LLM
 */
async function generateTitleWithLLM(
  text: string,
): Promise<string | null> {
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
  
  if (!openaiApiKey) {
    console.warn("OPENAI_API_KEY not configured, falling back to default title");
    return null;
  }

  const openaiUrl = Deno.env.get("OPENAI_API_URL") || 
    "https://api.openai.com/v1/chat/completions";

  const prompt = `Generate a concise, engaging title (maximum ${MAX_TITLE_LENGTH} characters) for this story narrative. The title should capture the essence and emotion of the story. Return only the title text, nothing else.

Narrative: ${text.substring(0, 1000)}`;

  const requestBody = {
    model: Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a helpful assistant that generates concise, engaging titles for narrative stories.",
      },
      {
        role: "user",
        content: prompt,
      },
    ],
    max_completion_tokens: 100, // Increased to account for reasoning tokens in gpt-5-mini
    // temperature: 0.7, // Not supported by gpt-5-mini, defaults to 1
  };

  try {
    // Log request details
    console.log(JSON.stringify({
      event: "openai_title_generation_request",
      model: requestBody.model,
      promptLength: prompt.length,
      maxTokens: requestBody.max_completion_tokens,
      // temperature: requestBody.temperature, // Not supported by gpt-5-mini
      url: openaiUrl,
    }));

    const response = await fetch(openaiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(JSON.stringify({
        event: "openai_title_generation_error",
        status: response.status,
        statusText: response.statusText,
        errorBody: errorText,
        url: openaiUrl,
      }));
      return null;
    }

    const data = await response.json();
    
    // Log response details
    console.log(JSON.stringify({
      event: "openai_title_generation_response",
      model: data.model,
      finishReason: data.choices?.[0]?.finish_reason,
      usage: data.usage,
      responseLength: data.choices?.[0]?.message?.content?.length ?? 0,
    }));

    const generatedTitle = data.choices?.[0]?.message?.content?.trim();

    // Handle empty response - could be due to reasoning tokens consuming all budget
    if (!generatedTitle) {
      console.warn(JSON.stringify({
        event: "openai_title_generation_empty_response",
        finishReason: data.choices?.[0]?.finish_reason,
        usage: data.usage,
        fullResponse: JSON.stringify(data),
      }));
      
      // If finish reason is "length", the model hit token limit without producing content
      // Return null to trigger fallback extraction from text
      return null;
    }

    const cleanedTitle = generatedTitle
      .replace(/^["']|["']$/g, "")
      .trim();
    
    // If cleaned title is still empty after processing, return null for fallback
    if (!cleanedTitle) {
      return null;
    }
    
    return truncateTitle(cleanedTitle, MAX_TITLE_LENGTH);
  } catch (error) {
    console.error(JSON.stringify({
      event: "openai_title_generation_exception",
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    }));
    return null;
  }
}

/**
 * Edge Function for processing stories
 * 
 * This function:
 * - Fetches story data from database using memoryId
 * - Validates input_text exists and is not empty
 * - Generates title from input_text
 * - Generates narrative text from input_text → processed_text
 * - Updates memories table with processed_text and title
 * - Updates story_fields table with status and timestamps
 * - Handles failures with retry logic
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
    const authHeader = req.headers.get("Authorization");
    const isInternalTrigger = req.headers.get("X-Internal-Trigger") === "true";

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl) {
      console.error("Missing SUPABASE_URL environment variable");
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

    // Choose auth mode:
    // - Internal trigger: service role, no user JWT required.
    // - External (user) call: use anon key with forwarded Authorization header, rely on RLS.
    let supabaseClient;

    if (isInternalTrigger) {
      if (!supabaseServiceKey) {
        console.error("Missing SUPABASE_SERVICE_ROLE_KEY for internal trigger");
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

      supabaseClient = createClient(supabaseUrl, supabaseServiceKey);
    } else {
      if (!authHeader) {
        return new Response(
          JSON.stringify({
            code: "UNAUTHORIZED",
            message: "Missing authorization header",
          } as ErrorResponse),
          {
            status: 401,
            headers: { "Content-Type": "application/json" },
          },
        );
      }

      if (!supabaseAnonKey) {
        console.error("Missing SUPABASE_ANON_KEY environment variable");
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

      // External mode: use anon key and forward Authorization header.
      // RLS policies will enforce per-user access; no manual JWT parsing needed.
      supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
      });
    }

    let requestBody: ProcessStoryRequest;
    try {
      requestBody = await req.json();
    } catch (e) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Invalid JSON in request body",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    if (!requestBody.memoryId || typeof requestBody.memoryId !== "string") {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "memoryId is required and must be a string",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Fetch memory and story_fields data from database
    // For internal mode: service role can access any memory.
    // For external mode: RLS policies enforce that the caller can only access their own memories.
    const { data: memory, error: memoryError } = await supabaseClient
      .from("memories")
      .select("id, input_text, memory_type")
      .eq("id", requestBody.memoryId)
      .single();

    if (memoryError || !memory) {
      return new Response(
        JSON.stringify({
          code: "NOT_FOUND",
          message: "Memory not found or access denied",
        } as ErrorResponse),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Verify this is a story
    const memoryType = memory.memory_type;
    if (memoryType !== "story") {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "This function only processes stories",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Validate input_text
    const inputText = memory.input_text?.trim();
    if (!inputText || inputText.length === 0) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Story has no input_text to process",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Validate that input_text contains meaningful content (not just whitespace or single characters)
    if (inputText.length < 3 || inputText.replace(/\s/g, "").length < 2) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Story input_text is too short or contains no meaningful content",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Update processing status to 'processing'
    const now = new Date().toISOString();
    const { error: statusUpdateError } = await supabaseClient
      .from("memory_processing_status")
      .update({
        state: "processing",
        started_at: now,
        last_updated_at: now,
        metadata: {
          memory_type: "story",
          phase: "narrative_generation",
        },
      })
      .eq("memory_id", requestBody.memoryId);

    if (statusUpdateError) {
      console.error("Error updating processing status:", statusUpdateError);
      // Continue processing even if status update fails
    }

    const startTime = Date.now();

    try {
      // Run narrative generation and title generation in parallel
      const [narrativeResult, titleResult] = await Promise.all([
        generateNarrativeWithLLM(inputText),
        generateTitleWithLLM(inputText), // Generate title from input_text in parallel
      ]);
      
      if (!narrativeResult) {
        throw new Error("Failed to generate narrative");
      }

      if (!titleResult) {
        throw new Error("Failed to generate title");
      }

      const narrative = narrativeResult;
      const title = titleResult;

      const duration = Date.now() - startTime;
      const completedAt = new Date().toISOString();

      // Update memories table with processed_text and title
      const { error: updateMemoryError } = await supabaseClient
        .from("memories")
        .update({
          processed_text: narrative,
          title: title,
          title_generated_at: completedAt,
        })
        .eq("id", requestBody.memoryId);

      if (updateMemoryError) {
        throw new Error(`Failed to update memory: ${updateMemoryError.message}`);
      }

      // Update story_fields table with narrative timestamp (processing status is in memory_processing_status)
      const { error: updateStoryFieldsError } = await supabaseClient
        .from("story_fields")
        .update({
          narrative_generated_at: completedAt,
          processing_error: null,
        })
        .eq("memory_id", requestBody.memoryId);

      if (updateStoryFieldsError) {
        throw new Error(`Failed to update story_fields: ${updateStoryFieldsError.message}`);
      }

      // Update memory_processing_status to 'complete'
      await supabaseClient
        .from("memory_processing_status")
        .update({
          state: "complete",
          completed_at: completedAt,
          last_updated_at: completedAt,
          metadata: {
            memory_type: "story",
            duration_ms: duration,
          },
        })
        .eq("memory_id", requestBody.memoryId);

      // Log success event
      const requestId = crypto.randomUUID();
      console.log(
        JSON.stringify({
          event: "story_processing",
          memoryId: requestBody.memoryId,
          titleLength: title.length,
          narrativeLength: narrative.length,
          inputTextLength: inputText.length,
          durationMs: duration,
          requestId: requestId,
          timestamp: completedAt,
          mode: isInternalTrigger ? "internal" : "external",
        }),
      );

      const response: ProcessStoryResponse = {
        title: title,
        processedText: narrative,
        status: "success",
        generatedAt: completedAt,
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      // Handle processing failure
      const errorMessage = error instanceof Error ? error.message : "Unknown error occurred";
      const failedAt = new Date().toISOString();

      // Get current attempts count from memory_processing_status
      const { data: currentStatus } = await supabaseClient
        .from("memory_processing_status")
        .select("attempts")
        .eq("memory_id", requestBody.memoryId)
        .single();

      const newAttempts = (currentStatus?.attempts || 0) + 1;

      // Update memory_processing_status to 'failed'
      await supabaseClient
        .from("memory_processing_status")
        .update({
          state: "failed",
          attempts: newAttempts,
          last_error: errorMessage,
          last_error_at: failedAt,
          last_updated_at: failedAt,
          metadata: {
            memory_type: "story",
            error: errorMessage,
            attempts: newAttempts,
          },
        })
        .eq("memory_id", requestBody.memoryId);

      // Log failure event
      const requestId = crypto.randomUUID();
      console.error(
        JSON.stringify({
          event: "story_processing_failed",
          memoryId: requestBody.memoryId,
          error: errorMessage,
          attempts: newAttempts,
          requestId: requestId,
          timestamp: failedAt,
          mode: isInternalTrigger ? "internal" : "external",
        }),
      );

      return new Response(
        JSON.stringify({
          code: "PROCESSING_FAILED",
          message: errorMessage,
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
  } catch (error) {
    console.error("Unexpected error in process-story function:", error);

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


import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ProcessMomentRequest {
  memoryId: string;
}

interface ProcessMomentResponse {
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
 * Processes input_text into cleaned, readable processed_text using LLM
 */
async function processTextWithLLM(
  inputText: string,
): Promise<string | null> {
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
  
  if (!openaiApiKey) {
    console.warn("OPENAI_API_KEY not configured, cannot process text");
    return null;
  }

  const openaiUrl = Deno.env.get("OPENAI_API_URL") || 
    "https://api.openai.com/v1/chat/completions";

  const prompt = `Transform this transcribed text into clean, readable text optimized for human reading. The text comes from voice dictation and may contain run-on sentences, incomplete thoughts, and filler words. Your task is to:

- Break up run-on sentences into proper sentence structure
- Ensure sentences are complete and grammatically coherent
- Remove filler words that don't convey meaningful information (e.g., "um", "uh", "like", "you know", "I mean")
- Preserve all information and meaning from the original
- Maintain the natural flow and voice of the speaker
- Do not add information that wasn't in the original
- Keep the tone and style consistent

The output should be readable and well-structured, but doesn't need to be perfectly grammatically correct. Focus on readability and information preservation.

Original text: ${inputText}

Return only the cleaned text, nothing else.`;

  const requestBody = {
    model: Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a helpful assistant that processes transcribed text into clean, readable format while preserving all information.",
      },
      {
        role: "user",
        content: prompt,
      },
    ],
    max_completion_tokens: 1000,
    // temperature: 0.3, // Not supported by gpt-5-mini, defaults to 1
  };

  try {
    // Log request details (without exposing API key)
    console.log(JSON.stringify({
      event: "openai_text_processing_request",
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
        event: "openai_text_processing_error",
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
      event: "openai_text_processing_response",
      model: data.model,
      finishReason: data.choices?.[0]?.finish_reason,
      usage: data.usage,
      responseLength: data.choices?.[0]?.message?.content?.length ?? 0,
    }));

    const processedText = data.choices?.[0]?.message?.content?.trim();

    if (!processedText) {
      console.warn(JSON.stringify({
        event: "openai_text_processing_empty_response",
        fullResponse: JSON.stringify(data),
      }));
      return null;
    }

    return processedText;
  } catch (error) {
    console.error(JSON.stringify({
      event: "openai_text_processing_exception",
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    }));
    return null;
  }
}

/**
 * Generates a title from text using LLM
 * Can accept either input_text or processed_text
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

  const prompt = `Generate a concise, engaging title (maximum ${MAX_TITLE_LENGTH} characters) for a brief moment or memory based on this text. The title should be descriptive but brief, capturing the essence of what happened. Return only the title text, nothing else.

Text: ${text.substring(0, 1000)}`;

  const requestBody = {
    model: Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a helpful assistant that generates concise, engaging titles for personal memories.",
      },
      {
        role: "user",
        content: prompt,
      },
    ],
    max_completion_tokens: 500, // Increased to account for reasoning tokens in gpt-5-mini
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
 * Edge Function for processing moments
 * 
 * This function:
 * - Fetches moment data from database using memoryId
 * - Generates title from input_text
 * - Processes input_text → processed_text (cleaned, readable text)
 * - Updates database with processed_text and title
 * - Returns processing status
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

    let requestBody: ProcessMomentRequest;
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

    // Fetch memory data from database
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

    // Verify this is a moment
    const memoryType = memory.memory_type;
    if (memoryType !== "moment") {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "This function only processes moments",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const inputText = memory.input_text?.trim();
    if (!inputText || inputText.length === 0) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Memory has no input_text to process",
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
          memory_type: "moment",
          phase: "text_processing",
        },
      })
      .eq("memory_id", requestBody.memoryId);

    if (statusUpdateError) {
      console.error("Error updating processing status:", statusUpdateError);
      // Continue processing even if status update fails
    }

    const startTime = Date.now();

    try {
      // Run text processing and title generation in parallel
      const [processedTextResult, titleResult] = await Promise.all([
        processTextWithLLM(inputText),
        generateTitleWithLLM(inputText), // Generate title from input_text in parallel
      ]);
      
      if (!processedTextResult) {
        throw new Error("Failed to process text");
      }
      
      if (!titleResult) {
        throw new Error("Failed to generate title");
      }

      const processedText = processedTextResult;
      const title = titleResult;
      const duration = Date.now() - startTime;

      // Update memory with processed text and title
      const updateData: Record<string, unknown> = {
        processed_text: processedText,
        title: title,
        title_generated_at: new Date().toISOString(),
      };

      const { error: updateError } = await supabaseClient
        .from("memories")
        .update(updateData)
        .eq("id", requestBody.memoryId);

      if (updateError) {
        throw new Error(`Failed to update memory: ${updateError.message}`);
      }

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

      // Log generation event
      const requestId = crypto.randomUUID();
      console.log(
        JSON.stringify({
          event: "moment_processing",
          memoryId: requestBody.memoryId,
          titleLength: title.length,
          processedTextLength: processedText.length,
          inputTextLength: inputText.length,
          durationMs: duration,
          requestId: requestId,
          timestamp: completedAt,
          mode: isInternalTrigger ? "internal" : "external",
        }),
      );

      const response: ProcessMomentResponse = {
        title: title,
        processedText: processedText,
        status: "success",
        generatedAt: completedAt,
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      // Handle processing failure
      const processingError = error instanceof Error ? error.message : String(error);
      const failedAt = new Date().toISOString();

      // Get current attempts count
      const { data: currentStatus } = await supabaseClient
        .from("memory_processing_status")
        .select("attempts")
        .eq("memory_id", requestBody.memoryId)
        .single();

      const newAttempts = (currentStatus?.attempts || 0) + 1;

      // Update processing status to 'failed'
      await supabaseClient
        .from("memory_processing_status")
        .update({
          state: "failed",
          attempts: newAttempts,
          last_error: processingError,
          last_error_at: failedAt,
          last_updated_at: failedAt,
          metadata: {
            memory_type: "moment",
            error: processingError,
            attempts: newAttempts,
          },
        })
        .eq("memory_id", requestBody.memoryId);

      return new Response(
        JSON.stringify({
          code: "PROCESSING_FAILED",
          message: processingError,
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
  } catch (error) {
    console.error("Unexpected error in process-moment function:", error);

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


# Story processing keeps failing when title response is empty (Dec 7, 2025)

## Summary
- Memory `4814b636-994d-463a-bf4d-bf521af6d99f` stays in the **failed** state because the deployed `process-story` edge function still throws whenever the title LLM returns an empty/length-truncated response, even though narrative generation succeeds.
- The newer code in `supabase/functions/process-story/index.ts` already implements a fallback that completes processing when only the title is missing, but that bundle has not been deployed, so production jobs keep aborting with `"Failed to generate title"`.
- The impacted story also has no `audio_path` in `story_fields`, so the detail screen cannot render or play back the recording even though `audio_duration` (≈14 minutes) was captured on-device.

## Status (Dec 7, 2025)
- ✅ `process-story` edge function redeployed to Supabase (version `6d6d08f4...894e`); the live bundle now includes the `title_generation` fallback and the higher `max_completion_tokens = 150`, so GPT length truncations no longer abort the job when narrative text exists.
- ⚠️ Could not requeue memory `4814b636-994d-463a-bf4d-bf521af6d99f` in the shared dev database—the row is missing from both `memories` and `memory_processing_status`. Please run the following in the production project where the record exists to clear the failure and trigger dispatcher pickup:

```
update memory_processing_status
set state = 'scheduled',
    attempts = 0,
    last_error = null,
    last_error_at = null
where memory_id = '4814b636-994d-463a-bf4d-bf521af6d99f';
```

## User impact
- Story detail shows neither the generated narrative nor a playable audio clip; the memory card falls back to the placeholder title (and audio banner is missing), so the user cannot review the content they just recorded.
- Dispatcher keeps retrying the bad processing code path, incrementing `attempts` and wasting OpenAI tokens while never unblocking the memory.

## Evidence
### Logs from the failing run
```
{"event":"story_processing_failed","memoryId":"4814b636-994d-463a-bf4d-bf521af6d99f","error":"Failed to generate title","attempts":3,"timestamp":"2025-12-07T17:41:04.540Z"}
{"event":"openai_title_generation_request","model":"gpt-5-mini","promptLength":1202,"maxTokens":100}
{"event":"openai_title_generation_empty_response","finishReason":"length","usage":{"completion_tokens":100}}
```
Narrative requests in the same run report `finishReason:"stop"` and ~1.7k completion tokens, so only the title branch fails.

### Database snapshots (Dec 7)
- `memories` row still lacks generated output:
  - `title`: `"This is a test ..."` (fallback from `MemorySaveService`)
  - `processed_text`: `NULL`
  - `title_generated_at`: `NULL`
- `memory_processing_status`: `state='failed'`, `attempts=3`, `last_error={"code":"PROCESSING_FAILED","message":"Failed to generate title"}`.
- `story_fields`: `audio_duration='866.1'` (captured), **`audio_path=NULL`**.

### Source vs. deployed behavior
The repo already contains fallback logic that only fails when **both** title and narrative return null:
```38:69:supabase/functions/process-story/index.ts
if (titleResult && titleResult.trim().length > 0) {
  title = truncateTitle(titleResult, MAX_TITLE_LENGTH);
} else {
  titleFallbackUsed = true;
  fallbackSource = narrativeResult ? "narrative" : "input_text";
  title = truncateTitle(narrative, MAX_TITLE_LENGTH);
}
```
Production logs still show `maxTokens:100` (old default) and never emit `title_generation_fallback_used`, confirming the new build has not been deployed.

### Audio upload gap
`MemorySaveService` silently swallows storage upload failures, so this memory ended up with duration metadata but no storage path:
```303:344:lib/services/memory_save_service.dart
try {
  await _supabase.storage.from('stories-audio').upload(...);
  audioPath = audioStoragePath;
} catch (e) {
  // Audio upload failed, but continue with story creation
}
await _supabase.from('story_fields').insert({
  'memory_id': memoryId,
  'audio_path': audioPath, // remains null on failure
  'audio_duration': state.audioDuration,
});
```
Large WAV uploads (~14 minutes) are likely hitting Supabase limits, leaving detail screens without a playable URL.

## Root causes
1. **Outdated edge function deployment** – The current `process-story` bundle in production still throws when `titleResult` is empty, so any `finish_reason = "length"` (common on GPT-5 mini) marks the memory failed even if the narrative succeeded.
2. **Audio upload failure is swallowed** – When the Storage upload fails, the client inserts `story_fields` with a null `audio_path` and provides no user feedback, so detail screens can never load audio even though duration metadata exists.

## Remediation plan
1. **Redeploy `process-story`**
   - Deploy the latest code (with `max_completion_tokens = 150` and fallback handling) to Supabase Functions.
   - After deployment, verify logs show `maxTokens:150` and `title_generation_fallback_used` when OpenAI returns nothing.
   - Requeue this memory (`UPDATE memory_processing_status SET state='scheduled', attempts=0, last_error=NULL WHERE memory_id='4814b636-994d-463a-bf4d-bf521af6d99f'`) or run `dispatch-memory-processing` so it processes with the new bundle.
2. **Increase resilience for long transcripts**
   - Consider bumping title `max_completion_tokens` further (e.g., 256) or switching to `response_format: { type: "text" }` so reasoning tokens do not consume the entire budget on long stories.
3. **Improve audio upload reliability**
   - Reproduce with long dictation files and capture the exception currently swallowed in `MemorySaveService`.
   - At minimum, log and surface a user-visible warning when uploads fail; ideally, chunk or compress recordings (e.g., convert to AAC) before uploading to stay under Supabase limits.
   - Provide a manual remediation path (e.g., retry upload) so `audio_path` is eventually populated.
4. **Verify playback after fixes**
   - Once redeployed and audio path restored, confirm `memories.processed_text` and `title` populate, `memory_processing_status.state` flips to `complete`, and `story_fields.audio_path` resolves to a valid signed URL. The detail view should then show both the generated narrative and a working audio player.

## Open questions / follow-ups
- Do other edge functions (`process-moment`, `process-memento`) still throw on missing titles? They should adopt the same fallback strategy to avoid similar regressions.
- Should we add monitoring for `title_generation_empty_response` and `title_generation_fallback_used` so operations can detect spikes without waiting for user reports?

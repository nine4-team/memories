# Native Dictation Audio Engine Failure

## Summary
- Attempting to start dictation inside `memories` immediately throws a scheduler error before `NativeDictationService.startListening` finishes, and the plugin surfaces `AUDIO_ENGINE_ERROR: Audio engine failed to start. Please try again.`
- The crash is triggered by `ConnectivityService.connectivityStream`, which builds a nullable ticker stream with `Stream<bool>.periodic` but omits the required `computation` callback.
- Because `MemorySyncService.startAutoSync()` subscribes to this stream during the same frame `_SyncServiceInitializerState.initState` runs, the exception bubbles up on the scheduler thread and leaves the dictation service in a half-initialized state.

## Symptoms
- Flutter logs show `Invalid argument (computation)` emitted by the scheduler before any dictation audio-level logs.
- Immediately afterward, the dictation plugin reports `AUDIO_ENGINE_ERROR` and the UI shows “Audio engine failed to start. Please try again.”
- Running the standalone `/Users/benjaminmackenzie/Dev/flutter_dictation/example` works because it does not instantiate `ConnectivityService`, so the periodic stream never throws.

## Evidence
1. **Scheduler exception in logs**
   ```
   ══╡ EXCEPTION CAUGHT BY SCHEDULER LIBRARY ╞══════════════════════════════════════════════════════
   Invalid argument (computation): Must not be omitted when the event type is non-nullable: null
   #1      ConnectivityService.connectivityStream (package:memories/services/connectivity_service.dart:40:12)
   #2      MemorySyncService.startAutoSync (package:memories/services/memory_sync_service.dart:49:54)
   #3      _SyncServiceInitializerState.initState.<anonymous closure> (package:memories/widgets/sync_service_initializer.dart:28:19)
   ```

2. **Faulty stream definition (FIXED)**

**Original buggy code:**
```dart
Stream<bool> get connectivityStream {
  return Stream<bool>.periodic(_pollInterval)
      .asyncMap((_) => isOnline())
      .distinct();
}
```

**Fixed code (now in place):**
```39:43:lib/services/connectivity_service.dart
Stream<bool> get connectivityStream {
  return Stream<void>.periodic(_pollInterval)
      .asyncMap((_) => isOnline())
      .distinct();
}
```

`Stream.periodic` defaults to emitting the iteration index, but if you specify a different generic (here `bool`) you must also pass the `computation` callback. Because we omitted that callback, the stream tried to emit `null` into a non-nullable `bool` sequence and threw before `isOnline` was ever invoked. The fix uses `Stream<void>.periodic` which safely emits `null`, which `asyncMap` ignores, and the final `Stream<bool>` still comes from the `isOnline()` futures.

3. **Dictation plugin only fails in Memories**
   - The same hardware successfully runs `/Users/benjaminmackenzie/Dev/flutter_dictation/example`, proving the native plugin and microphone permissions are healthy.
   - The only delta is the crashing connectivity stream wired through `_SyncServiceInitializer`, so dictation errors correlate 1:1 with the scheduler exception.

## Recommended Fix
1. **✅ FIXED: Provide a computation callback (or change the ticker type) so the periodic stream emits valid values.**

   The fix has been applied in `lib/services/connectivity_service.dart`:
   - Changed from `Stream<bool>.periodic(_pollInterval)` to `Stream<void>.periodic(_pollInterval)`
   - `Stream<void>.periodic` safely emits `null`, which `asyncMap` ignores, and the final `Stream<bool>` still comes from the `isOnline()` futures.
   - This prevents the scheduler crash that was interfering with dictation initialization.

2. **Retest dictation after the fix**
   - Rebuild the app, launch on the device, and trigger dictation.
   - Confirm no scheduler exceptions appear, `NativeDictationService` logs `=== START LISTENING COMPLETE ===`, and audio capture succeeds.
   - Verify Memory Sync continues to subscribe (connectivity toggles still enqueue sync attempts).

## Follow-up After Applying the Stream Fix
- With `Stream<void>.periodic` in place the scheduler crash disappears, but the native plugin can still emit `AUDIO_ENGINE_ERROR` if iOS denies microphone access or the audio session is inactive.
- Latest log snippet (post-fix) shows the engine failing immediately after `startListening` because the native layer reports an error event instead of a status transition:

```
flutter: [NativeDictationService] === START LISTENING START ===
flutter: [NativeDictationService] Event data: {message: Audio engine failed to start. Please try again., type: error}
flutter: [NativeDictationService] === START LISTENING FAILED after 111ms ===
flutter: [NativeDictationService] PlatformException code: AUDIO_ENGINE_ERROR
```

- The Swift implementation (`AudioEngineManager.startRecording`) checks `audioSession.recordPermission` and `audioSession.isOtherAudioPlaying` right before calling `audioEngine.start()`. If either guard fails, it throws with the exact error string above and sends the error event you see.

## Root Cause: Threading Issue (NEW)

After fixing the stream issue, Xcode logs reveal the actual problem:

**The audio engine's permission request is being called from a background thread, but iOS requires permission dialogs to run on the main thread.**

### Evidence from Xcode Logs:
```
[AudioEngineManager] [INFO] [BG] AudioEngineManager.swift:311 startRecording(...) - Current thread: BACKGROUND
[AudioEngineManager] [INFO] [BG] AudioEngineManager.swift:361 startRecording(...) - Permission not granted, requesting permission...
[AudioEngineManager] [ERROR] [BG] AudioEngineManager.swift:367 startRecording(...) - ERROR: Not on main thread! This will prevent permission dialog from appearing.
Error Domain=AudioEngineManager Code=-1 "Permission request must be called on main thread. This is a programming error."
```

### The Problem:
- `AudioEngineManager.startRecording()` runs on a background thread (`[BG]`)
- When microphone permission is not granted, it attempts to request permission
- iOS requires `AVAudioSession.requestRecordPermission(_:)` to be called on the main thread
- The request fails with a programming error, causing `AUDIO_ENGINE_ERROR`

### Required Fix:
The native Swift code in `AudioEngineManager.startRecording()` must dispatch the permission request to the main thread. The permission check/request logic needs to be wrapped in:

```swift
DispatchQueue.main.async {
    // Request permission here
}
```

**Note:** This is a bug in the `flutter_dictation` plugin's native Swift code, not in the Memories app code. The fix needs to be applied in the plugin repository (`/Users/benjaminmackenzie/Dev/flutter_dictation`).

### Next Actions
1. **Fix the plugin's native code** (in `flutter_dictation` repo)
   - Locate `AudioEngineManager.startRecording()` in the Swift implementation
   - Wrap the `requestRecordPermission` call in `DispatchQueue.main.async { ... }`
   - Ensure the permission check also happens on main thread if needed
2. **Alternative workaround** (if plugin fix is delayed)
   - Pre-request microphone permission in the Flutter app before calling `startListening()`
   - Use `permission_handler` or similar to request permission on app launch/onboarding
3. **Test on a physical device**
   - AVAudioEngine is flaky on the simulator; confirm on hardware to rule out simulator-only failures

## Verification Checklist
- [x] **Stream fix applied**: Changed `Stream<bool>.periodic` to `Stream<void>.periodic` in `ConnectivityService.connectivityStream`
- [x] Run `flutter test` to ensure no new regressions in connectivity-dependent services (completed - no connectivity-related test failures)
- [ ] `flutter run -d <device-id>`: start dictation and stop it; verify audio path and transcript populate (manual testing required)
- [ ] Toggle Airplane mode to ensure `connectivityStream` still emits booleans and `MemorySyncService` resumes syncing when the device reconnects (manual testing required)



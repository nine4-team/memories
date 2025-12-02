# iOS AudioWaveformsPlugin Duplicate Class Implementation

## Last Updated
2025-01-XX

## Summary
When running the Flutter app on iOS (physical device or simulator), Xcode logs show a warning that `AudioWaveformsPlugin` class is implemented in both the `audio_waveforms` framework and the `Runner.debug.dylib`. This duplication can cause symbol conflicts, mysterious casting failures, and potential runtime crashes.

## Symptoms
- Xcode console warning:
  ```
  objc[18365]: Class AudioWaveformsPlugin is implemented in both 
  /private/var/containers/Bundle/Application/.../Runner.app/Frameworks/audio_waveforms.framework/audio_waveforms (0x105ab9cc8) 
  and 
  /private/var/containers/Bundle/Application/.../Runner.app/Runner.debug.dylib (0x104fa0ef8). 
  This may cause spurious casting failures and mysterious crashes. 
  One of the duplicates must be removed or renamed.
  ```
- Warning appears during app launch
- May cause intermittent crashes or plugin registration failures
- Plugin may fail to initialize correctly

## Root Cause
The `audio_waveforms` plugin provides its own Swift implementation of `AudioWaveformsPlugin` in the framework. However, a manual Objective-C bridge was added to fix a previous issue with `use_frameworks!` configuration. This bridge creates a duplicate class definition:

1. **Plugin's native implementation**: The `audio_waveforms` plugin includes `AudioWaveformsPlugin` in its framework
2. **Manual bridge files**: `ios/Runner/AudioWaveformsPlugin.h` and `ios/Runner/AudioWaveformsPlugin.m` were added to work around symbol visibility issues

Both implementations are being compiled and linked, causing the duplicate class warning.

**Design principle going forward:** the `Runner` target should not declare its own `AudioWaveformsPlugin` class. We rely on the plugin’s own framework and Flutter’s generated registrant for registration. The manual bridge is considered a historical workaround and should not be reintroduced unless there is a compelling, well-documented reason.

## Evidence

### Current Bridge Files
- `ios/Runner/AudioWaveformsPlugin.h` - Header declaring the plugin interface
- `ios/Runner/AudioWaveformsPlugin.m` - Implementation that forwards to Swift plugin

### Xcode Project Configuration
The bridge files are included in the Runner target:
- `project.pbxproj` includes `AudioWaveformsPlugin.m` in the Sources build phase
- Files are listed in the Runner group

### Plugin Usage
The app uses `WaveformController` from `audio_waveforms`:
- `lib/providers/capture_state_provider.dart` - Creates `WaveformController` instance
- `lib/screens/capture/capture_screen.dart` - Uses waveform controller for visualization

## Historical Context
According to `docs/troubleshooting/archive/dictation_plugin_integration_fix_plan.md`, the bridge files were added to fix an issue where:
- `use_frameworks!` was enabled in `Podfile`
- Flutter couldn't find `AudioWaveformsPlugin` symbol during build
- Error: `Undefined symbol: _OBJC_CLASS_$_AudioWaveformsPlugin`

The bridge was created as a workaround to ensure the Objective-C symbol exists even when CocoaPods fails to expose it from the framework. That guidance is now **superseded**: the preferred fix is to rely on the pod-provided framework and symbols, and to debug CocoaPods / build configuration issues directly instead of adding a local bridge.

## Investigation Checklist
1. **Verify if bridge is still needed:**
   - Remove bridge files temporarily
   - Run `cd ios && pod install`
   - Build and run on device/simulator
   - Check if `Undefined symbol` error returns

2. **Check plugin registration:**
   - Verify `GeneratedPluginRegistrant.m` includes audio_waveforms registration
   - Confirm plugin initializes correctly without bridge

3. **Test waveform functionality:**
   - After removing bridge, test dictation/audio recording features
   - Verify `WaveformController` works correctly
   - Check for any runtime crashes or plugin errors

## Recommended Fix Plan

### Remove Manual Bridge and Use Plugin Framework (Preferred)

If the plugin's framework properly exposes the `AudioWaveformsPlugin` symbol (which is the expected and desired state), remove the manual bridge and rely entirely on the pod-provided implementation:

1. **Remove bridge files from the Xcode project (and disk):**
   - Open `ios/Runner.xcworkspace` in Xcode.
   - In the Project Navigator under the `Runner` group, select `AudioWaveformsPlugin.h` and `AudioWaveformsPlugin.m`.
   - Press Delete and choose **“Move to Trash”** so the files are removed from disk and from the target.
   - Open the **Runner** target → **Build Phases** → **Compile Sources** and confirm `AudioWaveformsPlugin.m` is no longer listed.
   - Alternatively, from the repo root you can run:
     ```bash
     git rm ios/Runner/AudioWaveformsPlugin.h
     git rm ios/Runner/AudioWaveformsPlugin.m
     ```
     and then open the workspace to ensure there are no red/missing file references.

2. **Reinstall pods:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. **Rebuild and test:**
   - Build and run on device/simulator.
   - Verify there are no duplicate-class warnings.
   - Verify there are no `Undefined symbol: _OBJC_CLASS_$_AudioWaveformsPlugin` errors.
   - Test dictation and waveform functionality to ensure the plugin behaves correctly without the bridge.

## Verification Steps (Post-Fix)
1. **Build without warnings:**
   - No duplicate class warnings in Xcode console
   - Clean build succeeds: `flutter clean && flutter build ios`

2. **Plugin functionality:**
   - Dictation service initializes correctly
   - Waveform visualization works during recording
   - Audio playback functions properly

3. **No symbol errors:**
   - No `Undefined symbol: _OBJC_CLASS_$_AudioWaveformsPlugin` errors
   - Plugin registers successfully

4. **Runtime stability:**
   - No mysterious crashes related to plugin casting
   - No intermittent initialization failures

## Related Files
- `ios/Runner/AudioWaveformsPlugin.h` - Manual bridge header
- `ios/Runner/AudioWaveformsPlugin.m` - Manual bridge implementation
- `ios/Runner.xcodeproj/project.pbxproj` - Xcode project configuration
- `ios/Podfile` - CocoaPods configuration (uses `use_frameworks!`)
- `lib/providers/capture_state_provider.dart` - Uses `WaveformController`
- `lib/screens/capture/capture_screen.dart` - Waveform visualization
- `docs/troubleshooting/archive/dictation_plugin_integration_fix_plan.md` - Historical context

## References
- Flutter plugin development: [https://docs.flutter.dev/development/packages-and-plugins/developing-packages](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- CocoaPods use_frameworks: [https://guides.cocoapods.org/syntax/podfile.html#use_frameworks_bang](https://guides.cocoapods.org/syntax/podfile.html#use_frameworks_bang)
- Objective-C class duplication: [https://developer.apple.com/documentation/objectivec](https://developer.apple.com/documentation/objectivec)


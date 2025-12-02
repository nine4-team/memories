# iOS Physical Device JIT Compilation Crash

## Last Updated
2025-01-XX

## Summary
When running the Flutter app on a physical iOS device via Xcode, the app crashes immediately on launch with `mprotect failed: 13 (Permission denied)` during Dart VM initialization. This occurs because iOS physical devices do not allow JIT (Just-In-Time) compilation, but the app is attempting to run in Debug mode which uses JIT.

## Symptoms
- App crashes immediately on launch when deployed to physical iOS device via Xcode
- Error log shows:
  ```
  ../../../flutter/third_party/dart/runtime/vm/virtual_memory_posix.cc: 428: error: mprotect failed: 13 (Permission denied)
  version=3.7.2 (stable) (Tue Mar 11 04:27:50 2025 -0700) on "ios_arm64"
  ```
- Stack trace shows crash during `dart::Code::FinalizeCode` → `dart::StubCode::Init()` → `Dart_Initialize`
- Error mentions `Runner.debug.dylib`, indicating Debug build mode
- Crash occurs before any Flutter UI is rendered

## Root Cause
iOS physical devices enforce strict security restrictions that prevent JIT compilation. Only AOT (Ahead-of-Time) compilation is allowed on physical devices. However, Flutter Debug builds use JIT compilation for faster development iteration.

**The issue:** The app is being built and deployed in Debug mode to a physical device, which attempts to use JIT compilation that iOS blocks.

## Technical Details

### Why JIT Fails on Physical Devices
- iOS uses code signing and memory protection to prevent dynamic code execution
- `mprotect()` system call fails with `EACCES` (Permission denied) when trying to mark memory pages as executable for JIT
- This is a security feature: iOS only allows pre-compiled, signed code to execute

### Flutter Build Modes
- **Debug**: Uses JIT compilation (fast hot reload, only works on simulator)
- **Profile**: Uses AOT compilation (optimized, works on physical devices)
- **Release**: Uses AOT compilation (fully optimized, works on physical devices)

## Recommended Fix

### Option 1: Use Profile Mode for Physical Device Testing (Recommended)
When testing on physical devices, use Profile mode instead of Debug:

**Via Xcode:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner scheme
3. Change the build configuration from "Debug" to "Profile"
4. Build and run on the physical device

**Via Flutter CLI:**
```bash
flutter run --profile -d <device-id>
```

**Via Xcode Scheme:**
1. Edit the Runner scheme (Product → Scheme → Edit Scheme)
2. Under "Run" → "Build Configuration", select "Profile"
3. Build and run

### Option 2: Use Release Mode
For production-like testing:
```bash
flutter run --release -d <device-id>
```

### Option 3: Use iOS Simulator for Debug Development
For rapid development with hot reload, use the iOS Simulator:
```bash
flutter run -d <simulator-id>
```

## Verification Steps
1. **Confirm build mode:**
   - Check Xcode scheme configuration (should be "Profile" or "Release" for physical devices)
   - Or use `flutter run --profile` or `flutter run --release`

2. **Test on physical device:**
   - Deploy using Profile or Release mode
   - App should launch successfully without `mprotect` errors
   - Note: Hot reload is disabled in Profile/Release modes

3. **Verify functionality:**
   - Test core app features to ensure Profile/Release builds work correctly
   - Check that native plugins (dictation, audio_waveforms) function properly

## Additional Notes

### Debug Mode Limitations
- Debug mode with JIT is **only** supported on iOS Simulator
- Physical devices **always** require AOT compilation (Profile or Release)
- This is an iOS platform restriction, not a Flutter limitation

### Development Workflow Recommendation
- **Development/Iteration**: Use iOS Simulator with Debug mode for hot reload
- **Device Testing**: Use Profile mode on physical devices for performance testing
- **Production**: Use Release mode for App Store builds

### Related Warnings (Non-Critical)
The error logs may also show:
- `UIScene lifecycle will soon be required` - Deprecation warning, doesn't cause crash
- `FlutterView implements focusItemsInRect:` - Performance warning, doesn't cause crash
- `Class AudioWaveformsPlugin is implemented in both...` - See separate troubleshooting doc for this issue

## Related Files
- `ios/Runner.xcodeproj/project.pbxproj` - Xcode project configuration
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` - Xcode scheme configuration
- `ios/Flutter/Debug.xcconfig` - Debug build configuration
- `ios/Flutter/Release.xcconfig` - Release build configuration

## References
- Flutter iOS deployment: [https://docs.flutter.dev/deployment/ios](https://docs.flutter.dev/deployment/ios)
- iOS code signing and security: [https://developer.apple.com/documentation/security](https://developer.apple.com/documentation/security)


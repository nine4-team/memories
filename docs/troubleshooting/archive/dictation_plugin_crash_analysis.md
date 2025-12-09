# Dictation Plugin Crash Analysis: EXC_BAD_ACCESS During Plugin Registration

## Crash Summary

**App**: Memories (com.memories.app.beta)  
**Version**: 1.0.0 (1)  
**Crash Type**: EXC_BAD_ACCESS (SIGSEGV) – Segmentation Fault  
**Crash Location**: Main thread, during app launch (`application:didFinishLaunchingWithOptions:`)  
**Faulting Plugin**: `flutter_dictation`  
**Specific Function**: `FlutterDictationPlugin.register(with:)`  
**Cause**: Attempt to access a null pointer (0x0). Likely a Swift object being accessed before initialization or a misconfigured Flutter plugin.  
**Trigger**: Happens immediately on app launch when the `GeneratedPluginRegistrant` tries to register the `FlutterDictationPlugin`.  
**Environment**: iOS Simulator, macOS 26.1, ARM64  

**Critical Note**: The plugin did not crash previously during tests. This is a new regression.

## Reference Applications

- **Working Example App**: `/Users/benjaminmackenzie/Dev/flutter_dictation/example`
  - Uses the same `flutter_dictation` plugin successfully
  - No crashes during plugin registration
  - Standard Flutter app structure

- **Crashing App**: `/Users/benjaminmackenzie/Dev/memories`
  - Same plugin version and configuration
  - Crashes immediately on launch during plugin registration
  - Uses UIKit Scene-based architecture

## Root Cause Analysis

### Observed Failure Surface

The crash occurs in `FlutterDictationPlugin.register(with:)` during `application:didFinishLaunchingWithOptions:`. The plugin never completes channel setup—the app terminates before any Dart code executes. Since the working example app successfully uses the same plugin, the native plugin code path is sound. The difference must be in how the host app initializes the Flutter engine.

### Control vs. Memories App Startup Comparison

#### Working Example App Structure

The example app uses the standard single-scene Flutter template:

**AppDelegate.swift** (Example):
```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Flutter will automatically register plugins via podspec
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Key Characteristics**:
- No `UIApplicationSceneManifest` in `Info.plist`
- No `SceneDelegate` class
- `FlutterAppDelegate` creates the window and Flutter engine automatically
- Plugin registration happens against the same engine instance that will run the app
- Single, unified Flutter engine lifecycle

#### Memories App Structure

The Memories app diverges in two critical ways:

**1. UIKit Scene-Based Architecture**

**Info.plist** includes:
```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

**2. SceneDelegate Creates FlutterViewController Separately**

**SceneDelegate.swift**:
```swift
@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window for this scene
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Load the FlutterViewController from the storyboard
        // The storyboard already has FlutterViewController configured
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let flutterViewController = storyboard.instantiateInitialViewController() {
            window.rootViewController = flutterViewController
        }
        
        window.makeKeyAndVisible()
    }
}
```

**3. AppDelegate Still Registers Plugins**

**AppDelegate.swift** (Memories):
```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Force Swift runtime initialization by using Swift types
    // This ensures the runtime is ready before plugin registration
    // Critical when using use_frameworks! with Swift-based Flutter plugins
    let _ = String.self
    let _ = Array<Any>.self
    let _ = Dictionary<String, Any>.self
    let _ = Optional<Any>.self
    
    // Force Swift runtime to initialize by creating a dummy object
    // This ensures Swift metadata is available before plugin registration
    let _ = NSObject()
    
    // Register plugins before initializing Flutter engine
    // This is the standard Flutter pattern
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### The Problem: Engine Lifecycle Mismatch

**Critical Issue**: Plugins are registered in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` against the `FlutterAppDelegate` instance, but **no Flutter engine is created or retained at this point**. When `SceneDelegate` later instantiates a brand new `FlutterViewController` from the storyboard (which creates its own engine internally), the registrar/messenger that `flutter_dictation` obtained during registration now points to an engine that was never actually started or is no longer valid.

**Why Only `flutter_dictation` Crashes**: The `flutter_dictation` plugin eagerly accesses the `FlutterPluginRegistrar.messenger()` during `register(with:)` to create method and event channels:

```swift
public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterDictationPlugin()
    
    // Create method channel
    let methodChannel = FlutterMethodChannel(
      name: "com.flutter_dictation/methods",
      binaryMessenger: registrar.messenger()  // ← CRASH HERE: null pointer
    )
    
    // Create event channel
    let eventChannel = FlutterEventChannel(
      name: "com.flutter_dictation/events",
      binaryMessenger: registrar.messenger()  // ← Or here
    )
    
    // Set up platform channels
    instance.setupPlatformChannels(methodChannel: methodChannel, eventChannel: eventChannel)
    
    // Register method channel handler
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    
    // Pre-warm managers after a delay to avoid crashes during launch
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      instance.prewarmManagers()
    }
}
```

Other plugins (like `audio_waveforms`) defer real work until Dart invokes them, so they don't crash during registration.

## Solution Theory

The fix must align Memories with the working example app's single-engine lifecycle pattern, ensuring `GeneratedPluginRegistrant` always runs against the same `FlutterEngine` that will actually run the app.

### Solution Option 1: Remove Scene-Based Architecture (Simplest)

**Approach**: Revert to the standard Flutter app structure used by the working example.

**Steps**:
1. Delete `ios/Runner/SceneDelegate.swift`
2. Remove the `UIApplicationSceneManifest` block from `ios/Runner/Info.plist`
3. Let `FlutterAppDelegate` create the window and engine automatically (default behavior)

**Result**: Single engine lifecycle, plugin registration happens against the live engine, crash eliminated.

**Pros**:
- Minimal code changes
- Matches the proven working example exactly
- No risk of engine lifecycle bugs

**Cons**:
- Loses scene-based architecture (if that was intentional for future multi-scene support)

### Solution Option 2: Explicit Engine Management with Scenes (If Scenes Are Required)

**Approach**: Create and retain a single `FlutterEngine` in `AppDelegate`, register plugins against it, and reuse it in `SceneDelegate`.

**Steps**:

1. **Modify AppDelegate.swift**:
```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
    // Retain the engine so SceneDelegate can use it
    lazy var flutterEngine: FlutterEngine = {
        let engine = FlutterEngine(name: "primary_engine")
        engine.run()
        return engine
    }()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Create and start the engine before registering plugins
        _ = flutterEngine
        
        // Register plugins against the engine (not self)
        GeneratedPluginRegistrant.register(with: flutterEngine)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

2. **Modify SceneDelegate.swift**:
```swift
@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Get the engine from AppDelegate
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate must be available")
        }
        
        // Create window
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Create FlutterViewController with the existing engine (not a new one)
        let flutterViewController = FlutterViewController(
            engine: appDelegate.flutterEngine,
            nibName: nil,
            bundle: nil
        )
        
        window.rootViewController = flutterViewController
        window.makeKeyAndVisible()
    }
}
```

3. **Remove Storyboard Dependency** (optional but recommended):
   - Remove `UIMainStoryboardFile` from `Info.plist`
   - Delete or ignore `Main.storyboard` (FlutterViewController is created programmatically)

**Result**: Single engine lifecycle maintained, plugin registration happens against the live engine, crash eliminated while preserving scene architecture.

**Pros**:
- Preserves scene-based architecture
- Follows Flutter's documented multi-scene pattern
- Explicit engine management prevents lifecycle bugs

**Cons**:
- More code changes
- Requires careful engine lifecycle management

## Implementation Recommendation

**Recommended**: Start with **Solution Option 1** (remove scenes) because:
1. It matches the proven working example exactly
2. Minimal risk of introducing new bugs
3. Scenes are only necessary if you plan to support multiple windows/scenes (which Memories doesn't currently need)

If scenes are required for future features, implement **Solution Option 2** after Option 1 is validated.

## Verification Steps

After implementing either solution:

1. **Clean Build**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
```

2. **Build and Run**:
```bash
flutter build ios --no-codesign
flutter run -d <device-id>
```

3. **Verify Plugin Registration**:
   - App should launch without crashing
   - Check Xcode console for plugin registration logs
   - Verify `flutter_dictation` plugin initializes successfully

4. **Functional Test**:
   - Navigate to capture screen
   - Start dictation
   - Verify waveform and transcript work correctly

## Additional Notes

- The Swift runtime initialization code in `AppDelegate` (lines 11-21) was an attempt to work around this issue but doesn't address the root cause (engine lifecycle mismatch)
- The `use_frameworks!` setting in `Podfile` is correct and not the cause of this crash
- Plugin versions are identical between working example and Memories app
- This crash is specific to the engine lifecycle timing, not plugin code quality

## Related Files

- `/Users/benjaminmackenzie/Dev/memories/ios/Runner/AppDelegate.swift`
- `/Users/benjaminmackenzie/Dev/memories/ios/Runner/SceneDelegate.swift`
- `/Users/benjaminmackenzie/Dev/memories/ios/Runner/Info.plist`
- `/Users/benjaminmackenzie/Dev/memories/ios/Runner/Base.lproj/Main.storyboard`
- `/Users/benjaminmackenzie/Dev/flutter_dictation/example/ios/Runner/AppDelegate.swift` (reference)
- `/Users/benjaminmackenzie/Dev/flutter_dictation/ios/Classes/FlutterDictationPlugin.swift` (plugin source)


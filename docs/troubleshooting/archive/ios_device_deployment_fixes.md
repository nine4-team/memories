# iOS Device Deployment Fixes

## Issues Fixed

### 1. ✅ Missing Info.plist Keys
- Added `NSLocalNetworkUsageDescription` (originally required by the `connectivity_plus` plugin; now kept as a harmless, backward-compatible key)
- The `NSBonjourServices` warning is non-critical and can be ignored unless you're using Bonjour services

### 2. Provisioning Profile Issue
**Error:** `Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the currently selected device`

**Solution:**
1. Open Xcode
2. Select your project in the navigator
3. Select the "Runner" target
4. Go to "Signing & Capabilities" tab
5. Ensure "Automatically manage signing" is checked
6. Select your Team (should show team ID: 5VHL56HV63)
7. Xcode will automatically register your device and create/update the provisioning profile
8. If automatic signing fails:
   - Go to [Apple Developer Portal](https://developer.apple.com/account)
   - Navigate to "Certificates, Identifiers & Profiles"
   - Under "Devices", ensure your iPhone is registered
   - If not, add it manually using the device UDID (found in Xcode's Devices window)

### 3. Program License Agreement (PLA)
**Error:** `PLA Update available: You currently don't have access to this membership resource`

**Solution:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. You'll see a banner or notification about the Program License Agreement
3. Click to review and accept the latest agreement
4. Once accepted, wait a few minutes for the changes to propagate
5. Try building again

### 4. mprotect Error (Permission Denied)
**Error:** `mprotect failed: 13 (Permission denied)` during Dart VM initialization

**Root Cause:** This is typically caused by:
- Code signing issues
- Provisioning profile problems
- Device not properly registered
- Entitlements mismatch

**Solution:**
1. **Clean the build:**
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   ```

2. **Fix provisioning (see #2 above)**

3. **Verify code signing in Xcode:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target → Signing & Capabilities
   - Ensure "Automatically manage signing" is enabled
   - Verify the Bundle Identifier matches: `com.memories.app.beta`
   - Check that your Team is selected

4. **Trust the developer certificate on your iPhone:**
   - On your iPhone: Settings → General → VPN & Device Management
   - Find your developer certificate and tap "Trust"

5. **Rebuild:**
   ```bash
   flutter build ios --debug
   ```
   Then run from Xcode

### 5. UIScene Lifecycle Warning
**Warning:** `UIScene lifecycle will soon be required`

This is a deprecation warning. To fix it, you need to update your iOS app to use UIScene-based lifecycle. However, this is not critical for now and won't prevent the app from running.

## Quick Fix Checklist

- [x] Added `NSLocalNetworkUsageDescription` to Info.plist
- [ ] Accept Program License Agreement in Apple Developer Portal
- [ ] Ensure device is registered in Apple Developer Portal
- [ ] Verify automatic signing is enabled in Xcode
- [ ] Clean build and reinstall pods
- [ ] Trust developer certificate on iPhone
- [ ] Rebuild and run

## Testing Steps

1. Clean everything:
   ```bash
   flutter clean
   cd ios && rm -rf Pods Podfile.lock && pod install && cd ..
   ```

2. Open in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

3. In Xcode:
   - Select your iPhone as the target device
   - Go to Signing & Capabilities
   - Verify automatic signing is working
   - Build and run (⌘R)

4. If provisioning still fails:
   - In Xcode: Window → Devices and Simulators
   - Select your iPhone
   - Note the device identifier
   - Add it manually in Apple Developer Portal if needed

## Notes

- The `NSBonjourServices` warning can be safely ignored unless you're using Bonjour services
- The mprotect error should resolve once provisioning is fixed
- Make sure you're using a physical device, not a simulator, for testing (especially for audio features)


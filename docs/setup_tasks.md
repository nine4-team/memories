# Authentication Setup Tasks

This document outlines all configuration tasks required to get the authentication system working properly.

## Prerequisites

- Supabase project created
- Flutter project initialized
- Google Cloud account (for OAuth)

---

## 0. Project Credentials (Quick Reference)

**Supabase Project URL:**
```
https://cgppebaekutbacvuaioa.supabase.co
```

**Supabase Publishable Key:**
```
sb_publishable_GunRzoOybI0g84ygBQ1wSg_Bs9QQj_5
```

**Note:** Supabase is moving to non-JWT keys. This `sb_publishable_` format is the new standard.

**Project Reference:** `cgppebaekutbacvuaioa`

**To use these credentials:**
```bash
flutter run --dart-define=SUPABASE_URL=https://cgppebaekutbacvuaioa.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_GunRzoOybI0g84ygBQ1wSg_Bs9QQj_5
```

---

## 1. Supabase Configuration

### 1.1 Environment Variables

Set these environment variables in your Flutter build configuration:

- `SUPABASE_URL` - Your Supabase project URL: `https://cgppebaekutbacvuaioa.supabase.co`
- `SUPABASE_ANON_KEY` - Your Supabase anonymous/publishable key: `sb_publishable_GunRzoOybI0g84ygBQ1wSg_Bs9QQj_5`

**For Flutter:**
- Add to `android/app/build.gradle` (android.defaultConfig.buildConfigField)
- Add to `ios/Runner/Info.plist` or use Xcode build settings
- Or use `--dart-define` flags when running: `flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx`

### 1.2 Configure Redirect URLs

**Action Required:** Go to Supabase Dashboard → Authentication → URL Configuration and add these redirect URLs.

**For this project (`cgppebaekutbacvuaioa`):**

You need to add redirect URLs based on your app's bundle ID/package name. Replace `YOUR_BUNDLE_ID` with your actual bundle ID (e.g., `com.memories.app.beta`):

**For Development:**
- `com.memories.app.beta://auth-callback` (for the mobile app builds; this deep link must match `lib/services/google_oauth_service.dart`/your app bundle ID so the native redirect can resume the session)
- `YOUR_BUNDLE_ID://auth-callback` (add this if your bundle ID differs from `com.memories.app.beta`)
- `http://localhost:3000/auth/callback` (only add when you are running the Flutter web version locally—use this redirect for browser-based OAuth flows during web testing)

**For Production:**
- `YOUR_BUNDLE_ID://auth-callback` (iOS - e.g., `com.memories.app.beta://auth-callback`)
- `YOUR_BUNDLE_ID://auth-callback` (Android - same format)
- `https://yourdomain.com/auth/callback` (if supporting web)

**Important:** 
- The redirect URL in your code (`lib/services/google_oauth_service.dart`) must match exactly what you configure here
- Once you determine your bundle ID, update both the Supabase Dashboard and the code
- The format is: `{BUNDLE_ID}://auth-callback`

**Current code uses:** `com.memories.app.beta://auth-callback`

### 1.3 Enable Google OAuth Provider

1. Go to Supabase Dashboard → Authentication → Providers
2. Enable "Google" provider
3. You'll need to add Google OAuth credentials (see section 2 below)

### 1.4 Configure Email Templates (Optional)

Supabase provides default email templates, but you may want to customize:
- Email verification template
- Password reset template

Go to: Authentication → Email Templates

---

## 2. Google Cloud Console Setup

### 2.1 Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API:
   - Go to "APIs & Services" → "Library"
   - Search for "Google+ API" and enable it
   - Also enable "Google Identity Toolkit API"

### 2.2 Create OAuth 2.0 Client ID

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - Choose "External" (unless you have a Google Workspace)
   - Fill in app name, user support email, developer contact
   - Add scopes: `email`, `profile`, `openid`
4. Create OAuth client ID:
   - Application type: **Web application**
   - Name: "Supabase Auth" (or similar)
   - Authorized redirect URIs: Add this:
     ```
     https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback
     ```

### 2.3 Get Client ID and Secret

After creating the OAuth client:
- Copy the **Client ID**
- Copy the **Client Secret**
UPDATE: DONE

### 2.4 Add Credentials to Supabase

1. Go back to Supabase Dashboard → Authentication → Providers → Google
2. Paste the **Client ID** and **Client Secret** from Google Cloud Console
3. Save the configuration

---

## 3. iOS Configuration

### 3.1 Update Bundle Identifier

Ensure your bundle identifier matches what you'll use in redirect URLs:
- Example: `com.memories.app.beta`
- Set in Xcode: Project → General → Bundle Identifier

### 3.2 Configure Universal Links (Recommended)

1. In Xcode, go to "Signing & Capabilities"
2. Add "Associated Domains" capability
3. Add domain: `applinks:cgppebaekutbacvuaioa.supabase.co`

**Alternative: Custom URL Scheme**

If not using Universal Links, ensure your `Info.plist` has:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_BUNDLE_ID</string>
    </array>
  </dict>
</array>
```

### 3.3 Update Redirect URL in Code

Update `lib/services/google_oauth_service.dart`:

```dart
String _getRedirectUrl() {
  // Replace with your actual bundle ID
  return 'YOUR_BUNDLE_ID://auth-callback';
  // Example: 'com.memories.app.beta://auth-callback'
}
```

---

## 4. Android Configuration

### 4.1 Update Package Name

Ensure your package name matches what you'll use in redirect URLs:
- Example: `com.memories.app.beta`
- Set in `android/app/build.gradle`: `applicationId`

### 4.2 Configure App Links (Recommended)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    ...>
    <!-- Existing intent filters -->
    
    <!-- Deep link intent filter -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="YOUR_BUNDLE_ID"
            android:host="auth-callback" />
    </intent-filter>
</activity>
```

Replace `YOUR_BUNDLE_ID` with your actual package name.

**Alternative: Custom URL Scheme**

If not using App Links, ensure your `AndroidManifest.xml` has the intent filter above (without `android:autoVerify="true"`).

### 4.3 Update Redirect URL in Code

Same as iOS - update `lib/services/google_oauth_service.dart`:

```dart
String _getRedirectUrl() {
  // Replace with your actual package name
  return 'YOUR_PACKAGE_NAME://auth-callback';
  // Example: 'com.memories.app.beta://auth-callback'
}
```

---

## 5. Code Updates Required

### 5.1 Update Redirect URL

**File:** `lib/services/google_oauth_service.dart`

**Current:**
```dart
String _getRedirectUrl() {
  return 'memories://auth-callback';
}
```

**Update to:**
```dart
String _getRedirectUrl() {
  // Replace with your actual bundle ID/package name
  return 'YOUR_BUNDLE_ID://auth-callback';
}
```

**Note:** Consider making this configurable via environment variables or platform detection.

### 5.2 Handle Deep Link Callbacks

Ensure your app's main entry point handles deep link callbacks. You may need to add:

**For iOS:** Handle Universal Links in `AppDelegate.swift` or via Flutter plugins

**For Android:** The intent filter above should handle it, but verify deep link handling in `MainActivity.kt`

**Flutter Plugin Option:**
Consider using `uni_links` or `app_links` package to handle deep links:
```yaml
dependencies:
  app_links: ^6.0.0  # or uni_links: ^5.0.0
```

Then listen for auth callbacks and pass to Supabase.

---

## 6. Configuration Checklist

- [ ] Supabase environment variables configured (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- [ ] Redirect URLs added to Supabase dashboard
- [ ] Google OAuth provider enabled in Supabase
- [ ] Google Cloud OAuth credentials created
- [ ] Google Client ID and Secret added to Supabase
- [ ] iOS bundle identifier configured
- [ ] iOS Universal Links or URL scheme configured
- [ ] Android package name configured
- [ ] Android App Links or intent filter configured
- [ ] Redirect URL updated in `google_oauth_service.dart`
- [ ] Deep link handling implemented (if needed)
- [ ] iOS Face ID usage description added to `Info.plist`
- [ ] Android biometric permissions added to `AndroidManifest.xml`
- [ ] Android `minSdkVersion` set to 23+

---

## 7. Troubleshooting

### Google OAuth Not Working

1. **Check redirect URLs match exactly:**
   - In Google Cloud Console (Authorized redirect URIs)
   - In Supabase Dashboard (Redirect URLs)
   - In your code (`google_oauth_service.dart`)

2. **Verify OAuth consent screen is configured:**
   - Must be configured before creating OAuth credentials
   - Scopes must include `email`, `profile`, `openid`

3. **Check Supabase provider configuration:**
   - Client ID and Secret must match Google Cloud Console
   - Provider must be enabled

### Deep Links Not Working

1. **iOS:**
   - Verify Universal Links domain is verified
   - Check Associated Domains capability is added
   - Verify `Info.plist` has URL scheme configured

2. **Android:**
   - Verify intent filter is in `AndroidManifest.xml`
   - Check package name matches everywhere
   - For App Links, verify domain verification

### Email Verification Not Working

1. Check Supabase email settings:
   - SMTP configuration (if using custom SMTP)
   - Email templates are configured
   - Check spam folder

2. Verify email confirmation is enabled:
   - Authentication → Settings → "Enable email confirmations"

### Biometric Authentication Not Working

1. **iOS:**
   - Verify `NSFaceIDUsageDescription` is in `Info.plist`
   - Check that device has Face ID/Touch ID enabled
   - Ensure app targets iOS 11.0+ for Face ID support
   - Test on physical device (simulator may not support biometrics)

2. **Android:**
   - Verify biometric permissions are in `AndroidManifest.xml`
   - Check `minSdkVersion` is 23 or higher
   - Ensure device has fingerprint/Face unlock enabled
   - Test on physical device (emulator may not support biometrics)

3. **General:**
   - Ensure biometrics are enabled in device settings

---

## 8. Security Notes

- **Never commit** `SUPABASE_ANON_KEY` or OAuth secrets to version control
- Use environment variables or secure configuration management
- For production, use different OAuth credentials than development
- Regularly rotate OAuth credentials
- Monitor Supabase logs for suspicious activity

---

## 9. Biometric Authentication Configuration

### 9.1 Add Dependencies

(Biometric dependency entries have already been added to `pubspec.yaml` in this repository.)
### 9.2 iOS Configuration

#### 9.2.1 Add Face ID Usage Description

Add to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to quickly and securely sign in to your account</string>
```

**Note:** This description is shown to users when Face ID is first requested. Make it clear and user-friendly.

#### 9.2.2 Verify Biometric Capability

Ensure your iOS app has the necessary capabilities:
- Face ID is automatically available if your app targets iOS 11.0+
- No additional entitlements needed for Face ID/Touch ID

### 9.3 Android Configuration

#### 9.3.1 Add Biometric Permission

Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>` tag):

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

**Note:** `USE_FINGERPRINT` is deprecated but included for older Android versions. `USE_BIOMETRIC` is the modern permission.

#### 9.3.2 Minimum SDK Version

Ensure your `android/app/build.gradle` has a minimum SDK version that supports biometrics:

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Android 6.0+ required for fingerprint
        // For better biometric support, consider minSdkVersion 28 (Android 9.0+)
    }
}
```

### 9.4 Generate Riverpod Code

(Riverpod code generation has already been run in this workspace; generated `.g.dart` files are present.)
### 9.5 Verify Configuration

**iOS:**
- [ ] `NSFaceIDUsageDescription` added to `Info.plist`
- [ ] App targets iOS 11.0+ (for Face ID support)

**Android:**
- [ ] Biometric permissions added to `AndroidManifest.xml`
- [ ] `minSdkVersion` is 23 or higher
- [ ] Test on device with biometrics enabled

**General:** (biometric dependency install and Riverpod code generation completed)

---

## 10. Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google OAuth Setup Guide](https://developers.google.com/identity/protocols/oauth2)
- [Flutter Deep Linking Guide](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Supabase Redirect URLs Guide](https://supabase.com/docs/guides/auth/redirect-urls)
- [local_auth Package Documentation](https://pub.dev/packages/local_auth)
- [iOS Face ID Documentation](https://developer.apple.com/documentation/localauthentication)
- [Android Biometric Documentation](https://developer.android.com/training/sign-in/biometric-auth)

---

## Quick Reference: Redirect URL Format

**Current placeholder:** `memories://auth-callback`

**Should be:** `YOUR_BUNDLE_ID://auth-callback`

**Examples:**
- iOS: `com.memories.app.beta://auth-callback`
- Android: `com.memories.app.beta://auth-callback`

**Important:** The redirect URL must match exactly in:
1. Supabase Dashboard → Authentication → URL Configuration
2. Your code (`google_oauth_service.dart`)
3. iOS/Android deep link configuration

---

## 12. Next Steps for This Project

**Immediate actions needed in Supabase Dashboard:**

1. **Configure Redirect URLs** (Section 1.2)
   - Go to: https://supabase.com/dashboard/project/cgppebaekutbacvuaioa/auth/url-configuration
   - Add: `memories://auth-callback` (or your actual bundle ID format)
   - Add: `http://localhost:3000/auth/callback` (for web testing)

2. **Enable Google OAuth Provider** (Section 1.3)
   - Go to: https://supabase.com/dashboard/project/cgppebaekutbacvuaioa/auth/providers
   - Enable "Google" provider
   - Add Google OAuth Client ID and Secret (after completing Section 2)

3. **Verify Project Settings**
   - Confirmed the publishable key is correct (new format: `sb_publishable_...`)
   - Checked Project Settings → API to verify the key

**Code updates needed:**
- Update `lib/services/google_oauth_service.dart` redirect URL once bundle ID is determined
- Configure environment variables in build configuration or use `--dart-define` flags

## 11. Manual tasks you must perform (assistant cannot do)

The following steps require access to your cloud consoles, local development machines, or physical devices and therefore cannot be performed by the assistant. Complete them manually or assign them to a team member:

- **Create and configure Google Cloud OAuth credentials** — You must create the OAuth client ID and secret in Google Cloud Console and paste them into the Supabase Dashboard; the assistant cannot access your Google account.
- **Add redirect URLs and enable providers in the Supabase Dashboard** — The assistant cannot operate within your Supabase project UI; add redirect URLs, enable Google (and other) providers, and verify settings yourself.
- **Set environment variables in CI/build configs or platform settings** — Add `SUPABASE_URL`, `SUPABASE_ANON_KEY`, Sentry DSN, and other secrets to your CI/CD secrets store, `--dart-define`, Xcode build settings, or Gradle config; do not commit secrets to source control.
- **Provision App Store / Google Play settings and entitlements** — Configure bundle IDs, provisioning profiles, App Store Connect / Play Console metadata, and upload builds; these require developer accounts and manual approval.
- **Verify and add Associated Domains / App Links** — Domain verification steps in Apple/Google consoles and adding associated domain files require access you must perform.
- **Add sensitive keys to secret managers** — Store service-role keys, OAuth client secrets, and other sensitive data in a secure secret manager; the assistant cannot store or rotate secrets for you.
- **Run local and CI build steps** — Execute `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs`, and platform builds locally or via CI; the assistant cannot run commands on your machine.
- **Test biometric flows on real devices** — Biometrics require hardware and platform configuration; validate Face ID / Touch ID and Android biometrics on physical devices (simulators may be insufficient).
- **Update native manifests and platform files** — Add `NSFaceIDUsageDescription` to `Info.plist`, biometric permissions to `AndroidManifest.xml`, and ensure `minSdkVersion` is set appropriately in `build.gradle`.
- **Approve OAuth consent screen and domain verification** — Google OAuth consent and any domain verification steps require interactive approval and ownership verification that only you can perform.

If you'd like, I can generate copy-pasteable snippets, CI configuration examples, platform manifest edits, and a step-by-step checklist for any of the above items — tell me which ones you want and I'll produce them.

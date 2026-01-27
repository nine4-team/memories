# Auth Refresh Token Failure & OAuth Callback Routing Error

## Last Updated
2026-01-27

## TL;DR
Historically, stored Supabase sessions failed to hydrate on iOS when `_hydrateSession()` called `refreshSession()` without letting Supabase rehydrate its internal cache. This surfaced as `AuthApiException(message: Invalid Refresh Token: Refresh Token Not Found, statusCode: 400)`. The current implementation now checks `supabase.auth.currentSession`, uses `recoverSession()` with the serialized session JSON from `SupabaseSecureStorage`, and treats `refresh_token_not_found` as an expected expiration. A separate OAuth callback routing issue may still occur if Flutter route handling intercepts `com.memories.app.beta://auth-callback`.

## Symptoms
- Console spam during cold start:
  - `authStateProvider initialization: Invalid Refresh Token: Refresh Token Not Found`
  - `supabase.supabase_flutter: WARNING: Invalid Refresh Token`
- App router drops back to the unauthenticated stack even when a session exists.
- After Google OAuth completes, Xcode logs `Failed to handle route information` and the app never navigates to the authenticated shell.

## Root Causes (Historical)
1. **Incorrect session hydration flow**  
   `Supabase.initialize` already persists the full session JSON via `SupabaseSecureStorage`, but `_hydrateSession()` ignored that cache and directly called `refreshSession()` with no `currentSession`. Supabase treated this as a missing refresh token and returned 400. The code also stored tokens separately in `SecureStorageService`, creating two divergent sources of truth.

2. **Deep link route interception**  
   `MaterialApp.onGenerateRoute` special-cased `/auth-callback`. When iOS launches the app with `com.memories.app.beta://auth-callback`, Flutter attempted to convert that URL into a route, colliding with Supabase’s plugin-level handler and throwing `FlutterViewController` errors.

## Investigation Checklist
1. Confirm `SupabaseSecureStorage.persistSession()` contains the PKCE session JSON (inspect the key in Keychain).  
2. Verify `secureStorage.getRefreshToken()` is **not** the same payload Supabase expects for `setSession()` (usually JSON vs raw token).  
3. Trigger the failure by:
   - Signing in with Google.
   - Killing the app.
   - Relaunching; watch `_hydrateSession()` logs.  
4. On the OAuth callback, confirm the deep link arrives (look for `supabase.supabase_flutter: INFO: handle deeplink uri`) followed immediately by the Flutter route error.

## Resolution (Implemented)

### 1. Align Session Hydration With Supabase Expectations
- `_hydrateSession()` now checks `supabase.auth.currentSession` first; if present, it skips manual work.
- If Supabase did not auto-hydrate, `_hydrateSession()` uses `supabase.auth.recoverSession(sessionJson)` with the serialized session JSON from `SupabaseSecureStorage`.
- `refresh_token_not_found` during recovery is treated as expected expiration: storage is cleared without surfacing a confusing error.
- The app no longer stores access/refresh tokens separately; only the serialized session JSON is mirrored when needed (e.g., for biometrics).

### 2. OAuth Deep Link Routing
- If `com.memories.app.beta://auth-callback` still triggers `FlutterViewController` route errors, verify `MaterialApp.onGenerateRoute` is not intercepting `/auth-callback`.
- Prefer logging in `AppDelegate.application(_:open:options:)` if diagnostics are needed.

### 3. Platform Configuration (Verify)
- Ensure `Info.plist` lists `com.memories.app.beta` under `CFBundleURLSchemes`.
- Supabase Dashboard → Authentication → URL Configuration includes `com.memories.app.beta://auth-callback`.
- Google Cloud OAuth client lists `https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback`.
- If Universal Links/App Links are enabled, confirm associated domains match; otherwise disable them.

## Verification Steps (post-fix)
1. Clear secure storage (both `supabase-auth-token` key and custom tokens). Relaunch; `_hydrateSession()` should log “No stored session” and finish without errors.
2. Complete Google OAuth. Confirm `AuthChangeEvent.signedIn` fires and auth state transitions to `authenticated`.
3. Kill app, relaunch. Supabase should auto-hydrate the session (no refresh call required). Route state should start at `authenticated`.
4. Force an expired refresh token (revoke in Supabase dashboard) and relaunch. App should silently clear storage and show login without error banners or crash logs.
5. Observe no `[FlutterViewController.mm]` errors when OAuth callback fires; navigation should be handled solely by the auth state stream.

## Related Files
- `lib/providers/auth_state_provider.dart`
- `lib/services/supabase_secure_storage.dart`
- `lib/services/secure_storage_service.dart`
- `lib/main.dart` (route handling)
- `ios/Runner/AppDelegate.swift` and `ios/Runner/Info.plist`

## References
- Supabase Flutter docs: [https://supabase.com/docs/guides/auth/auth-helpers/flutter](https://supabase.com/docs/guides/auth/auth-helpers/flutter)
- Internal setup guide `docs/setup_tasks.md` (sections 4 & 5)


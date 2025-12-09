# Auth Refresh Token Failure & OAuth Callback Routing Error

## Last Updated
2025-11-18

## TL;DR
Stored Supabase sessions fail to hydrate on iOS because `_hydrateSession()` calls `refreshSession()` without rehydrating Supabase’s internal session cache. This surfaces as `AuthApiException(message: Invalid Refresh Token: Refresh Token Not Found, statusCode: 400)`. At the same time, a Flutter `onGenerateRoute` handler tries to interpret the incoming OAuth deep link (`com.memories.app.beta://auth-callback`) as a Flutter route, producing `[FlutterViewController.mm(1869)] Failed to handle route information`.

## Symptoms
- Console spam during cold start:
  - `authStateProvider initialization: Invalid Refresh Token: Refresh Token Not Found`
  - `supabase.supabase_flutter: WARNING: Invalid Refresh Token`
- App router drops back to the unauthenticated stack even when a session exists.
- After Google OAuth completes, Xcode logs `Failed to handle route information` and the app never navigates to the authenticated shell.

## Root Causes
1. **Incorrect session hydration flow**  
   `Supabase.initialize` already persists the full session JSON via `SupabaseSecureStorage`, but `_hydrateSession()` ignores that cache and directly calls `refreshSession()` with no `currentSession`. Supabase treats this as a missing refresh token and returns 400. The code also stores tokens separately in `SecureStorageService`, creating two divergent sources of truth.

2. **Deep link route interception**  
   `MaterialApp.onGenerateRoute` special-cases `/auth-callback`. When iOS launches the app with `com.memories.app.beta://auth-callback`, Flutter attempts to convert that URL into a route, colliding with Supabase’s plugin-level handler and throwing `FlutterViewController` errors.

## Investigation Checklist
1. Confirm `SupabaseSecureStorage.persistSession()` contains the PKCE session JSON (inspect the key in Keychain).  
2. Verify `secureStorage.getRefreshToken()` is **not** the same payload Supabase expects for `setSession()` (usually JSON vs raw token).  
3. Trigger the failure by:
   - Signing in with Google.
   - Killing the app.
   - Relaunching; watch `_hydrateSession()` logs.  
4. On the OAuth callback, confirm the deep link arrives (look for `supabase.supabase_flutter: INFO: handle deeplink uri`) followed immediately by the Flutter route error.

## Recommended Fix Plan (do not implement yet)

### 1. Align Session Hydration With Supabase Expectations
- Prefer `supabase.auth.recoverSession()` so Supabase reads the serialized session it created via `SupabaseSecureStorage`.
- Before calling any refresh API, check `supabase.auth.currentSession`; if Supabase already hydrated automatically, skip manual work.
- When `recoverSession()` throws `refresh_token_not_found`, treat it as an expected expiration: clear `SecureStorageService` immediately and do **not** surface a user-facing error message.
- Decide on a single storage of truth:
  - Option A: rely solely on Supabase’s `LocalStorage` abstraction. Remove redundant secure storage writes for tokens.
  - Option B: if custom storage is required (e.g., biometrics), store the exact serialized session string and call `supabase.auth.setSession(sessionJson)` instead of refreshing.

### 2. Remove Flutter Route Interference
- Delete the `/auth-callback` case from `MaterialApp.onGenerateRoute` (Supabase handles the scheme at the platform channel level).
- If you need diagnostics, log inside `AppDelegate.application(_:open:options:)` rather than Flutter routing.

### 3. Revalidate Platform Configuration
- Ensure `Info.plist` lists `com.memories.app.beta` under `CFBundleURLSchemes`.
- Supabase Dashboard → Authentication → URL Configuration must include `com.memories.app.beta://auth-callback`.
- Google Cloud OAuth client must list `https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback`.
- If Universal Links/App Links are enabled, make sure associated domains match; otherwise disable them so the custom scheme is used consistently.

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


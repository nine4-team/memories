# Rapid Logout While Switching Memory Types (Auth Refresh Loop)

## Summary
- Users get kicked back to the login stack ~90 seconds after interacting with the capture screen, even though they never signed out.
- The logout coincides with Supabase’s first automatic access-token refresh attempt.
- Our custom `_hydrateSession()` workflow **overrides** Supabase’s persisted session JSON, so when the SDK attempts to refresh, it sees a stale / already rotated refresh token and emits `refresh_token_not_found`, forcing a sign-out event.

## Evidence
- `_hydrateSession()` reads the serialized session from `SupabaseSecureStorage`, calls `supabase.auth.setSession(sessionJson)` by hand, and mirrors the token into `SecureStorageService`. Any error (stale JSON, token already rotated) immediately clears storage and returns `AuthRouteState.unauthenticated`.
```210:342:lib/providers/auth_state_provider.dart
final sessionJson = await supabaseStorage.getSessionJson();
if (sessionJson != null && sessionJson.isNotEmpty) {
  await supabase.auth.setSession(sessionJson);
  ...
} on AuthException catch (e) {
  if (e.statusCode == 'refresh_token_not_found') {
    await secureStorage.clearSession();
    await supabaseStorage.removePersistedSession();
    return;
  }
}
```
- `docs/troubleshooting/auth_refresh_token_failure.md` already warns that manually hydrating / refreshing outside of Supabase’s flow causes exactly this `refresh_token_not_found` behavior. The current provider still follows the anti-pattern called out there.
- Repro: Sign in → open capture → flip memory type pills a few times → wait ~90 seconds. Supabase auto-refresh fires, `AuthChangeEvent.signedOut` hits the stream, and `AppRouter` navigates back to `LoginScreen`.

## Root Cause
1. **Two sources of truth** – Supabase persists the full session JSON via `SupabaseSecureStorage`. We also write partial tokens to `SecureStorageService`. When `_hydrateSession()` runs, it immediately overwrites Supabase’s internal cache by calling `setSession()` with whichever JSON we read, regardless of whether Supabase already hydrated itself.
2. **Stale refresh token usage** – When Supabase later tries to refresh, it uses the latest server-issued refresh token. Our mirrored JSON still references the *previous* refresh token, so the SDK (and GoTrue) rejects it (`refresh_token_not_found`). The provider catches that exception and clears storage, which looks like a forced logout to the user.

## Proposed Solutions
### 1. Let Supabase Own Hydration & Refresh (Recommended)
- Remove the manual JSON juggling. On startup:
  1. Call `await supabase.auth.initialize()` (already done via `Supabase.initialize`).
  2. If `currentSession != null`, stop; Supabase has already hydrated.
  3. Else call `await supabase.auth.recoverSession()` and rely on the SDK’s secure storage.
- Drop `SecureStorageService.storeSession()` for access/refresh tokens. If biometrics need the serialized session, store **only** the Supabase JSON blob; don’t attempt to mint expiry timestamps yourself.
- With this in place, the SDK keeps its refresh token rotation atomic and the 90-second logout disappears.

### 2. If Biometrics Require Custom Storage, Mirror the Exact JSON
- Keep `secureStorage.storeSessionJson(sessionJson)` but stop deriving `expiresAt` or splitting tokens.
- Only call `supabase.auth.setSession()` after biometric verification **and** only when Supabase fails to auto-hydrate (i.e., `currentSession == null`). Otherwise, skip to avoid overwriting fresh server-issued tokens.
- When `AuthChangeEvent.tokenRefreshed` fires, pull the serialized session via `SupabaseSecureStorage().getSessionJson()` and update the biometric cache so both storages stay in sync.

### 3. Harden Error Handling
- Treat `refresh_token_not_found` as “session expired” and surface a gentle “Session expired, please sign in again” toast instead of silently dumping users back to login.
- Add debug logging (and, eventually, Sentry breadcrumbs) capturing `AuthChangeEvent` transitions so we can correlate user actions with unexpected sign-outs.

## Resolution – 2025-12-24
- `_hydrateSession()` now checks `supabase.auth.currentSession`, prompts for biometrics only when required, and falls back to `supabase.auth.recoverSession()` so Supabase owns refresh token rotation.
- The provider no longer persists partial access/refresh tokens via `SecureStorageService.storeSession()`; we only mirror Supabase’s serialized session JSON for biometric unlock flows.
- `refresh_token_not_found` exceptions raised during recovery are treated as expected expirations: we clear both storages silently and let the user re-authenticate without forcing an app crash or repeated sign-outs.
- Every `AuthChangeEvent` now refreshes the mirrored JSON through `_mirrorSupabaseSessionToBiometricCache`, keeping biometric caches aligned with Supabase’s storage.

## Next Steps
1. QA: sign in, let the app idle on capture for 3+ minutes, verify no logout occurs and that `AuthChangeEvent.tokenRefreshed` logs continue without `signedOut`.
2. Update `docs/troubleshooting/auth_refresh_token_failure.md` with validation steps once the fix ships.


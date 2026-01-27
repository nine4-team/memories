# Rapid Logout While Switching Memory Types (Auth Refresh Loop)

## Summary
- Users get kicked back to the login stack ~90 seconds after interacting with the capture screen, even though they never signed out.
- The logout coincides with Supabase’s first automatic access-token refresh attempt.
- Our custom `_hydrateSession()` workflow **overrides** Supabase’s persisted session JSON, so when the SDK attempts to refresh, it sees a stale / already rotated refresh token and emits `refresh_token_not_found`, forcing a sign-out event.

## Evidence
- This class of failure correlates with Supabase’s **first** automatic refresh attempt (commonly ~60–120 seconds after login, depending on token lifetime and refresh scheduling).
- `docs/troubleshooting/auth_refresh_token_failure.md` warns that manually hydrating / refreshing outside of Supabase’s flow causes `refresh_token_not_found`.
- Historically, `_hydrateSession()` patterns that:
  - manually injected session JSON (e.g., `setSession()`),
  - manually refreshed without letting Supabase rehydrate its own persisted session first,
  - or persisted session/token state outside of Supabase
  can create stale/rotated refresh-token usage that later surfaces as a `signedOut` event.
- Repro: Sign in → open capture → flip memory type pills a few times → wait ~90 seconds. Supabase auto-refresh fires, `AuthChangeEvent.signedOut` hits the stream, and `AppRouter` navigates back to `LoginScreen`.

## Root Cause
1. **Two sources of truth** – Supabase persists the full session JSON via the configured `LocalStorage` (e.g., `SupabaseSecureStorage`). Any additional token/session persistence or manual “rehydration” logic can overwrite Supabase’s internal cache with stale data.
2. **Stale refresh token usage** – When Supabase later tries to refresh, it uses the latest server-issued refresh token. If app logic restores an older session snapshot (or races refresh), the SDK (and GoTrue) can reject it (`refresh_token_not_found`). If the app treats that exception as a hard sign-out, users experience “rapid logout.”

## Proposed Solutions
### 1. Let Supabase Own Hydration & Refresh (Recommended)
- Remove all manual session/token persistence outside Supabase. On startup:
  1. Call `await supabase.auth.initialize()` (already done via `Supabase.initialize`).
  2. If `currentSession != null`, stop; Supabase has already hydrated.
  3. Else call `await supabase.auth.recoverSession(sessionJson)` where `sessionJson` is the exact persisted session string read from the configured `LocalStorage` implementation (e.g., `SupabaseSecureStorage`).
- Do not derive `expiresAt` or split tokens. Don’t store access/refresh tokens anywhere except Supabase’s configured `LocalStorage`.
- With this in place, the SDK keeps its refresh token rotation atomic and the 90-second logout disappears.

### 2. Harden Error Handling
- Treat `refresh_token_not_found` as “session expired” and surface a gentle “Session expired, please sign in again” toast instead of silently dumping users back to login.
- Add debug logging (and, eventually, Sentry breadcrumbs) capturing `AuthChangeEvent` transitions so we can correlate user actions with unexpected sign-outs.

## Resolution – 2025-12-24
- `_hydrateSession()` now checks `supabase.auth.currentSession` and uses `supabase.auth.recoverSession(sessionJson)` only when Supabase did not auto-hydrate, so Supabase owns refresh token rotation.
- The app no longer persists partial access/refresh tokens (or any other “second source of truth”) outside of Supabase.
- `refresh_token_not_found` exceptions raised during recovery are treated as expected expirations: we clear persisted session state and let the user re-authenticate without forcing an app crash or repeated sign-outs.
- Every `AuthChangeEvent` is logged so we can correlate user actions with unexpected sign-outs.

## Next Steps
1. QA: sign in, let the app idle on capture for 3+ minutes, verify no logout occurs and that `AuthChangeEvent.tokenRefreshed` logs continue without `signedOut`.
2. Update `docs/troubleshooting/auth_refresh_token_failure.md` with validation steps once the fix ships.


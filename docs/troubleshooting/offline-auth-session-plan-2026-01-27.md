# Offline Auth Session Plan (High Offline Success Rate)

## Goal
Keep users in the app when they are offline **and** already have a cached session, while only forcing re-login when we know the session is truly invalid. Target: ~98% of offline launches succeed without a login prompt.

## Current Behavior (Observed)
- If a valid session is cached, users can enter the app offline.
- If there is no stored session (or if refresh fails), users are routed to login.
- `refresh_token_not_found` is treated as expiration (good), but network failures can still lead to a sign-out flow or confusing UI.

## Risks We Want to Avoid
- Clearing cached session on transient network errors.
- Treating offline refresh failure as logout.
- Forcing login while offline when the user already has a valid cached session.

## Proposed Changes

### 1. Separate “Offline” From “Unauthenticated”
Introduce an offline-aware route state or flag:
- If offline and a cached session exists, route to authenticated shell with offline banner.
- If offline and **no cached session**, route to unauthenticated with a clear “offline” message (no login attempt).

### 2. Do Not Clear Sessions on Network Errors
When a refresh or recovery fails due to offline/network:
- Preserve cached session JSON.
- Set a short-lived “offline auth state” in memory.
- Allow read-only/offline-safe actions; queue mutations.

### 3. Distinguish Expiration vs Offline
Treat only true expiration as logout:
- `refresh_token_not_found` => clear session and require login.
- Network/timeouts => keep session, mark offline state.

### 4. Graceful Startup Sequence
At launch:
1. Check `supabase.auth.currentSession`.
2. If present, proceed (even if offline).
3. If not present, attempt `recoverSession()` from `SupabaseSecureStorage`.
4. If recovery fails due to network, keep cached session and set offline state.
5. If recovery fails due to `refresh_token_not_found`, clear and require login.

### 5. UI Messaging
Provide clear offline messaging:
- If offline but authenticated: “You’re offline. Some actions will sync later.”
- If offline and unauthenticated: “You’re offline. Please reconnect to sign in.”

## Implementation Notes
- Add an `isOffline` flag or `AuthRouteState.offlineAuthenticated` state.
- Use `AuthErrorHandler.isOffline()` before clearing sessions.
- Log a specific `AuthChangeEvent` diagnostic for offline refresh failures.

## Edge Cases
- First install (no session): must show login and offline message.
- Explicit sign out: always unauthenticated, even if offline.
- Revoked refresh token while offline: must require login once network returns.

## Test Plan
1. Online login, kill app, toggle airplane mode, relaunch => should open app in offline mode.
2. Online login, revoke refresh token in Supabase, go offline, relaunch => app should open offline, then force login once online refresh fails with `refresh_token_not_found`.
3. Fresh install, offline => show offline + login disabled message.
4. Offline during token refresh => no logout, no session clearing.

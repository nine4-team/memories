import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/biometric_service.dart';
import 'package:memories/services/supabase_secure_storage.dart';

part 'auth_state_provider.g.dart';

/// Enum representing the current authentication routing state
enum AuthRouteState {
  /// User is not authenticated - show auth stack (login/signup)
  unauthenticated,

  /// User is authenticated but email not verified - show verification wait screen
  unverified,

  /// User is authenticated and verified but onboarding not completed - show onboarding
  onboarding,

  /// User is fully authenticated, verified, and onboarded - show main shell
  authenticated,
}

/// State class for authentication routing
class AuthRoutingState {
  final AuthRouteState routeState;
  final User? user;
  final Session? session;
  final String? errorMessage;

  const AuthRoutingState({
    required this.routeState,
    this.user,
    this.session,
    this.errorMessage,
  });

  AuthRoutingState copyWith({
    AuthRouteState? routeState,
    User? user,
    Session? session,
    String? errorMessage,
  }) {
    return AuthRoutingState(
      routeState: routeState ?? this.routeState,
      user: user ?? this.user,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for secure storage service
@riverpod
SecureStorageService secureStorageService(SecureStorageServiceRef ref) {
  return SecureStorageService();
}

/// Provider that listens to Supabase auth state changes and determines routing
///
/// This provider:
/// - Listens to auth state changes from Supabase
/// - Determines the appropriate route state based on user authentication,
///   email verification, and onboarding completion
/// - Handles session refresh and expiration
/// - Persists session tokens securely
@riverpod
Stream<AuthRoutingState> authState(AuthStateRef ref) async* {
  final supabase = ref.watch(supabaseClientProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  final errorHandler = ref.watch(authErrorHandlerProvider);

  try {
    // Hydrate session from secure storage on app start
    // This will check for biometric authentication if enabled
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('Initializing auth state provider...');
    debugPrint('═══════════════════════════════════════════════════════');
    await _hydrateSession(supabase, secureStorage, biometricService);

    // Get initial auth state immediately (before waiting for stream)
    final initialSession = supabase.auth.currentSession;
    final initialUser = supabase.auth.currentUser;

    debugPrint('Initial auth state:');
    debugPrint(
        '  User: ${initialUser?.id ?? "null"} (${initialUser?.email ?? "no email"})');
    debugPrint('  Session: ${initialSession != null ? "exists" : "null"}');
    if (initialSession != null) {
      debugPrint(
          '  Access token: ${initialSession.accessToken.substring(0, 20)}...');
    }

    // Emit initial state right away
    final initialRouteState = await _determineRouteState(
      supabase,
      initialUser,
      initialSession,
    );

    debugPrint('  Route state: $initialRouteState');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('');

    yield AuthRoutingState(
      routeState: initialRouteState,
      user: initialUser,
      session: initialSession,
    );

    // Listen to auth state changes
    await for (final authState in supabase.auth.onAuthStateChange) {
      try {
        debugPrint('');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('Auth state changed: ${authState.event}');
        debugPrint('═══════════════════════════════════════════════════════');
        final session = authState.session;
        final user = authState.session?.user;

        if (authState.event == AuthChangeEvent.signedIn) {
          debugPrint('✓ User signed in via OAuth');
          debugPrint('  User ID: ${user?.id}');
          debugPrint('  Email: ${user?.email}');
          debugPrint('  Session exists: ${session != null}');
        } else if (authState.event == AuthChangeEvent.signedOut) {
          debugPrint('✗ User signed out');
        } else if (authState.event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('↻ Token refreshed');
        }
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');

        // Handle session persistence
        if (session != null) {
          await _mirrorSupabaseSessionToBiometricCache(secureStorage);
        } else {
          await secureStorage.clearSession();
        }

        // Determine route state
        final routeState = await _determineRouteState(
          supabase,
          user,
          session,
        );

        yield AuthRoutingState(
          routeState: routeState,
          user: user,
          session: session,
        );
      } catch (e, stackTrace) {
        // Handle errors gracefully
        final errorMessage = errorHandler.handleAuthError(e);

        yield AuthRoutingState(
          routeState: AuthRouteState.unauthenticated,
          errorMessage: errorMessage,
        );

        // Log error for debugging
        errorHandler.logError(e, stackTrace);
      }
    }
  } catch (e, stackTrace) {
    // Handle initialization errors
    debugPrint('ERROR in authStateProvider initialization: $e');
    errorHandler.logError(e, stackTrace);

    yield AuthRoutingState(
      routeState: AuthRouteState.unauthenticated,
      errorMessage: errorHandler.handleAuthError(e),
    );
  }
}

/// Hydrate session from secure storage on app start
///
/// This function:
/// - First checks if Supabase has already auto-hydrated the session
/// - Uses recoverSession() to let Supabase read its own persisted session
/// - Checks if biometric authentication is enabled and required
/// - If biometrics are enabled, prompts for biometric authentication before recovery
/// - Handles refresh_token_not_found as expected expiration (silently clears storage)
Future<void> _hydrateSession(
  SupabaseClient supabase,
  SecureStorageService secureStorage,
  BiometricService biometricService,
) async {
  final supabaseStorage = SupabaseSecureStorage();

  try {
    // First, check if Supabase already has a hydrated session
    final currentSession = supabase.auth.currentSession;
    if (currentSession != null) {
      debugPrint(
        '  ✓ Supabase already has a hydrated session - skipping manual hydration',
      );
      await _mirrorSupabaseSessionToBiometricCache(
        secureStorage,
        supabaseStorage: supabaseStorage,
      );
      return;
    }

    // Check if Supabase has a persisted session in its storage
    final hasSupabaseSession = await supabaseStorage.hasSessionJson();

    if (!hasSupabaseSession) {
      debugPrint(
          '  No stored session found in Supabase storage - user needs to sign in');
      // Also clear any custom storage to keep them in sync
      await secureStorage.clearSession();
      return;
    }

    debugPrint('  ✓ Stored session found in Supabase storage - recovering...');
    final sessionJson = await supabaseStorage.getSessionJson();
    if (sessionJson == null || sessionJson.isEmpty) {
      debugPrint('  ✗ Session JSON missing despite storage flag - clearing');
      await secureStorage.clearSession();
      await supabaseStorage.removePersistedSession();
      return;
    }

    // Check if biometric authentication is enabled
    final biometricEnabled = await secureStorage.isBiometricEnabled();
    if (biometricEnabled) {
      // Check if biometrics are available
      final isAvailable = await biometricService.isAvailable();
      if (isAvailable) {
        // Prompt for biometric authentication
        final biometricTypeName =
            await biometricService.getAvailableBiometricTypeName();
        final authenticated = await biometricService.authenticate(
          reason:
              'Authenticate with ${biometricTypeName ?? 'biometrics'} to access your account',
        );

        if (!authenticated) {
          // Biometric authentication failed - clear session and require password login
          await secureStorage.clearSession();
          await secureStorage.clearBiometricPreference();
          // Also clear Supabase's persisted session
          await supabaseStorage.removePersistedSession();
          // Also update Supabase profile to disable biometrics
          try {
            final user = supabase.auth.currentUser;
            if (user != null) {
              await supabase
                  .from('profiles')
                  .update({'biometric_enabled': false}).eq('id', user.id);
            }
          } catch (e) {
            // Ignore errors updating profile - user will need to login with password
          }
          return;
        }

        // Biometric authentication succeeded - continue with session recovery
      } else {
        // Biometrics no longer available - clear preference
        await secureStorage.clearBiometricPreference();
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            await supabase
                .from('profiles')
                .update({'biometric_enabled': false}).eq('id', user.id);
          }
        } catch (e) {
          // Ignore errors updating profile
        }
      }
    }

    debugPrint('  Calling Supabase recoverSession()...');
    try {
      final response = await supabase.auth.recoverSession(sessionJson);
      final recoveredSession = response.session;

      if (recoveredSession == null) {
        debugPrint('  ✗ recoverSession() returned null - clearing storage');
        await secureStorage.clearSession();
        await supabaseStorage.removePersistedSession();
        return;
      }

      debugPrint('  ✓ Session recovered for user ${recoveredSession.user.id}');
      await _mirrorSupabaseSessionToBiometricCache(
        secureStorage,
        supabaseStorage: supabaseStorage,
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      final statusCode = (e.statusCode ?? '').toLowerCase();
      final isRefreshTokenMissing = statusCode == 'refresh_token_not_found' ||
          message.contains('refresh token not found') ||
          message.contains('refresh_token_not_found');
      if (isRefreshTokenMissing) {
        debugPrint(
            '  Refresh token not found (expected expiration) - clearing storage');
        await secureStorage.clearSession();
        await supabaseStorage.removePersistedSession();
        return;
      }
      rethrow;
    }
  } catch (e) {
    // If hydration fails, clear stored session
    debugPrint('  ✗ Session hydration failed: $e');
    await secureStorage.clearSession();
    // Don't throw - let user authenticate fresh
  }
}

Future<void> _mirrorSupabaseSessionToBiometricCache(
  SecureStorageService secureStorage, {
  SupabaseSecureStorage? supabaseStorage,
}) async {
  final storage = supabaseStorage ?? SupabaseSecureStorage();
  final sessionJson = await storage.getSessionJson();
  if (sessionJson != null && sessionJson.isNotEmpty) {
    await secureStorage.storeSessionJson(sessionJson);
  }
}

/// Determine the appropriate route state based on user status
Future<AuthRouteState> _determineRouteState(
  SupabaseClient supabase,
  User? user,
  Session? session,
) async {
  // No user or session - unauthenticated
  if (user == null || session == null) {
    return AuthRouteState.unauthenticated;
  }

  // Check if email is verified
  if (user.emailConfirmedAt == null) {
    return AuthRouteState.unverified;
  }

  // ONBOARDING BYPASSED - Commented out to skip onboarding flow
  // Check if onboarding is completed
  // Query profiles table to check onboarding_completed_at
  // try {
  //   final profileResponse = await supabase
  //       .from('profiles')
  //       .select('onboarding_completed_at')
  //       .eq('id', user.id)
  //       .maybeSingle();

  //   // If profile doesn't exist, assume onboarding needed
  //   if (profileResponse == null) {
  //     return AuthRouteState.onboarding;
  //   }

  //   final onboardingCompletedAt = profileResponse['onboarding_completed_at'];

  //   if (onboardingCompletedAt == null) {
  //     return AuthRouteState.onboarding;
  //   }
  // } catch (e) {
  //   // If query fails, assume onboarding needed
  //   // This handles edge cases where profile creation might be delayed
  //   // Don't log this as an error - it's an expected edge case
  //   return AuthRouteState.onboarding;
  // }

  // User is authenticated, verified, and onboarded
  // (Onboarding check bypassed - always return authenticated after verification)
  return AuthRouteState.authenticated;
}

/// Provider for current auth routing state (non-stream, synchronous access)
///
/// Note: This provider watches the auth state stream. In practice, you may want
/// to use AsyncValue or a StateNotifier to track the latest state more explicitly.
/// For now, components should watch authStateProvider directly to get stream updates.
@riverpod
Stream<AuthRoutingState> currentAuthState(CurrentAuthStateRef ref) {
  return ref.watch(authStateProvider.stream);
}

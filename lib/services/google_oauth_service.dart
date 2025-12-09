import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

part 'google_oauth_service.g.dart';

/// Service for handling Google OAuth authentication
///
/// Integrates with Supabase signInWithOAuth to handle Google authentication
/// with deep link callback handling for iOS/Android.
class GoogleOAuthService {
  final SupabaseClient _supabase;
  final AuthErrorHandler _errorHandler;

  GoogleOAuthService(this._supabase, this._errorHandler);

  /// Sign in with Google OAuth
  ///
  /// OAuth Flow:
  /// 1. App → Supabase: Calls signInWithOAuth with app redirect URL
  /// 2. Supabase → Google: Redirects to Google OAuth
  /// 3. Google → Supabase: Redirects to Supabase callback URL
  /// 4. Supabase → App: Redirects to app's deep link URL
  ///
  /// Configuration Required:
  /// - Google Cloud Console: Add Supabase callback URL:
  ///   https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback
  /// - Supabase Dashboard: Add app redirect URL:
  ///   com.memories.app.beta://auth-callback
  ///
  /// For iOS: Configure Universal Links in Xcode
  /// For Android: Configure App Links in AndroidManifest.xml
  Future<void> signIn() async {
    try {
      final redirectUrl = _getRedirectUrl();
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('Starting Google OAuth');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('App redirect URL: $redirectUrl');
      debugPrint('');
      debugPrint('OAuth Configuration Checklist:');
      debugPrint('✓ App redirect URL (this): $redirectUrl');
      debugPrint(
          '  → Must be registered in: Supabase Dashboard → Authentication → URL Configuration');
      debugPrint(
          '✓ Supabase callback URL: https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback');
      debugPrint(
          '  → Must be registered in: Google Cloud Console → OAuth 2.0 Client → Authorized redirect URIs');
      debugPrint('');
      debugPrint('Calling signInWithOAuth...');

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      debugPrint('✓ signInWithOAuth completed - browser should open');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('');
      debugPrint(
          'If Safari opens with "Open in Memories?" instead of Google login:');
      debugPrint(
          '→ Google OAuth provider is NOT properly configured in Supabase');
      debugPrint(
          '→ Check: Supabase Dashboard → Authentication → Providers → Google');
      debugPrint('→ Ensure:');
      debugPrint('  1. Google provider is ENABLED');
      debugPrint('  2. Client ID is set (from Google Cloud Console)');
      debugPrint('  3. Client Secret is set (from Google Cloud Console)');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);

      // Provide helpful error message for common OAuth issues
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('redirect') ||
          errorMessage.contains('url') ||
          errorMessage.contains('callback') ||
          errorMessage.contains('connect')) {
        debugPrint('');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('OAuth Configuration Error');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('If you see "Safari can\'t connect" after Google login:');
        debugPrint('');
        debugPrint('1. Verify Google Cloud Console configuration:');
        debugPrint(
            '   → Go to: Google Cloud Console → APIs & Services → Credentials');
        debugPrint('   → Find your OAuth 2.0 Client ID');
        debugPrint(
            '   → Under "Authorized redirect URIs", ensure this is added:');
        debugPrint(
            '     https://cgppebaekutbacvuaioa.supabase.co/auth/v1/callback');
        debugPrint('');
        debugPrint('2. Verify Supabase Dashboard configuration:');
        debugPrint(
            '   → Go to: Supabase Dashboard → Authentication → URL Configuration');
        debugPrint('   → Under "Redirect URLs", ensure this is added:');
        debugPrint('     com.memories.app.beta://auth-callback');
        debugPrint('');
        debugPrint('3. Verify Google OAuth credentials in Supabase:');
        debugPrint(
            '   → Go to: Supabase Dashboard → Authentication → Providers → Google');
        debugPrint('   → Ensure Client ID and Client Secret are correctly set');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');
      }

      rethrow;
    }
  }

  /// Get the redirect URL for OAuth callback
  ///
  /// Returns the appropriate redirect URL based on platform.
  /// This should match the URL configured in Supabase dashboard.
  String _getRedirectUrl() {
    // This must match the URL scheme in Info.plist (iOS) and AndroidManifest.xml (Android)
    // The bundle identifier is com.memories.app.beta
    return 'com.memories.app.beta://auth-callback';
  }

  /// Handle OAuth callback from deep link
  ///
  /// Call this method when the app receives a deep link callback
  /// from the OAuth provider. The URL should contain the auth tokens.
  Future<void> handleCallback(Uri callbackUrl) async {
    try {
      // Supabase will automatically handle the callback if the URL
      // matches the redirect URL configured in signInWithOAuth
      // The auth state listener will pick up the session change
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      rethrow;
    }
  }
}

/// Provider for Google OAuth service
@riverpod
GoogleOAuthService googleOAuthService(GoogleOAuthServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final errorHandler = ref.watch(authErrorHandlerProvider);
  return GoogleOAuthService(supabase, errorHandler);
}

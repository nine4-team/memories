import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_error_handler.g.dart';

/// Service for handling authentication errors
///
/// Provides user-friendly error messages and logging hooks per security standards.
/// Handles offline detection, network errors, and Supabase-specific auth errors.
class AuthErrorHandler {
  /// Handle authentication errors and return user-friendly messages
  ///
  /// Returns a user-friendly error message without exposing technical details
  /// or security information per error handling standards.
  String handleAuthError(Object error) {
    // Log error details once (not per field)
    if (kDebugMode && error is AuthException) {
      debugPrint('AuthError: ${error.statusCode} - ${error.message}');
    }

    // Handle network/connectivity errors
    if (error is SocketException || error is TimeoutException) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Handle Supabase auth errors
    if (error is AuthException) {
      return _handleSupabaseAuthError(error);
    }

    // Handle generic exceptions
    if (error is Exception) {
      return _handleGenericError(error);
    }

    // Fallback for unknown errors
    return 'An unexpected error occurred. Please try again.';
  }

  /// Handle Supabase-specific authentication errors
  String _handleSupabaseAuthError(AuthException error) {
    // Check for refresh_token_not_found (can appear in statusCode or message)
    final message = error.message.toLowerCase();
    final statusCode = (error.statusCode ?? '').toLowerCase();
    final isRefreshTokenMissing = statusCode == 'refresh_token_not_found' ||
        message.contains('refresh token not found') ||
        message.contains('refresh_token_not_found');

    if (isRefreshTokenMissing) {
      // Treat refresh_token_not_found as expected session expiration
      // This prevents confusing error messages when sessions naturally expire
      return 'Session expired. Please sign in again.';
    }

    switch (error.statusCode) {
      case 'invalid_credentials':
        return 'Invalid email or password. Please check your credentials and try again.';

      case 'email_not_confirmed':
        return 'Please verify your email address before signing in.';

      case 'signup_disabled':
        return 'New account registration is currently disabled.';

      case 'email_rate_limit_exceeded':
        return 'Too many requests. Please wait a moment and try again.';

      case 'user_not_found':
        return 'No account found with this email address.';

      case 'weak_password':
        return 'Password is too weak. Please use a stronger password.';

      case 'email_address_invalid':
        return 'Please enter a valid email address.';

      case 'user_already_registered':
        return 'An account with this email already exists. Please sign in instead.';

      default:
        // Don't expose internal error details
        return 'Authentication failed. Please try again.';
    }
  }

  /// Handle generic errors
  String _handleGenericError(Exception error) {
    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }

    if (errorMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return 'An error occurred. Please try again.';
  }

  /// Log error with context for debugging
  ///
  /// Logs errors according to security standards. In production, this should
  /// integrate with Sentry or similar error tracking service.
  void logError(Object error, StackTrace stackTrace,
      {Map<String, dynamic>? context}) {
    if (kDebugMode) {
      debugPrint('Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      if (context != null) {
        debugPrint('Context: $context');
      }
    }

    // In production, send to Sentry:
    // Sentry.captureException(
    //   error,
    //   stackTrace: stackTrace,
    //   hint: Hint.withMap(context ?? {}),
    // );
  }

  /// Check if device is offline
  Future<bool> isOffline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isEmpty || result[0].rawAddress.isEmpty;
    } catch (e) {
      return true;
    }
  }

  /// Handle offline scenarios with user-friendly messaging
  String getOfflineMessage() {
    return 'You appear to be offline. Please check your internet connection and try again.';
  }
}

/// Provider for auth error handler service
@riverpod
AuthErrorHandler authErrorHandler(AuthErrorHandlerRef ref) {
  return AuthErrorHandler();
}

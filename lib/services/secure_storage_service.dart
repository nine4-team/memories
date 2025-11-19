import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage items
class SecureStorageKeys {
  static const String accessToken = 'supabase_access_token';
  static const String refreshToken = 'supabase_refresh_token';
  static const String sessionExpiresAt = 'supabase_session_expires_at';
  static const String sessionJson = 'supabase_session_json'; // Full session JSON for biometrics
  static const String biometricEnabled = 'biometric_enabled';
  
  SecureStorageKeys._();
}

/// Service for managing secure storage of sensitive data
/// 
/// Uses flutter_secure_storage to persist session tokens and other
/// sensitive information securely on device. Never use SharedPreferences
/// for secrets per security standards.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Store access token securely
  Future<void> storeAccessToken(String token) async {
    await _storage.write(
      key: SecureStorageKeys.accessToken,
      value: token,
    );
  }

  /// Retrieve access token from secure storage
  Future<String?> getAccessToken() async {
    return await _storage.read(key: SecureStorageKeys.accessToken);
  }

  /// Store refresh token securely
  Future<void> storeRefreshToken(String token) async {
    await _storage.write(
      key: SecureStorageKeys.refreshToken,
      value: token,
    );
  }

  /// Retrieve refresh token from secure storage
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Store session expiration timestamp
  Future<void> storeSessionExpiresAt(DateTime expiresAt) async {
    await _storage.write(
      key: SecureStorageKeys.sessionExpiresAt,
      value: expiresAt.toIso8601String(),
    );
  }

  /// Retrieve session expiration timestamp
  Future<DateTime?> getSessionExpiresAt() async {
    final value = await _storage.read(key: SecureStorageKeys.sessionExpiresAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Store complete session data
  Future<void> storeSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await Future.wait([
      storeAccessToken(accessToken),
      storeRefreshToken(refreshToken),
      storeSessionExpiresAt(expiresAt),
    ]);
  }

  /// Clear all session data from secure storage
  /// 
  /// Called on logout or when session is invalidated
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: SecureStorageKeys.accessToken),
      _storage.delete(key: SecureStorageKeys.refreshToken),
      _storage.delete(key: SecureStorageKeys.sessionExpiresAt),
      _storage.delete(key: SecureStorageKeys.sessionJson),
    ]);
  }

  /// Check if a session exists in storage
  Future<bool> hasSession() async {
    final refreshToken = await getRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  /// Store biometric enabled preference
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: SecureStorageKeys.biometricEnabled,
      value: enabled.toString(),
    );
  }

  /// Retrieve biometric enabled preference
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: SecureStorageKeys.biometricEnabled);
    if (value == null) return false;
    return value == 'true';
  }

  /// Clear biometric preference (called when disabling biometrics)
  Future<void> clearBiometricPreference() async {
    await _storage.delete(key: SecureStorageKeys.biometricEnabled);
  }

  /// Store the full session JSON string (for biometric authentication)
  /// 
  /// This stores the exact serialized session JSON that Supabase creates,
  /// which can be used with setSession() instead of refreshSession().
  Future<void> storeSessionJson(String sessionJson) async {
    await _storage.write(
      key: SecureStorageKeys.sessionJson,
      value: sessionJson,
    );
  }

  /// Retrieve the full session JSON string
  Future<String?> getSessionJson() async {
    return await _storage.read(key: SecureStorageKeys.sessionJson);
  }

  /// Clear session JSON (called when clearing session)
  Future<void> clearSessionJson() async {
    await _storage.delete(key: SecureStorageKeys.sessionJson);
  }
}

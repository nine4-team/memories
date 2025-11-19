import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom LocalStorage implementation using FlutterSecureStorage
/// 
/// This provides secure storage for Supabase session data and enables
/// OAuth PKCE flow by implementing the LocalStorage interface that
/// Supabase uses for asyncStorage.
class SupabaseSecureStorage extends LocalStorage {
  final FlutterSecureStorage _storage;
  final String _persistSessionKey;

  SupabaseSecureStorage({
    String? persistSessionKey,
    FlutterSecureStorage? storage,
  })  : _persistSessionKey = persistSessionKey ?? supabasePersistSessionKey,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<void> initialize() async {
    // No initialization needed for FlutterSecureStorage
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _persistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: _persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(
      key: _persistSessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _persistSessionKey);
  }

  /// Read the full session JSON string from storage
  /// 
  /// This returns the complete session JSON that Supabase stores,
  /// which can be used with setSession() for biometric authentication flows.
  Future<String?> getSessionJson() async {
    return _storage.read(key: _persistSessionKey);
  }

  /// Check if a session JSON exists in storage
  Future<bool> hasSessionJson() async {
    return await _storage.containsKey(key: _persistSessionKey);
  }
}

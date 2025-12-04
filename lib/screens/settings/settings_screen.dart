import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/services/logout_service.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/widgets/profile_edit_form.dart';
import 'package:memories/widgets/password_change_widget.dart';
import 'package:memories/widgets/user_info_display.dart';
import 'package:memories/screens/settings/account_deletion_flow.dart';

/// Screen for managing user settings and profile
/// 
/// Provides:
/// - Account section: Profile editing, user info display
/// - Security section: Password change, biometric authentication
/// - Support section: Placeholder links
/// - Sign out functionality in AppBar
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoadingBiometric = false;
  bool? _biometricEnabled;
  bool? _biometricAvailable;
  String? _biometricTypeName;
  String? _biometricErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  Future<void> _loadBiometricSettings() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    final secureStorage = container.read(secureStorageServiceProvider);
    final biometricService = container.read(biometricServiceProvider);
    final supabase = container.read(supabaseClientProvider);

    try {
      // Check if biometrics are available
      final available = await biometricService.isAvailable();
      final typeName = available
          ? await biometricService.getAvailableBiometricTypeName()
          : null;

      // Check current enabled state from secure storage
      final enabled = await secureStorage.isBiometricEnabled();

      // Also check from Supabase profile for consistency
      final user = supabase.auth.currentUser;
      if (user != null) {
        try {
          final profileResponse = await supabase
              .from('profiles')
              .select('biometric_enabled')
              .eq('id', user.id)
              .single();

          final profileEnabled =
              profileResponse['biometric_enabled'] as bool? ?? false;

          // Sync: if profile says enabled but secure storage doesn't, update secure storage
          if (profileEnabled && !enabled) {
            await secureStorage.setBiometricEnabled(true);
          }

          if (mounted) {
            setState(() {
              _biometricEnabled = profileEnabled;
              _biometricAvailable = available;
              _biometricTypeName = typeName;
            });
          }
          return;
        } catch (e) {
          // If profile fetch fails, use secure storage value
        }
      }

      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
          _biometricAvailable = available;
          _biometricTypeName = typeName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricErrorMessage = 'Failed to load biometric settings';
        });
      }
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!mounted) return;
    setState(() {
      _isLoadingBiometric = true;
      _biometricErrorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final secureStorage = container.read(secureStorageServiceProvider);
      final biometricService = container.read(biometricServiceProvider);
      final supabase = container.read(supabaseClientProvider);

      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _biometricErrorMessage = 'You must be signed in to change this setting';
            _isLoadingBiometric = false;
          });
        }
        return;
      }

      if (enabled) {
        // Enable biometrics: authenticate first, then update settings
        final authenticated = await biometricService.authenticate(
          reason:
              'Enable ${_biometricTypeName ?? 'biometric authentication'} for quick access',
        );

        if (!authenticated) {
          if (mounted) {
            setState(() {
              _biometricErrorMessage =
                  'Biometric authentication failed. Please try again.';
              _isLoadingBiometric = false;
              _biometricEnabled = false;
            });
          }
          return;
        }

        // Update Supabase profile
        await supabase
            .from('profiles')
            .update({'biometric_enabled': true}).eq('id', user.id);

        // Update secure storage
        await secureStorage.setBiometricEnabled(true);
      } else {
        // Disable biometrics: clear secure storage and update profile
        await secureStorage.clearBiometricPreference();
        await secureStorage.clearSession(); // Clear session as per requirements

        // Update Supabase profile
        await supabase
            .from('profiles')
            .update({'biometric_enabled': false}).eq('id', user.id);
      }

      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
          _isLoadingBiometric = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final container = ProviderScope.containerOf(context);
        final errorHandler = container.read(authErrorHandlerProvider);
        setState(() {
          _biometricErrorMessage = errorHandler.handleAuthError(e);
          _isLoadingBiometric = false;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!context.mounted) return;

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);
      final secureStorage = container.read(secureStorageServiceProvider);
      
      final logoutService = LogoutService(supabase, secureStorage);
      await logoutService.logout();
      
      // Navigation will be handled by auth state provider
      // User will be routed to auth stack automatically
    } catch (e) {
      // Show error if logout fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              Semantics(
                label: 'Account settings section',
                header: true,
                child: Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // User Info Display
              const UserInfoDisplay(),
              const SizedBox(height: 24),
              
              // Profile Edit Form
              Semantics(
                label: 'Profile editing section',
                header: true,
                child: Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              const ProfileEditForm(),
              const SizedBox(height: 32),
              
              // Security Section
              Semantics(
                label: 'Security settings section',
                header: true,
                child: Text(
                  'Security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // Biometric authentication inline
              if (_biometricErrorMessage != null)
                Semantics(
                  label: 'Error message',
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _biometricErrorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              
              if (_biometricAvailable == null)
                const Center(child: CircularProgressIndicator())
              else if (!_biometricAvailable!)
                Semantics(
                  label: 'Biometric authentication not available',
                  child: Text(
                    'Biometric authentication is not available on this device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                Semantics(
                  label: 'Biometric authentication toggle',
                  child: SwitchListTile(
                    title: Text(
                      'Enable ${_biometricTypeName ?? 'Biometric'} Authentication',
                    ),
                    subtitle: Text(
                      'Use ${_biometricTypeName ?? 'biometric authentication'} to quickly and securely sign in',
                    ),
                    value: _biometricEnabled ?? false,
                    onChanged: _isLoadingBiometric
                        ? null
                        : (value) => _toggleBiometric(value),
                    secondary: Icon(
                      _biometricTypeName?.toLowerCase().contains('face') ?? false
                          ? Icons.face
                          : Icons.fingerprint,
                    ),
                  ),
                ),
              
              if (_isLoadingBiometric)
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Password Change
              Semantics(
                label: 'Password change section',
                header: true,
                child: Text(
                  'Change Password',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              const PasswordChangeWidget(),
              const SizedBox(height: 32),
              
              // Support Section
              Semantics(
                label: 'Support section',
                header: true,
                child: Text(
                  'Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              
              // Placeholder support links
              Semantics(
                label: 'Help and support',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help with your account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support coming soon'),
                      ),
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Privacy policy',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View our privacy policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon'),
                      ),
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Terms of service',
                button: true,
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  subtitle: const Text('View our terms of service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms of Service coming soon'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // Account Deletion Section
              Semantics(
                label: 'Account deletion section',
                header: true,
                child: Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              
              Semantics(
                label: 'Delete account',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AccountDeletionFlow(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


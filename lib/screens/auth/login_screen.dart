import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/providers/main_navigation_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/google_oauth_service.dart';
import 'package:memories/widgets/biometric_prompt_widget.dart';

/// Screen for user login with email and password or Google OAuth
///
/// Provides:
/// - Email/password login form
/// - "Forgot password?" link to password reset
/// - Google OAuth button
/// - Error handling and display
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final supabase = container.read(supabaseClientProvider);

      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Show biometric prompt after successful login if not already enabled
      if (response.user != null && mounted) {
        final secureStorage = container.read(secureStorageServiceProvider);
        final alreadyEnabled = await secureStorage.isBiometricEnabled();

        if (!alreadyEnabled) {
          // Show biometric prompt dialog
          await BiometricPromptWidget.showPrompt(
            context,
            user: response.user!,
            secureStorage: secureStorage,
          );
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response.user != null) {
        final navigationNotifier =
            container.read(mainNavigationTabNotifierProvider.notifier);
        navigationNotifier.switchToCapture();
      }

      // Navigation will be handled by auth state provider
      // User will be routed based on verification and onboarding status
    } catch (e) {
      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      setState(() {
        _errorMessage = errorHandler.handleAuthError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final googleOAuth = container.read(googleOAuthServiceProvider);
      await googleOAuth.signIn();
      // Navigation will be handled by auth state provider
    } catch (e) {
      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      setState(() {
        _errorMessage = errorHandler.handleAuthError(e);
        _isLoading = false;
      });
    }
  }

  void _navigateToPasswordReset() {
    Navigator.of(context).pushNamed('/password-reset');
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Email field
                Semantics(
                  label: 'Email input field',
                  textField: true,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                    autofocus: true,
                    autofillHints: const [AutofillHints.email],
                  ),
                ),
                const SizedBox(height: 16),
                // Password field
                Semantics(
                  label: 'Password input field',
                  textField: true,
                  obscured: _obscurePassword,
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                ),
                const SizedBox(height: 8),
                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    label: 'Forgot password link',
                    button: true,
                    child: TextButton(
                      onPressed: _navigateToPasswordReset,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Error message
                if (_errorMessage != null)
                  Semantics(
                    label: 'Error message',
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),
                // Sign in button
                Semantics(
                  label: 'Sign in button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 16),
                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                // Google OAuth button
                Semantics(
                  label: 'Continue with Google button',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Semantics(
                      label: 'Navigate to sign up screen',
                      button: true,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/signup');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/google_oauth_service.dart';

/// Screen for user signup with email and password
///
/// Provides form validation for:
/// - Email format
/// - Name (required, non-empty)
/// - Password strength (≥8 chars, mixed characters)
///
/// Also includes Google OAuth signup option.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
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

      // Sign up with email and password
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'name': _nameController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      if (response.user != null) {
        // Surface helpful feedback so users know to check their inbox
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check your email to verify your account. You can sign in once it is confirmed.',
            ),
          ),
        );
      }
    } catch (e) {
      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      if (mounted) {
        setState(() {
          _errorMessage = errorHandler.handleAuthError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('Starting Google OAuth signup...');
      debugPrint('═══════════════════════════════════════════════════════');

      final container = ProviderScope.containerOf(context);
      final googleOAuth = container.read(googleOAuthServiceProvider);
      await googleOAuth.signIn();

      debugPrint('✓ OAuth signIn() completed - Safari should have opened');
      debugPrint('  Waiting for OAuth callback via deep link...');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('');

      // Browser opened successfully - reset loading state
      // The OAuth flow will continue in the browser and return via deep link
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Navigation will be handled by auth state provider when OAuth completes
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('ERROR in Google OAuth signup:');
      debugPrint('  $e');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('');

      final container = ProviderScope.containerOf(context);
      final errorHandler = container.read(authErrorHandlerProvider);
      errorHandler.logError(e, stackTrace);

      if (mounted) {
        setState(() {
          _errorMessage = errorHandler.handleAuthError(e);
          _isLoading = false;
        });
      }
    }
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

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    // Check for mixed characters (at least one letter and one number)
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Password must contain both letters and numbers';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
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
                // Name field
                Semantics(
                  label: 'Name input field',
                  textField: true,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter your name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                    autofocus: true,
                  ),
                ),
                const SizedBox(height: 16),
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
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _handleSignup(),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label:
                      'Password requirements: at least 8 characters with both letters and numbers',
                  child: Text(
                    'Password must be at least 8 characters with both letters and numbers',
                    style: Theme.of(context).textTheme.bodySmall,
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
                // Sign up button
                Semantics(
                  label: 'Sign up button',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
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
                        : const Text('Sign Up'),
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
                    onPressed: _isLoading ? null : _handleGoogleSignup,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Semantics(
                      label: 'Navigate to sign in screen',
                      button: true,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                        child: const Text('Sign In'),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memories/providers/supabase_provider.dart';

/// Widget for displaying read-only user information
///
/// Shows:
/// - Email address (from auth.users)
/// - Last sign-in timestamp
/// - Profile name (from profiles table)
/// - Account creation date (optional)
class UserInfoDisplay extends ConsumerStatefulWidget {
  const UserInfoDisplay({super.key});

  @override
  ConsumerState<UserInfoDisplay> createState() => _UserInfoDisplayState();
}

class _UserInfoDisplayState extends ConsumerState<UserInfoDisplay> {
  String? _profileName;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  StreamSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToAuthStateChanges();
    _loadProfileInfo();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToAuthStateChanges() {
    final supabase = ref.read(supabaseClientProvider);
    _authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      final newUserId = session != null ? session.user.id : null;
      if (newUserId != _currentUserId) {
        _currentUserId = newUserId;
        if (newUserId == null) {
          if (mounted) {
            setState(() {
              _profileName = null;
              _isLoading = false;
              _errorMessage = null;
            });
          }
        } else {
          _loadProfileInfo();
        }
      }
    });
  }

  Future<void> _loadProfileInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _profileName = null;
          _isLoading = false;
        });
        return;
      }

      _currentUserId = user.id;

      final profileResponse = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        _profileName = profileResponse['name'] as String?;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load profile information: $error');
      if (!mounted) return;
      setState(() {
        _profileName = null;
        _isLoading = false;
        _errorMessage = 'Failed to load profile information';
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Never';

    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = ref.read(supabaseClientProvider);
    final user = supabase.auth.currentUser;

    if (user == null) {
      return Semantics(
        label: 'User information not available',
        child: Text(
          'Not signed in',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Error loading user information',
            liveRegion: true,
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _loadProfileInfo,
            child: const Text('Retry loading profile'),
          ),
        ],
      );
    }

    return Semantics(
      label: 'User account information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email (read-only)
          Semantics(
            label: 'Email address',
            child: _InfoRow(
              label: 'Email',
              value: user.email ?? 'Not available',
            ),
          ),
          const SizedBox(height: 16),

          // Profile name
          if (_profileName != null) ...[
            Semantics(
              label: 'Profile name',
              child: _InfoRow(
                label: 'Name',
                value: _profileName!,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Last sign-in
          Semantics(
            label: 'Last sign-in timestamp',
            child: _InfoRow(
              label: 'Last sign-in',
              value: _formatDate(user.lastSignInAt),
            ),
          ),

          // Account creation date
          const SizedBox(height: 16),
          Semantics(
            label: 'Account creation date',
            child: _InfoRow(
              label: 'Account created',
              value: _formatDate(user.createdAt),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

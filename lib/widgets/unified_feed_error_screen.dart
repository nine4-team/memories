import 'package:flutter/material.dart';

/// Full-page error screen for initial load failures
///
/// Displays a full-screen error with retry button when the initial
/// feed load fails. Provides messaging about offline availability.
class UnifiedFeedErrorScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final bool isOffline;

  const UnifiedFeedErrorScreen({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Error loading memories',
      hint: errorMessage,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Error icon',
                excludeSemantics: true,
                child: Icon(
                  isOffline ? Icons.cloud_off : Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  isOffline ? 'You\'re offline' : 'Failed to load memories',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                child: Text(
                  errorMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isOffline) ...[
                const SizedBox(height: 8),
                Semantics(
                  child: Text(
                    'Showing cached content if available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Semantics(
                label: 'Retry loading memories',
                button: true,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

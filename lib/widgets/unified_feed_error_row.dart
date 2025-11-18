import 'package:flutter/material.dart';

/// Inline error row for pagination failures
///
/// Displays an error message with a retry button when pagination fails.
/// Keeps existing content visible while showing the error.
class UnifiedFeedErrorRow extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const UnifiedFeedErrorRow({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Error loading more memories',
      hint: errorMessage,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              label: 'Retry loading more memories',
              button: true,
              child: TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

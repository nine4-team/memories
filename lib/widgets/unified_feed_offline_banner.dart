import 'package:flutter/material.dart';

/// Offline banner for unified feed
///
/// Displays a banner at the top of the feed when the device is offline,
/// explaining that cached content is being shown and refresh is disabled.
class UnifiedFeedOfflineBanner extends StatelessWidget {
  const UnifiedFeedOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Offline mode - showing cached content',
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.errorContainer,
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline - Showing cached content',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/search_result.dart';
import 'package:memories/models/memory_type.dart';

/// Card widget for displaying a single search result
/// 
/// Shows:
/// - Title with memory type badge
/// - Snippet text with query term highlighting
/// - Optional metadata (date)
/// - Tap to navigate to detail screen
class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memoryType = _getMemoryType(result.memoryType);

    // Build semantic label
    final semanticLabel = StringBuffer('${memoryType.displayName}');
    if (result.title.isNotEmpty) {
      semanticLabel.write(' titled ${result.title}');
    }
    semanticLabel.write(' created ${_formatRelativeDate(result.createdAt)}');
    if (result.snippetText != null && result.snippetText!.isNotEmpty) {
      semanticLabel.write('. ${result.snippetText}');
    }

    return Semantics(
      label: semanticLabel.toString(),
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 44,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Memory type badge and title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Memory type badge
                      Semantics(
                        label: '${memoryType.displayName} badge',
                        excludeSemantics: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            memoryType.displayName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title - single line, ellipsized
                      Expanded(
                        child: Text(
                          result.title.isNotEmpty
                              ? result.title
                              : 'Untitled ${memoryType.displayName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Snippet text with highlighting
                  if (result.snippetText != null &&
                      result.snippetText!.isNotEmpty)
                    _buildHighlightedSnippet(
                      context,
                      result.snippetText!,
                      query,
                    ),
                  const SizedBox(height: 8),
                  // Metadata row (date)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRelativeDate(result.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build snippet text with highlighted query terms
  Widget _buildHighlightedSnippet(
    BuildContext context,
    String snippet,
    String query,
  ) {
    if (query.isEmpty) {
      return Text(
        snippet,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Split query into individual terms (simple word splitting)
    final queryTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    if (queryTerms.isEmpty) {
      return Text(
        snippet,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Build text spans with highlighting
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    final snippetLower = snippet.toLowerCase();
    int lastIndex = 0;

    // Find all matches and create spans
    for (final term in queryTerms) {
      int searchIndex = lastIndex;
      while (true) {
        final matchIndex = snippetLower.indexOf(term, searchIndex);
        if (matchIndex == -1) break;

        // Add text before match
        if (matchIndex > lastIndex) {
          spans.add(TextSpan(
            text: snippet.substring(lastIndex, matchIndex),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ));
        }

        // Add highlighted match
        final matchEnd = matchIndex + term.length;
        spans.add(TextSpan(
          text: snippet.substring(matchIndex, matchEnd),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
          ),
        ));

        lastIndex = matchEnd;
        searchIndex = matchEnd;
      }
    }

    // Add remaining text
    if (lastIndex < snippet.length) {
      spans.add(TextSpan(
        text: snippet.substring(lastIndex),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    }

    // If no matches found, return plain text
    if (spans.isEmpty) {
      return Text(
        snippet,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Get MemoryType from string
  MemoryType _getMemoryType(String memoryType) {
    return MemoryTypeExtension.fromApiValue(memoryType);
  }

  /// Format relative date (e.g., "Today", "Yesterday", "3d ago", "2w ago")
  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}


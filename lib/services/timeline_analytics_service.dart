import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for timeline events
/// 
/// Tracks user interactions, scroll depth, search queries, and errors.
/// Events can be sent to analytics platforms (e.g., Sentry, Firebase Analytics).
class TimelineAnalyticsService {
  /// Track scroll depth milestone
  /// 
  /// [depth] is the percentage scrolled (0-100)
  /// [momentCount] is the number of moments loaded so far
  void trackScrollDepth(int depth, int momentCount) {
    // Track milestones: 25%, 50%, 75%, 100%
    if (depth >= 25 && depth < 50) {
      _logEvent('timeline_scroll_depth_25', {
        'depth': depth,
        'moment_count': momentCount,
      });
    } else if (depth >= 50 && depth < 75) {
      _logEvent('timeline_scroll_depth_50', {
        'depth': depth,
        'moment_count': momentCount,
      });
    } else if (depth >= 75 && depth < 100) {
      _logEvent('timeline_scroll_depth_75', {
        'depth': depth,
        'moment_count': momentCount,
      });
    } else if (depth >= 100) {
      _logEvent('timeline_scroll_depth_100', {
        'depth': depth,
        'moment_count': momentCount,
      });
    }
  }

  /// Track search query (hashed for privacy)
  /// 
  /// [query] is the search query text (will be hashed)
  /// [resultCount] is the number of results returned
  void trackSearchQuery(String query, int resultCount) {
    final hashedQuery = _hashQuery(query);
    _logEvent('timeline_search', {
      'query_hash': hashedQuery,
      'query_length': query.length,
      'result_count': resultCount,
    });
  }

  /// Track moment card tap
  /// 
  /// [momentId] is the ID of the moment tapped
  /// [position] is the position in the list (0-indexed)
  /// [hasMedia] indicates if the moment has media
  void trackMomentCardTap(String momentId, int position, bool hasMedia) {
    _logEvent('timeline_moment_tap', {
      'moment_id': momentId,
      'position': position,
      'has_media': hasMedia,
    });
  }

  /// Track timeline error
  /// 
  /// [error] is the error message or exception
  /// [errorType] is the type of error (e.g., 'network', 'parse', 'unknown')
  /// [context] is additional context about where the error occurred
  void trackError(Object error, String errorType, {Map<String, dynamic>? context}) {
    _logEvent('timeline_error', {
      'error_type': errorType,
      'error_message': error.toString(),
      if (context != null) ...context,
    });

    // In production, send to Sentry:
    // Sentry.captureException(
    //   error,
    //   hint: Hint.withMap({
    //     'error_type': errorType,
    //     if (context != null) ...context,
    //   }),
    // );
  }

  /// Track pagination event
  /// 
  /// [pageNumber] is the page number (1-indexed)
  /// [batchSize] is the number of items loaded
  /// [latencyMs] is the time taken to load in milliseconds
  void trackPagination(int pageNumber, int batchSize, int latencyMs) {
    _logEvent('timeline_pagination', {
      'page_number': pageNumber,
      'batch_size': batchSize,
      'latency_ms': latencyMs,
    });
  }

  /// Track pull-to-refresh
  void trackPullToRefresh() {
    _logEvent('timeline_pull_to_refresh', {});
  }

  /// Track search clear action
  void trackSearchClear() {
    _logEvent('timeline_search_clear', {});
  }

  /// Hash a search query for privacy
  /// 
  /// Uses SHA-256 to create a consistent hash of the query
  String _hashQuery(String query) {
    final bytes = utf8.encode(query.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Log an analytics event
  /// 
  /// In debug mode, prints to console. In production, can be extended
  /// to send to analytics platforms.
  void _logEvent(String eventName, Map<String, dynamic> properties) {
    if (kDebugMode) {
      debugPrint('Analytics: $eventName');
      debugPrint('Properties: $properties');
    }

    // In production, send to analytics platform:
    // FirebaseAnalytics.instance.logEvent(
    //   name: eventName,
    //   parameters: properties,
    // );
    // 
    // Or send to Sentry:
    // Sentry.addBreadcrumb(
    //   Breadcrumb(
    //     message: eventName,
    //     data: properties,
    //     category: 'analytics',
    //   ),
    // );
  }
}



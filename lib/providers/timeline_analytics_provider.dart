import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/timeline_analytics_service.dart';

part 'timeline_analytics_provider.g.dart';

/// Provider for timeline analytics service
@riverpod
TimelineAnalyticsService timelineAnalyticsService(TimelineAnalyticsServiceRef ref) {
  return TimelineAnalyticsService();
}


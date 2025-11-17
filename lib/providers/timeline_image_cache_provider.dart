import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/timeline_image_cache_service.dart';

part 'timeline_image_cache_provider.g.dart';

/// Provider for timeline image cache service
@riverpod
TimelineImageCacheService timelineImageCacheService(TimelineImageCacheServiceRef ref) {
  return TimelineImageCacheService();
}


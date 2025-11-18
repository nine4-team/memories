import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/unified_feed_tab_persistence_service.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';

part 'unified_feed_tab_provider.g.dart';

/// Provider for unified feed tab persistence service
@riverpod
UnifiedFeedTabPersistenceService unifiedFeedTabPersistenceService(
    UnifiedFeedTabPersistenceServiceRef ref) {
  return UnifiedFeedTabPersistenceService();
}

/// Provider for the selected tab in unified feed
/// 
/// Manages the current filter selection and persists it to SharedPreferences.
/// null represents 'all' (no filter).
@riverpod
class UnifiedFeedTabNotifier extends _$UnifiedFeedTabNotifier {
  @override
  Future<MemoryType?> build() async {
    // Restore last selected tab on init
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    return await service.getLastSelectedTab();
  }

  /// Set the selected tab and persist it
  /// 
  /// [tab] is the memory type filter (null for 'all')
  Future<void> setTab(MemoryType? tab) async {
    final previousTab = state.valueOrNull;
    state = AsyncValue.data(tab);
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    await service.saveLastSelectedTab(tab);
    
    // Track tab switch analytics
    ref.read(timelineAnalyticsServiceProvider).trackUnifiedFeedTabSwitch(
      previousTab,
      tab,
    );
  }

  /// Clear the saved tab (resets to 'all')
  Future<void> clearTab() async {
    state = const AsyncValue.data(null);
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    await service.clearSavedTab();
  }
}


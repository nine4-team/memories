import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memories/providers/unified_feed_tab_provider.dart';
import 'package:memories/models/memory_type.dart';

void main() {
  group('UnifiedFeedTabNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with null (all) when no saved tab exists', () async {
      final notifier = container.read(unifiedFeedTabNotifierProvider.notifier);
      await notifier.build();

      final state = container.read(unifiedFeedTabNotifierProvider);
      expect(state.valueOrNull, null);
    });

    test('restores last selected tab on initialization', () async {
      // Save a tab preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('unified_feed_last_selected_tab', 'story');

      // Create new container to trigger initialization
      container.dispose();
      container = ProviderContainer();

      final state = await container.read(unifiedFeedTabNotifierProvider.future);
      expect(state, MemoryType.story);
    });

    test('setTab updates state and persists to SharedPreferences', () async {
      final notifier = container.read(unifiedFeedTabNotifierProvider.notifier);
      await notifier.build();

      await notifier.setTab(MemoryType.moment);

      final state = container.read(unifiedFeedTabNotifierProvider);
      expect(state.valueOrNull, MemoryType.moment);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString('unified_feed_last_selected_tab');
      expect(savedTab, 'moment');
    });

    test('setTab with null saves as "all"', () async {
      final notifier = container.read(unifiedFeedTabNotifierProvider.notifier);
      await notifier.build();

      // First set a tab
      await notifier.setTab(MemoryType.story);

      // Then set to null (all)
      await notifier.setTab(null);

      final state = container.read(unifiedFeedTabNotifierProvider);
      expect(state.valueOrNull, null);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString('unified_feed_last_selected_tab');
      expect(savedTab, 'all');
    });

    test('clearTab resets to null and clears SharedPreferences', () async {
      final notifier = container.read(unifiedFeedTabNotifierProvider.notifier);
      await notifier.build();

      // Set a tab first
      await notifier.setTab(MemoryType.memento);

      // Clear it
      await notifier.clearTab();

      final state = container.read(unifiedFeedTabNotifierProvider);
      expect(state.valueOrNull, null);

      // Verify SharedPreferences is cleared
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getString('unified_feed_last_selected_tab');
      expect(savedTab, null);
    });

    test('handles all memory types correctly', () async {
      final notifier = container.read(unifiedFeedTabNotifierProvider.notifier);
      await notifier.build();

      for (final memoryType in MemoryType.values) {
        await notifier.setTab(memoryType);
        final state = container.read(unifiedFeedTabNotifierProvider);
        expect(state.valueOrNull, memoryType);

        // Verify persistence
        final prefs = await SharedPreferences.getInstance();
        final savedTab = prefs.getString('unified_feed_last_selected_tab');
        expect(savedTab, memoryType.apiValue);
      }
    });
  });
}

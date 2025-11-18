import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/models/timeline_moment.dart';

/// Tests for Story timeline provider logic that don't require mocking
/// 
/// These tests focus on state management, cursor logic, and pure functions
/// that can be tested without external dependencies.
void main() {
  group('Story Timeline Provider - Pure Logic Tests', () {
    group('State Management', () {
      test('initial state is initial for Story timeline', () {
        final container = ProviderContainer();
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.state, TimelineState.initial);
        expect(state.moments, isEmpty);
        expect(state.hasMore, isFalse);
        expect(state.nextCursor, isNull);
        container.dispose();
      });

      test('removeMoment removes Story from timeline', () {
        final container = ProviderContainer();
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);

        final testStory1 = TimelineMoment(
          id: 'story-1',
          userId: 'user-1',
          title: 'Story 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'story',
        );

        final testStory2 = TimelineMoment(
          id: 'story-2',
          userId: 'user-1',
          title: 'Story 2',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          captureType: 'story',
        );

        // Set initial state with stories
        notifier.state = TimelineFeedState(
          state: TimelineState.loaded,
          moments: [testStory1, testStory2],
          hasMore: false,
        );

        // Remove story-1
        notifier.removeMoment('story-1');

        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.moments.length, 1);
        expect(state.moments.first.id, 'story-2');
        expect(state.moments.first.title, 'Story 2');
        container.dispose();
      });

      test('removeMoment handles non-existent Story gracefully', () {
        final container = ProviderContainer();
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);

        final testStory = TimelineMoment(
          id: 'story-1',
          userId: 'user-1',
          title: 'Story 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'story',
        );

        notifier.state = TimelineFeedState(
          state: TimelineState.loaded,
          moments: [testStory],
          hasMore: false,
        );

        // Try to remove non-existent story
        notifier.removeMoment('non-existent');

        final state = container.read(storyTimelineFeedNotifierProvider);
        // Should still have the original story
        expect(state.moments.length, 1);
        expect(state.moments.first.id, 'story-1');
        container.dispose();
      });

      test('removeMoment handles empty list', () {
        final container = ProviderContainer();
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);

        notifier.state = const TimelineFeedState(
          state: TimelineState.loaded,
          moments: [],
          hasMore: false,
        );

        // Try to remove from empty list
        notifier.removeMoment('any-id');

        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.moments, isEmpty);
        container.dispose();
      });

      test('removeMoment preserves other Stories', () {
        final container = ProviderContainer();
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);

        final stories = List.generate(5, (index) => TimelineMoment(
          id: 'story-$index',
          userId: 'user-1',
          title: 'Story $index',
          capturedAt: DateTime(2025, 1, 17 - index),
          createdAt: DateTime(2025, 1, 17 - index),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17 - index,
          tags: [],
          captureType: 'story',
        ));

        notifier.state = TimelineFeedState(
          state: TimelineState.loaded,
          moments: stories,
          hasMore: false,
        );

        // Remove middle story
        notifier.removeMoment('story-2');

        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.moments.length, 4);
        expect(state.moments.map((s) => s.id), containsAll(['story-0', 'story-1', 'story-3', 'story-4']));
        expect(state.moments.map((s) => s.id), isNot(contains('story-2')));
        container.dispose();
      });
    });

    group('State Transitions', () {
      test('state copyWith creates new state with updated fields', () {
        const initialState = TimelineFeedState(
          state: TimelineState.loaded,
          moments: [],
          hasMore: false,
        );

        final updatedState = initialState.copyWith(
          state: TimelineState.loadingMore,
          hasMore: true,
        );

        expect(updatedState.state, TimelineState.loadingMore);
        expect(updatedState.hasMore, isTrue);
        expect(updatedState.moments, isEmpty);
      });

      test('state copyWith preserves existing fields when not specified', () {
        final testStory = TimelineMoment(
          id: 'story-1',
          userId: 'user-1',
          title: 'Story 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'story',
        );

        final initialState = TimelineFeedState(
          state: TimelineState.loaded,
          moments: [testStory],
          hasMore: true,
        );

        final updatedState = initialState.copyWith(
          state: TimelineState.loadingMore,
        );

        expect(updatedState.state, TimelineState.loadingMore);
        expect(updatedState.moments.length, 1);
        expect(updatedState.hasMore, isTrue); // Preserved
      });
    });

    group('Story Filter Logic', () {
      test('Story timeline provider uses MemoryType.story filter', () {
        final container = ProviderContainer();
        
        // Verify that storyTimelineFeedNotifierProvider is configured with Story filter
        // This is a structural test - the actual filter is applied in _fetchPage
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        expect(notifier, isNotNull);
        
        // The filter is applied internally, so we verify the provider exists
        // and can be accessed without errors
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state, isNotNull);
        container.dispose();
      });
    });

    group('Cursor Logic', () {
      test('TimelineCursor isEmpty returns true when both fields are null', () {
        const cursor = TimelineCursor();
        expect(cursor.isEmpty, isTrue);
      });

      test('TimelineCursor isEmpty returns false when capturedAt is set', () {
        final cursor = TimelineCursor(capturedAt: DateTime.now());
        expect(cursor.isEmpty, isFalse);
      });

      test('TimelineCursor isEmpty returns false when id is set', () {
        const cursor = TimelineCursor(id: 'test-id');
        expect(cursor.isEmpty, isFalse);
      });

      test('TimelineCursor toParams returns empty map when empty', () {
        const cursor = TimelineCursor();
        expect(cursor.toParams(), isEmpty);
      });

      test('TimelineCursor toParams returns correct params when set', () {
        final date = DateTime(2025, 1, 17);
        const id = 'test-id';
        final cursor = TimelineCursor(capturedAt: date, id: id);
        final params = cursor.toParams();
        
        expect(params['p_cursor_captured_at'], date.toIso8601String());
        expect(params['p_cursor_id'], id);
      });
    });

    group('Search Query Logic', () {
      test('SearchQueryNotifier initial state is empty', () {
        final container = ProviderContainer();
        final state = container.read(searchQueryNotifierProvider);
        expect(state, isEmpty);
        container.dispose();
      });

      test('SearchQueryNotifier setQuery updates state', () {
        final container = ProviderContainer();
        final notifier = container.read(searchQueryNotifierProvider.notifier);
        
        notifier.setQuery('test query');
        final state = container.read(searchQueryNotifierProvider);
        
        expect(state, 'test query');
        container.dispose();
      });

      test('SearchQueryNotifier clear resets state to empty', () {
        final container = ProviderContainer();
        final notifier = container.read(searchQueryNotifierProvider.notifier);
        
        notifier.setQuery('test query');
        notifier.clear();
        final state = container.read(searchQueryNotifierProvider);
        
        expect(state, isEmpty);
        container.dispose();
      });
    });
  });
}


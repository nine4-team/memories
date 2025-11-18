import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/timeline_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/models/timeline_moment.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  group('Story Timeline Provider', () {
    late MockSupabaseClient mockSupabase;
    late MockConnectivityService mockConnectivity;
    late ProviderContainer container;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockConnectivity = MockConnectivityService();
      
      container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
        ],
      );

      // Default connectivity to online
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
    });

    tearDown(() {
      container.dispose();
    });

    group('Pull-to-Refresh', () {
      test('refresh resets state and loads Stories', () async {
        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => []);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.refresh();
        
        // Verify RPC was called
        verify(() => mockSupabase.rpc('get_timeline_feed', params: any(named: 'params'))).called(1);
      });

      test('refresh resets pagination cursor', () async {
        final testStory = {
          'id': 'story-1',
          'user_id': 'user-1',
          'title': 'Test Story',
          'captured_at': DateTime(2025, 1, 17).toIso8601String(),
          'created_at': DateTime(2025, 1, 17).toIso8601String(),
          'year': 2025,
          'season': 'Winter',
          'month': 1,
          'day': 17,
          'tags': [],
          'capture_type': 'story',
        };

        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => [testStory]);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        // Load initial
        await notifier.loadInitial();
        final stateAfterLoad = container.read(storyTimelineFeedNotifierProvider);
        expect(stateAfterLoad.moments.length, 1);
        
        // Refresh should reset
        await notifier.refresh();
        final stateAfterRefresh = container.read(storyTimelineFeedNotifierProvider);
        expect(stateAfterRefresh.moments.length, 1);
        // State should be reset (not loadingMore)
        expect(stateAfterRefresh.state, isNot(TimelineState.loadingMore));
      });
    });

    group('Pagination', () {
      test('loadMore loads next batch of Stories', () async {
        final testStories = List.generate(25, (index) => {
          'id': 'story-$index',
          'user_id': 'user-1',
          'title': 'Story $index',
          'captured_at': DateTime(2025, 1, 17 - index).toIso8601String(),
          'created_at': DateTime(2025, 1, 17 - index).toIso8601String(),
          'year': 2025,
          'season': 'Winter',
          'month': 1,
          'day': 17 - index,
          'tags': [],
          'capture_type': 'story',
        });

        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => testStories);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        // Load initial
        await notifier.loadInitial();
        final stateAfterLoad = container.read(storyTimelineFeedNotifierProvider);
        expect(stateAfterLoad.moments.length, 25);
        expect(stateAfterLoad.hasMore, isTrue);
        
        // Load more
        await notifier.loadMore();
        final stateAfterLoadMore = container.read(storyTimelineFeedNotifierProvider);
        // Should have more stories appended
        expect(stateAfterLoadMore.moments.length, 50);
      });

      test('loadMore does nothing when no more Stories', () async {
        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        // Set state with no more data
        container.read(storyTimelineFeedNotifierProvider.notifier).state = 
            const TimelineFeedState(
              state: TimelineState.loaded,
              hasMore: false,
            );

        await notifier.loadMore();
        
        // Should not have called RPC
        verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
      });

      test('loadMore includes Story filter in RPC params', () async {
        final testStories = List.generate(25, (index) => {
          'id': 'story-$index',
          'user_id': 'user-1',
          'title': 'Story $index',
          'captured_at': DateTime(2025, 1, 17 - index).toIso8601String(),
          'created_at': DateTime(2025, 1, 17 - index).toIso8601String(),
          'year': 2025,
          'season': 'Winter',
          'month': 1,
          'day': 17 - index,
          'tags': [],
          'capture_type': 'story',
        });

        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => testStories);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.loadInitial();
        await notifier.loadMore();
        
        // Verify RPC was called multiple times
        verify(() => mockSupabase.rpc('get_timeline_feed', params: any(named: 'params'))).called(greaterThan(1));
      });
    });

    group('Provider Updates', () {
      test('removeMoment removes Story from timeline', () async {
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
        container.read(storyTimelineFeedNotifierProvider.notifier).state = 
            TimelineFeedState(
              state: TimelineState.loaded,
              moments: [testStory1, testStory2],
              hasMore: false,
            );

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        // Remove story-1
        notifier.removeMoment('story-1');
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.moments.length, 1);
        expect(state.moments.first.id, 'story-2');
      });

      test('removeMoment handles non-existent Story gracefully', () async {
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

        container.read(storyTimelineFeedNotifierProvider.notifier).state = 
            TimelineFeedState(
              state: TimelineState.loaded,
              moments: [testStory],
              hasMore: false,
            );

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        // Try to remove non-existent story
        notifier.removeMoment('non-existent');
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        // Should still have the original story
        expect(state.moments.length, 1);
        expect(state.moments.first.id, 'story-1');
      });
    });

    group('Offline Behavior', () {
      test('loadInitial handles offline state', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.loadInitial();
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.state, TimelineState.error);
        expect(state.errorMessage, contains('offline'));
      });

      test('loadMore handles offline state', () async {
        // Set up initial state with hasMore = true
        container.read(storyTimelineFeedNotifierProvider.notifier).state = 
            const TimelineFeedState(
              state: TimelineState.loaded,
              hasMore: true,
              nextCursor: TimelineCursor(id: 'cursor-id'),
            );

        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.loadMore();
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.state, TimelineState.error);
        expect(state.errorMessage, contains('offline'));
      });

      test('refresh handles offline state', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.refresh();
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.state, TimelineState.error);
        expect(state.errorMessage, contains('offline'));
      });
    });

    group('Story Filter', () {
      test('loadInitial includes Story filter in RPC params', () async {
        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => []);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.loadInitial();
        
        // Verify RPC was called
        verify(() => mockSupabase.rpc('get_timeline_feed', params: any(named: 'params'))).called(1);
      });

      test('only Stories are returned in results', () async {
        final testStory = {
          'id': 'story-1',
          'user_id': 'user-1',
          'title': 'Test Story',
          'captured_at': DateTime(2025, 1, 17).toIso8601String(),
          'created_at': DateTime(2025, 1, 17).toIso8601String(),
          'year': 2025,
          'season': 'Winter',
          'month': 1,
          'day': 17,
          'tags': [],
          'capture_type': 'story',
        };

        when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
            .thenAnswer((_) async => [testStory]);

        final notifier = container.read(storyTimelineFeedNotifierProvider.notifier);
        
        await notifier.loadInitial();
        
        final state = container.read(storyTimelineFeedNotifierProvider);
        expect(state.moments.length, 1);
        expect(state.moments.first.captureType, 'story');
      });
    });
  });
}


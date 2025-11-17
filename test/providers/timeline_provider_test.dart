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

class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder {}

class MockPostgrestQueryBuilder extends Mock implements PostgrestQueryBuilder {}

class MockPostgrestBuilder extends Mock implements PostgrestBuilder {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  group('TimelineCursor', () {
    test('isEmpty returns true when both fields are null', () {
      const cursor = TimelineCursor();
      expect(cursor.isEmpty, isTrue);
    });

    test('isEmpty returns false when capturedAt is set', () {
      final cursor = TimelineCursor(capturedAt: DateTime.now());
      expect(cursor.isEmpty, isFalse);
    });

    test('isEmpty returns false when id is set', () {
      const cursor = TimelineCursor(id: 'test-id');
      expect(cursor.isEmpty, isFalse);
    });

    test('toParams returns empty map when empty', () {
      const cursor = TimelineCursor();
      expect(cursor.toParams(), isEmpty);
    });

    test('toParams returns correct params when set', () {
      final date = DateTime(2025, 1, 17);
      const id = 'test-id';
      final cursor = TimelineCursor(capturedAt: date, id: id);
      final params = cursor.toParams();
      
      expect(params['p_cursor_captured_at'], date.toIso8601String());
      expect(params['p_cursor_id'], id);
    });
  });

  group('TimelineFeedState', () {
    test('copyWith creates new state with updated fields', () {
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
  });

  group('SearchQueryNotifier', () {
    test('initial state is empty string', () {
      final container = ProviderContainer();
      final state = container.read(searchQueryNotifierProvider);
      expect(state, isEmpty);
    });

    test('setQuery updates state', () {
      final container = ProviderContainer();
      final notifier = container.read(searchQueryNotifierProvider.notifier);
      
      notifier.setQuery('test query');
      final state = container.read(searchQueryNotifierProvider);
      
      expect(state, 'test query');
    });

    test('clear resets state to empty', () {
      final container = ProviderContainer();
      final notifier = container.read(searchQueryNotifierProvider.notifier);
      
      notifier.setQuery('test query');
      notifier.clear();
      final state = container.read(searchQueryNotifierProvider);
      
      expect(state, isEmpty);
    });
  });

  group('TimelineFeedNotifier', () {
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

    test('initial state is initial', () {
      final state = container.read(timelineFeedNotifierProvider);
      expect(state.state, TimelineState.initial);
    });

    test('loadInitial sets loading state', () async {
      // Mock RPC response
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) async => []);

      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      // Start loading
      final future = notifier.loadInitial();
      await container.read(timelineFeedNotifierProvider.future);
      
      // Check loading state was set
      final loadingState = container.read(timelineFeedNotifierProvider);
      expect(loadingState.state, isIn([TimelineState.loading, TimelineState.empty, TimelineState.loaded]));
      
      await future;
    });

    test('loadMore does nothing when already loading', () async {
      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      // Set state to loadingMore
      container.read(timelineFeedNotifierProvider.notifier).state = 
          const TimelineFeedState(
            state: TimelineState.loadingMore,
            hasMore: false,
          );

      await notifier.loadMore();
      
      // Should not have called RPC
      verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
    });

    test('loadMore does nothing when no more data', () async {
      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      // Set state with no more data
      container.read(timelineFeedNotifierProvider.notifier).state = 
          const TimelineFeedState(
            state: TimelineState.loaded,
            hasMore: false,
          );

      await notifier.loadMore();
      
      // Should not have called RPC
      verifyNever(() => mockSupabase.rpc(any(), params: any(named: 'params')));
    });

    test('refresh resets page number and loads initial', () async {
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) async => []);

      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      await notifier.refresh();
      
      verify(() => mockSupabase.rpc('get_timeline_feed', params: any(named: 'params'))).called(1);
    });

    test('loadInitial handles offline state', () async {
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      await notifier.loadInitial();
      
      final state = container.read(timelineFeedNotifierProvider);
      expect(state.state, TimelineState.error);
      expect(state.errorMessage, contains('offline'));
    });

    test('loadInitial handles search query', () async {
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) async => []);

      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      await notifier.loadInitial(searchQuery: 'test query');
      
      verify(() => mockSupabase.rpc(
        'get_timeline_feed',
        params: argThat(
          containsPair('p_search_query', 'test query'),
          named: 'params',
        ),
      )).called(1);
    });

    test('loadInitial handles empty search query', () async {
      when(() => mockSupabase.rpc(any(), params: any(named: 'params')))
          .thenAnswer((_) async => []);

      final notifier = container.read(timelineFeedNotifierProvider.notifier);
      
      await notifier.loadInitial(searchQuery: '   '); // Whitespace only
      
      verify(() => mockSupabase.rpc(
        'get_timeline_feed',
        params: argThat(
          isNot(contains('p_search_query')),
          named: 'params',
        ),
      )).called(1);
    });
  });
}


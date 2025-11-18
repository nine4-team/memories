import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/models/memory_type.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockUnifiedFeedRepository extends Mock implements UnifiedFeedRepository {}

void main() {
  group('UnifiedFeedController', () {
    late MockSupabaseClient mockSupabase;
    late MockConnectivityService mockConnectivity;
    late MockUnifiedFeedRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockConnectivity = MockConnectivityService();
      mockRepository = MockUnifiedFeedRepository();

      container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
          unifiedFeedRepositoryProvider.overrideWith((ref) => mockRepository),
        ],
      );

      // Default connectivity to online
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('starts in initial state', () {
        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.initial);
        expect(state.memories, isEmpty);
        expect(state.hasMore, false);
        expect(state.isOffline, false);
      });
    });

    group('State Transitions', () {
      test('transitions from initial to empty on loadInitial', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Check final state
        final finalState = container.read(unifiedFeedProvider);
        expect(finalState.state, UnifiedFeedState.empty);
      });

      test('transitions to ready state when data is loaded', () async {
        final testMemory = TimelineMoment(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'moment',
        );

        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.ready);
        expect(state.memories.length, 1);
        expect(state.hasMore, true);
      });

      test('transitions to appending state during pagination', () async {
        final testMemory1 = TimelineMoment(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'moment',
        );

        final testMemory2 = TimelineMoment(
          id: 'memory-2',
          userId: 'user-1',
          title: 'Test Memory 2',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          captureType: 'moment',
        );

        var callCount = 0;
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;
          callCount++;

          if (cursor == null) {
            // Initial load
            return UnifiedFeedPageResult(
              memories: [testMemory1],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory1.createdAt,
                id: testMemory1.id,
              ),
            );
          } else {
            // Pagination load
            return UnifiedFeedPageResult(
              memories: [testMemory2],
              hasMore: false,
            );
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify initial load succeeded
        final stateAfterLoad = container.read(unifiedFeedProvider);
        expect(stateAfterLoad.state, UnifiedFeedState.ready);
        expect(stateAfterLoad.memories.length, 1);

        // Load more
        await notifier.loadMore();

        // Check final state
        final finalState = container.read(unifiedFeedProvider);
        expect(finalState.state, UnifiedFeedState.ready);
        expect(finalState.memories.length, 2);
      });
    });

    group('Error Handling - Initial Load', () {
      test('shows full-page error on initial load failure', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenThrow(Exception('Network error'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, isNotNull);
        expect(state.errorMessage, contains('Network error'));
        expect(state.memories, isEmpty);
      });

      test('provides user-friendly error message for network errors', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenThrow(SocketException('Connection failed'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, contains('Unable to connect'));
        expect(state.errorMessage, isNot(contains('SocketException')));
      });

      test('provides user-friendly error message for timeout errors', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, contains('Unable to connect'));
      });
    });

    group('Error Handling - Pagination', () {
      test(
          'shows inline error on pagination failure while keeping existing data',
          () async {
        final testMemory = TimelineMoment(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'moment',
        );

        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;

          if (cursor == null) {
            // Initial load succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            );
          } else {
            // Pagination fails
            throw Exception('Network error');
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify initial load succeeded
        final stateAfterLoad = container.read(unifiedFeedProvider);
        expect(stateAfterLoad.state, UnifiedFeedState.ready);
        expect(stateAfterLoad.memories.length, 1);

        // Try to load more (will fail)
        await notifier.loadMore();

        // Verify pagination error state
        final stateAfterError = container.read(unifiedFeedProvider);
        expect(stateAfterError.state, UnifiedFeedState.paginationError);
        expect(stateAfterError.errorMessage, isNotNull);
        // Existing memories should still be visible
        expect(stateAfterError.memories.length, 1);
      });

      test('can retry pagination after error', () async {
        final testMemory1 = TimelineMoment(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'moment',
        );

        final testMemory2 = TimelineMoment(
          id: 'memory-2',
          userId: 'user-1',
          title: 'Test Memory 2',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          captureType: 'moment',
        );

        var callCount = 0;
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;
          callCount++;

          if (cursor == null) {
            // Initial load succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory1],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory1.createdAt,
                id: testMemory1.id,
              ),
            );
          } else if (callCount == 2) {
            // First pagination attempt fails
            throw Exception('Network error');
          } else {
            // Retry succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory2],
              hasMore: false,
            );
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // First pagination attempt fails
        await notifier.loadMore();
        final stateAfterError = container.read(unifiedFeedProvider);
        expect(stateAfterError.state, UnifiedFeedState.paginationError);
        expect(stateAfterError.memories.length, 1);

        // Retry pagination (will succeed on third call)
        await notifier.loadMore();
        final stateAfterRetry = container.read(unifiedFeedProvider);
        expect(stateAfterRetry.state, UnifiedFeedState.ready);
        expect(stateAfterRetry.memories.length, 2);
      });
    });

    group('Offline Handling', () {
      test('detects offline state and sets isOffline flag', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.isOffline, true);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, contains('offline'));
      });

      test('disables refresh while offline', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(unifiedFeedProvider.notifier);

        // Refresh should return early without making API calls
        await notifier.refresh();

        // Verify no repository calls were made
        verifyNever(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            ));
      });

      test('shows offline banner when isOffline is true', () {
        // This is tested via widget tests, but we verify the state
        final state = UnifiedFeedViewState(
          state: UnifiedFeedState.ready,
          isOffline: true,
        );
        expect(state.isOffline, true);
      });
    });

    group('Filter Management', () {
      test('setFilter updates filter and reloads', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);

        // Set filter to Story
        await notifier.setFilter(MemoryType.story);

        // Verify repository was called with Story filter
        verify(() => mockRepository.fetchPage(
              cursor: null,
              filter: MemoryType.story,
              batchSize: 20,
            )).called(1);
      });

      test('setFilter resets pagination', () async {
        final testMemory = TimelineMoment(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          captureType: 'moment',
        );

        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Change filter
        await notifier.setFilter(MemoryType.story);

        // Verify cursor was reset (new initial load)
        verify(() => mockRepository.fetchPage(
              cursor: null,
              filter: MemoryType.story,
              batchSize: 20,
            )).called(1);
      });
    });

    group('Empty State', () {
      test('transitions to empty state when no memories found', () async {
        when(() => mockRepository.fetchPage(
              cursor: any(named: 'cursor'),
              filter: any(named: 'filter'),
              batchSize: any(named: 'batchSize'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.empty);
        expect(state.memories, isEmpty);
        expect(state.hasMore, false);
      });
    });
  });
}

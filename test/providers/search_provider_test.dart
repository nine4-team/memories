import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/services/search_service.dart';
import 'package:memories/models/search_result.dart';
import 'package:mocktail/mocktail.dart';

// Mock SearchService
class MockSearchService extends Mock implements SearchService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchQuery', () {
    test('initializes with empty string', () {
      final container = ProviderContainer();
      final query = container.read(searchQueryProvider);
      expect(query, isEmpty);
      container.dispose();
    });

    test('setQuery updates state', () {
      final container = ProviderContainer();
      container.read(searchQueryProvider.notifier).setQuery('test query');
      final query = container.read(searchQueryProvider);
      expect(query, equals('test query'));
      container.dispose();
    });

    test('clear resets to empty string', () {
      final container = ProviderContainer();
      container.read(searchQueryProvider.notifier).setQuery('test query');
      container.read(searchQueryProvider.notifier).clear();
      final query = container.read(searchQueryProvider);
      expect(query, isEmpty);
      container.dispose();
    });
  });

  group('DebouncedSearchQuery', () {
    test('returns empty immediately when query is empty', () {
      final container = ProviderContainer();
      final debouncedQuery = container.read(debouncedSearchQueryProvider);
      expect(debouncedQuery, isEmpty);
      container.dispose();
    });

    test('debounces query updates', () async {
      final container = ProviderContainer();
      
      // Set query
      container.read(searchQueryProvider.notifier).setQuery('test');
      
      // Immediately after setting, debounced query should still be empty
      // (debounce hasn't fired yet)
      final immediate = container.read(debouncedSearchQueryProvider);
      expect(immediate, isEmpty);
      
      // Wait for debounce period (250ms)
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Now debounced query should be updated
      final debounced = container.read(debouncedSearchQueryProvider);
      expect(debounced, equals('test'));
      
      container.dispose();
    });

    test('cancels previous debounce timer on new query', () async {
      final container = ProviderContainer();
      
      // Set first query
      container.read(searchQueryProvider.notifier).setQuery('test1');
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Set second query before debounce fires
      container.read(searchQueryProvider.notifier).setQuery('test2');
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Should only have the second query
      final debounced = container.read(debouncedSearchQueryProvider);
      expect(debounced, equals('test2'));
      
      container.dispose();
    });
  });

  group('SearchResults', () {
    late MockSearchService mockSearchService;
    late ProviderContainer container;

    setUp(() {
      mockSearchService = MockSearchService();
      container = ProviderContainer(
        overrides: [
          searchServiceProvider.overrideWithValue(mockSearchService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with empty state', () {
      final state = container.read(searchResultsProvider);
      expect(state.items, isEmpty);
      expect(state.currentPage, equals(0));
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('clear resets to initial state', () {
      final notifier = container.read(searchResultsProvider.notifier);
      notifier.clear();
      final state = container.read(searchResultsProvider);
      expect(state.items, isEmpty);
      expect(state.currentPage, equals(0));
      expect(state.hasMore, isFalse);
    });

    // Note: Testing search execution requires mocking SearchService responses
    // which is complex. These tests are best done in integration tests with
    // real Supabase. See test/integration/ for end-to-end tests.
  });

  group('RecentSearches', () {
    late MockSearchService mockSearchService;
    late ProviderContainer container;

    setUp(() {
      mockSearchService = MockSearchService();
      container = ProviderContainer(
        overrides: [
          searchServiceProvider.overrideWithValue(mockSearchService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loads recent searches from service', () async {
      final mockSearches = [
        RecentSearch(
          query: 'test query 1',
          searchedAt: DateTime(2024, 1, 1),
        ),
        RecentSearch(
          query: 'test query 2',
          searchedAt: DateTime(2024, 1, 2),
        ),
      ];

      when(() => mockSearchService.getRecentSearches())
          .thenAnswer((_) async => mockSearches);

      final result = await container.read(recentSearchesProvider.future);

      expect(result.length, equals(2));
      expect(result[0].query, equals('test query 1'));
      expect(result[1].query, equals('test query 2'));
    });
  });

  group('ClearRecentSearches', () {
    late MockSearchService mockSearchService;
    late ProviderContainer container;

    setUp(() {
      mockSearchService = MockSearchService();
      container = ProviderContainer(
        overrides: [
          searchServiceProvider.overrideWithValue(mockSearchService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('calls service to clear recent searches', () async {
      when(() => mockSearchService.clearRecentSearches())
          .thenAnswer((_) async => {});

      final notifier = container.read(clearRecentSearchesProvider.notifier);
      await notifier.clear();

      verify(() => mockSearchService.clearRecentSearches()).called(1);
    });
  });
}


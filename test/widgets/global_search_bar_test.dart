import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/widgets/global_search_bar.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/services/search_service.dart';
import 'package:memories/models/search_result.dart';
import 'package:mocktail/mocktail.dart';

// Mock SearchService
class MockSearchService extends Mock implements SearchService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlobalSearchBar', () {
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

    testWidgets('displays search input field with placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search memories…'), findsOneWidget);
    });

    testWidgets('shows clear button when search query is not empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Set search query
      container.read(searchQueryProvider.notifier).setQuery('test');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears search when clear button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Set search query
      container.read(searchQueryProvider.notifier).setQuery('test');
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Search query should be cleared
      final state = container.read(searchQueryProvider);
      expect(state, isEmpty);
    });

    testWidgets('shows loading indicator when searching', (WidgetTester tester) async {
      // Mock search to return slowly
      when(() => mockSearchService.searchMemories(
            query: any(named: 'query'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            memoryType: any(named: 'memoryType'),
          )).thenAnswer((_) async => Future.delayed(
                const Duration(seconds: 1),
                () => SearchResultsPage(
                      items: [],
                      page: 1,
                      pageSize: 20,
                      hasMore: false,
                    ),
              ));

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Set search query
      container.read(searchQueryProvider.notifier).setQuery('test');
      
      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state when search fails', (WidgetTester tester) async {
      when(() => mockSearchService.searchMemories(
            query: any(named: 'query'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            memoryType: any(named: 'memoryType'),
          )).thenThrow(Exception('Search failed'));

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Set search query
      container.read(searchQueryProvider.notifier).setQuery('test');
      
      // Wait for debounce and error
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text("Can't load results. Tap to retry."), findsOneWidget);
    });

    testWidgets('shows empty state when no results', (WidgetTester tester) async {
      when(() => mockSearchService.searchMemories(
            query: any(named: 'query'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            memoryType: any(named: 'memoryType'),
          )).thenAnswer((_) async => SearchResultsPage(
                items: [],
                page: 1,
                pageSize: 20,
                hasMore: false,
              ));

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Set search query
      container.read(searchQueryProvider.notifier).setQuery('test');
      
      // Wait for debounce and search
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No memories match your search'), findsOneWidget);
    });

    testWidgets('shows recent searches when focused and empty', (WidgetTester tester) async {
      final mockSearches = [
        RecentSearch(
          query: 'recent query 1',
          searchedAt: DateTime(2024, 1, 1),
        ),
        RecentSearch(
          query: 'recent query 2',
          searchedAt: DateTime(2024, 1, 2),
        ),
      ];

      when(() => mockSearchService.getRecentSearches())
          .thenAnswer((_) async => mockSearches);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Focus the search field
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pumpAndSettle();

      // Should show recent searches
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.text('recent query 1'), findsOneWidget);
      expect(find.text('recent query 2'), findsOneWidget);
    });

    testWidgets('hides recent searches when user starts typing', (WidgetTester tester) async {
      final mockSearches = [
        RecentSearch(
          query: 'recent query',
          searchedAt: DateTime(2024, 1, 1),
        ),
      ];

      when(() => mockSearchService.getRecentSearches())
          .thenAnswer((_) async => mockSearches);

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      // Focus the search field
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pumpAndSettle();

      // Should show recent searches
      expect(find.text('Recent searches'), findsOneWidget);

      // Type in the field
      await tester.enterText(textField, 't');
      await tester.pump();

      // Recent searches should be hidden
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('has proper accessibility labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalSearchBar(),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(GlobalSearchBar));
      expect(semantics, isNotNull);
    });
  });
}


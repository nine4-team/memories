import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/widgets/timeline_search_bar.dart';
import 'package:memories/providers/timeline_provider.dart';

void main() {
  group('TimelineSearchBar', () {
    testWidgets('displays search input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TimelineSearchBar(),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search memories...'), findsOneWidget);
    });

    testWidgets('shows clear button when search query is not empty', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TimelineSearchBar(),
            ),
          ),
        ),
      );

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Set search query
      container.read(searchQueryNotifierProvider.notifier).setQuery('test');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
      
      container.dispose();
    });

    testWidgets('clears search when clear button is tapped', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TimelineSearchBar(),
            ),
          ),
        ),
      );

      // Set search query
      container.read(searchQueryNotifierProvider.notifier).setQuery('test');
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Search query should be cleared
      final state = container.read(searchQueryNotifierProvider);
      expect(state, isEmpty);
      
      container.dispose();
    });

    testWidgets('debounces search input', (WidgetTester tester) async {
      final container = ProviderContainer();
      
      await tester.pumpWidget(
        ProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TimelineSearchBar(),
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      
      // Type multiple characters quickly
      await tester.enterText(textField, 't');
      await tester.pump();
      await tester.enterText(textField, 'te');
      await tester.pump();
      await tester.enterText(textField, 'tes');
      await tester.pump();
      await tester.enterText(textField, 'test');
      await tester.pump();

      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 350));

      // Should have set query after debounce
      final state = container.read(searchQueryNotifierProvider);
      expect(state, 'test');
      
      container.dispose();
    });

    testWidgets('has proper accessibility labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TimelineSearchBar(),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(TimelineSearchBar));
      expect(semantics, isNotNull);
    });
  });
}


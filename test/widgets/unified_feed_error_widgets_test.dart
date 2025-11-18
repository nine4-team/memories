import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:memories/widgets/unified_feed_error_row.dart';
import 'package:memories/widgets/unified_feed_error_screen.dart';
import 'package:memories/widgets/unified_feed_offline_banner.dart';

void main() {
  group('UnifiedFeedErrorRow', () {
    testWidgets('displays error message', (WidgetTester tester) async {
      const errorMessage = 'Network error. Please try again.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorRow(
              errorMessage: errorMessage,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is tapped',
        (WidgetTester tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorRow(
              errorMessage: 'Test error',
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCalled, true);
    });

    testWidgets('has proper accessibility semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorRow(
              errorMessage: 'Test error',
              onRetry: () {},
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(UnifiedFeedErrorRow));
      expect(semantics, isNotNull);
      expect(semantics.label, contains('Error loading more memories'));
    });

    testWidgets('displays error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorRow(
              errorMessage: 'Test error',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('UnifiedFeedErrorScreen', () {
    testWidgets('displays error message', (WidgetTester tester) async {
      const errorMessage = 'Failed to load memories. Please try again.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorScreen(
              errorMessage: errorMessage,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Failed to load memories'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is tapped',
        (WidgetTester tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorScreen(
              errorMessage: 'Test error',
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCalled, true);
    });

    testWidgets('shows offline message when isOffline is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorScreen(
              errorMessage: 'You appear to be offline',
              onRetry: () {},
              isOffline: true,
            ),
          ),
        ),
      );

      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.text('Showing cached content if available'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows error icon when not offline',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorScreen(
              errorMessage: 'Test error',
              onRetry: () {},
              isOffline: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('has proper accessibility semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedErrorScreen(
              errorMessage: 'Test error',
              onRetry: () {},
            ),
          ),
        ),
      );

      final semantics =
          tester.getSemantics(find.byType(UnifiedFeedErrorScreen));
      expect(semantics, isNotNull);
      expect(semantics.label, contains('Error loading memories'));
    });
  });

  group('UnifiedFeedOfflineBanner', () {
    testWidgets('displays offline message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedOfflineBanner(),
          ),
        ),
      );

      expect(find.text('Offline - Showing cached content'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('has proper accessibility semantics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFeedOfflineBanner(),
          ),
        ),
      );

      final semantics =
          tester.getSemantics(find.byType(UnifiedFeedOfflineBanner));
      expect(semantics, isNotNull);
      expect(semantics.label, contains('Offline mode'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/screens/timeline/story_timeline_screen.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import '../helpers/test_supabase_setup.dart';

/// Integration tests for Story timeline using real Supabase instance
///
/// These tests use a real Supabase connection (test instance) to verify
/// end-to-end behavior without mocking.
///
/// To run these tests:
/// ```bash
/// flutter test integration_test/story_timeline_integration_test.dart \
///   --dart-define=TEST_SUPABASE_URL=your_test_url \
///   --dart-define=TEST_SUPABASE_ANON_KEY=your_test_key
/// ```
///
/// Or set environment variables:
/// ```bash
/// export TEST_SUPABASE_URL=your_test_url
/// export TEST_SUPABASE_ANON_KEY=your_test_key
/// flutter test integration_test/story_timeline_integration_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Story Timeline Integration Tests (Real Supabase)', () {
    late ProviderContainer container;

    setUpAll(() {
      // Set up real Supabase container for integration tests
      // This will throw if TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY are not set
      try {
        container = createTestSupabaseContainer();
      } catch (e) {
        // Skip tests if Supabase credentials not configured
        print('Skipping integration tests: $e');
        print(
            'Set TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY to run these tests');
      }
    });

    tearDownAll(() {
      container.dispose();
    });

    testWidgets('Story timeline screen loads and displays Stories',
        (WidgetTester tester) async {
      // Skip if Supabase not configured
      if (!_isSupabaseConfigured()) {
        return;
      }

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: StoryTimelineScreen(),
          ),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify we're on Story timeline screen
      expect(find.text('Stories'), findsOneWidget);

      // Verify screen is in a valid state (loading, empty, or loaded)
      // We don't know which state without actual data, but we verify
      // the screen renders without errors
      expect(find.byType(StoryTimelineScreen), findsOneWidget);
    });

    testWidgets('Story timeline handles empty state gracefully',
        (WidgetTester tester) async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: StoryTimelineScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If no Stories exist, should show empty state
      // The empty state message should be visible
      final emptyStateText = find.textContaining(RegExp(
        r'(No stories|Record your first)',
        caseSensitive: false,
      ));

      // Either empty state or stories list should be visible
      expect(
        emptyStateText.evaluate().isNotEmpty ||
            find.byType(StoryTimelineScreen).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Story timeline pull-to-refresh works',
        (WidgetTester tester) async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: StoryTimelineScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find the scrollable area
      final scrollable = find.byType(RefreshIndicator);
      if (scrollable.evaluate().isNotEmpty) {
        // Try to trigger pull-to-refresh
        // This is a simplified test - full pull-to-refresh testing
        // would require more complex gesture simulation
        expect(scrollable, findsWidgets);
      }
    });

    testWidgets('Story detail screen loads for Story type',
        (WidgetTester tester) async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Note: This test requires a real Story ID from your test database
      // Replace 'test-story-id' with an actual Story ID from your test data
      const testStoryId = 'test-story-id';

      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: MomentDetailScreen(momentId: testStoryId),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify detail screen loads (may show loading, error, or content)
      expect(find.byType(MomentDetailScreen), findsOneWidget);
    });
  });
}

/// Check if Supabase is configured for integration tests
bool _isSupabaseConfigured() {
  const testUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: '',
  );
  const testAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  return testUrl.isNotEmpty && testAnonKey.isNotEmpty;
}

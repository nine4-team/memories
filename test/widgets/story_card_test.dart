import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/widgets/story_card.dart';
import 'package:memories/models/timeline_moment.dart';

void main() {
  group('StoryCard', () {
    Widget createWidget(TimelineMoment story) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StoryCard(
              story: story,
              onTap: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays story title', (WidgetTester tester) async {
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      expect(find.text('Test Story'), findsOneWidget);
    });

    testWidgets('displays "Untitled Story" when title is empty', (WidgetTester tester) async {
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: '',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      expect(find.text('Untitled Story'), findsOneWidget);
    });

    testWidgets('displays relative timestamp for recent story', (WidgetTester tester) async {
      final today = DateTime.now();
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: today,
        createdAt: today,
        year: today.year,
        season: 'Winter',
        month: today.month,
        day: today.day,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      // Should show "Just now" or similar relative time
      expect(find.textContaining('ago'), findsWidgets);
    });

    testWidgets('displays absolute timestamp for old story', (WidgetTester tester) async {
      final oldDate = DateTime(2020, 1, 17);
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: oldDate,
        createdAt: oldDate,
        year: 2020,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      // Should show absolute date format
      expect(find.textContaining('2020'), findsWidgets);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      var tapped = false;
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StoryCard(
                story: story,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StoryCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has proper accessibility semantics', (WidgetTester tester) async {
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      final semantics = tester.getSemantics(find.byType(StoryCard));
      expect(semantics, isNotNull);
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(semantics.label, contains('Story'));
      expect(semantics.label, contains('Test Story'));
      expect(semantics.hint, contains('Double tap to view story details'));
    });

    testWidgets('has minimum 44px tap target height', (WidgetTester tester) async {
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      final cardFinder = find.byType(StoryCard);
      final cardBox = tester.getRect(cardFinder);
      expect(cardBox.height, greaterThanOrEqualTo(44));
    });

    testWidgets('displays calendar icon', (WidgetTester tester) async {
      final story = TimelineMoment(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test Story',
        capturedAt: DateTime(2025, 1, 17),
        createdAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        captureType: 'story',
      );

      await tester.pumpWidget(createWidget(story));

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });
  });
}


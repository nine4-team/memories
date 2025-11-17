import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/widgets/moment_card.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/providers/supabase_provider.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockStorageBucketApi extends Mock implements StorageBucketApi {}

class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  group('MomentCard', () {
    late MockSupabaseClient mockSupabase;
    late MockStorageBucketApi mockBucketApi;
    late MockStorageFileApi mockFileApi;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockBucketApi = MockStorageBucketApi();
      mockFileApi = MockStorageFileApi();

      when(() => mockSupabase.storage).thenReturn(mockBucketApi);
      when(() => mockBucketApi.from(any())).thenReturn(mockFileApi);
    });

    Widget createWidget(TimelineMoment moment) {
      return ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MomentCard(
              moment: moment,
              onTap: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays moment title', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.text('Test Moment'), findsOneWidget);
    });

    testWidgets('displays "Untitled Moment" when title is empty', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: '',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.text('Untitled Moment'), findsOneWidget);
    });

    testWidgets('displays snippet text when available', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
        snippetText: 'This is a test snippet',
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.text('This is a test snippet'), findsOneWidget);
    });

    testWidgets('displays tags when available', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: ['tag1', 'tag2', 'tag3'],
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
      expect(find.text('tag3'), findsOneWidget);
    });

    testWidgets('shows text-only badge when no media', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (WidgetTester tester) async {
      var tapped = false;
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MomentCard(
                moment: moment,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MomentCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('displays relative date', (WidgetTester tester) async {
      final today = DateTime.now();
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: today,
        year: today.year,
        season: 'Winter',
        month: today.month,
        day: today.day,
        tags: [],
      );

      await tester.pumpWidget(createWidget(moment));

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('has proper accessibility semantics', (WidgetTester tester) async {
      final moment = TimelineMoment(
        id: 'test-id',
        title: 'Test Moment',
        capturedAt: DateTime(2025, 1, 17),
        year: 2025,
        season: 'Winter',
        month: 1,
        day: 17,
        tags: ['tag1'],
        snippetText: 'Test snippet',
      );

      await tester.pumpWidget(createWidget(moment));

      final semantics = tester.getSemantics(find.byType(MomentCard));
      expect(semantics, isNotNull);
      expect(semantics?.hasFlag(SemanticsFlag.isButton), isTrue);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import 'package:memories/providers/moment_detail_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/timeline_analytics_service.dart';
import 'package:memories/models/moment_detail.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockTimelineAnalyticsService extends Mock implements TimelineAnalyticsService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

// Mock notifier that returns a fixed state
class MockMomentDetailNotifier extends MomentDetailNotifier {
  final MomentDetailViewState _state;

  MockMomentDetailNotifier(this._state);

  @override
  MomentDetailViewState build(String momentId) {
    return _state;
  }

  @override
  Future<String?> getShareLink() async => null;

  @override
  Future<bool> deleteMoment() async => true;

  @override
  Future<void> refresh() async {}
}

void main() {
  group('MomentDetailScreen', () {
    late MockSupabaseClient mockSupabase;
    late MockTimelineAnalyticsService mockAnalytics;
    late MockConnectivityService mockConnectivity;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAnalytics = MockTimelineAnalyticsService();
      mockConnectivity = MockConnectivityService();

      // Default connectivity to online
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
    });

    Widget createWidget(String momentId) {
      return ProviderScope(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
        ],
        child: MaterialApp(
          home: MomentDetailScreen(momentId: momentId),
        ),
      );
    }

    group('Controller States', () {
      testWidgets('displays loading skeleton when state is loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget('test-id'));

        // Initial state should show loading skeleton (CustomScrollView with skeleton containers)
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.text('Memory'), findsOneWidget); // App bar title
      });

      testWidgets('displays error state with retry button',
          (WidgetTester tester) async {
        // Create a provider override that returns error state
        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.error,
            errorMessage: 'Failed to load moment',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        // Error message appears in both title and body
        expect(find.text('Failed to load moment'), findsWidgets);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('displays loaded state with moment content',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          textDescription: 'Test description',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        // Title appears in both app bar and content
        expect(find.text('Test Moment'), findsWidgets);
        expect(find.text('Test description'), findsOneWidget);
      });

      testWidgets('displays "Untitled Moment" when title is empty',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: '',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        // Title appears in both app bar and content
        expect(find.text('Untitled Moment'), findsWidgets);
      });
    });

    group('Carousel Interactions', () {
      testWidgets('displays media carousel when photos are present',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [
            PhotoMedia(url: 'photo1.jpg', index: 0),
            PhotoMedia(url: 'photo2.jpg', index: 1),
          ],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => MockMomentDetailNotifier(
                        MomentDetailViewState(
                          state: MomentDetailState.loaded,
                          moment: moment,
                        ),
                      )),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        // Carousel should be present (PageView)
        expect(find.byType(PageView), findsOneWidget);
      });

      testWidgets('displays page indicators for multiple media items',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [
            PhotoMedia(url: 'photo1.jpg', index: 0),
            PhotoMedia(url: 'photo2.jpg', index: 1),
            PhotoMedia(url: 'photo3.jpg', index: 2),
          ],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        // Page indicators should be present (PageView with multiple items)
        expect(find.byType(PageView), findsOneWidget);
      });
    });

    group('Destructive Actions', () {
      testWidgets('shows delete confirmation bottom sheet when delete is tapped',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find delete button (FloatingActionButton with delete icon)
        final deleteButton = find.byIcon(Icons.delete);
        expect(deleteButton, findsOneWidget);

        // Tap delete button
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Verify confirmation sheet appears
        expect(find.text('Delete "Test Moment"?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('tracks delete analytics event when delete is confirmed',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();

        // Confirm delete
        await tester.tap(find.text('Delete'));
        await tester.pump();

        // Verify analytics was called
        verify(() => mockAnalytics.trackMomentDetailDelete('test-id')).called(1);
      });

      testWidgets('shows edit button and tracks edit analytics',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find edit button
        final editButton = find.byIcon(Icons.edit);
        expect(editButton, findsOneWidget);

        // Tap edit button
        await tester.tap(editButton);
        await tester.pump();

        // Verify analytics was called
        verify(() => mockAnalytics.trackMomentDetailEdit('test-id')).called(1);
      });
    });

    group('Share Functionality', () {
      testWidgets('shows share button in app bar when online',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Share button should be present
        expect(find.byIcon(Icons.share), findsOneWidget);
      });

      testWidgets('tracks share analytics when share is tapped',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap share button
        await tester.tap(find.byIcon(Icons.share));
        await tester.pumpAndSettle();

        // Verify analytics was called
        verify(() => mockAnalytics.trackMomentShare('test-id', shareToken: null))
            .called(1);
      });
    });

    group('Offline State', () {
      testWidgets('disables share when offline', (WidgetTester tester) async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Share button should be disabled - find IconButton wrapped in Semantics
        final shareButtonFinder = find.descendant(
          of: find.byType(Semantics),
          matching: find.byType(IconButton),
        );
        expect(shareButtonFinder, findsOneWidget);
        final shareButton = tester.widget<IconButton>(shareButtonFinder);
        expect(shareButton.onPressed, isNull);
      });

      testWidgets('shows offline banner when viewing cached data',
          (WidgetTester tester) async {
        final moment = MomentDetail(
          id: 'test-id',
          userId: 'user-id',
          title: 'Test Moment',
          tags: [],
          captureType: 'moment',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          updatedAt: DateTime(2025, 1, 17),
          photos: [],
          videos: [],
          relatedStories: [],
          relatedMementos: [],
        );

        final mockNotifier = MockMomentDetailNotifier(
          MomentDetailViewState(
            state: MomentDetailState.loaded,
            moment: moment,
            isFromCache: true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(mockSupabase),
              timelineAnalyticsServiceProvider.overrideWithValue(mockAnalytics),
              connectivityServiceProvider.overrideWithValue(mockConnectivity),
              momentDetailNotifierProvider('test-id')
                  .overrideWith(() => mockNotifier),
            ],
            child: MaterialApp(
              home: MomentDetailScreen(momentId: 'test-id'),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.text(
            'Showing cached content. Some features may be unavailable offline.',
          ),
          findsOneWidget,
        );
      });
    });
  });
}



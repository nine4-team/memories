import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/widgets/sticky_audio_player.dart';

void main() {
  group('StickyAudioPlayer', () {
    Widget createWidget({
      String? audioUrl,
      double? duration,
      String storyId = 'test-story-id',
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StickyAudioPlayer(
              audioUrl: audioUrl,
              duration: duration,
              storyId: storyId,
            ),
          ),
        ),
      );
    }

    testWidgets('displays placeholder when audio URL is null', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(audioUrl: null));

      expect(find.text('Audio playback will be available soon'), findsOneWidget);
      expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
    });

    testWidgets('displays placeholder when duration is null', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: null,
      ));

      expect(find.text('Audio playback will be available soon'), findsOneWidget);
    });

    testWidgets('displays audio player controls when audio URL and duration are provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      // Should show play button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      // Should show duration (2:00 for 120 seconds)
      expect(find.textContaining('2:00'), findsWidgets);
      // Should show playback speed button
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('toggles play/pause button when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      // Initially shows play button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Tap play button
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      // Should now show pause button
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      // Should show play button again
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('displays slider for audio progress', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('has proper accessibility semantics for play button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      final playButtonFinder = find.byIcon(Icons.play_arrow);
      final semantics = tester.getSemantics(playButtonFinder);
      expect(semantics, isNotNull);
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(semantics.label, contains('Play audio playback'));
    });

    testWidgets('has proper accessibility semantics for slider', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      final sliderFinder = find.byType(Slider);
      final semantics = tester.getSemantics(sliderFinder);
      expect(semantics, isNotNull);
      expect(semantics.label, contains('Audio progress'));
    });

    testWidgets('has proper accessibility semantics for playback speed', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      final speedButtonFinder = find.text('1x');
      final semantics = tester.getSemantics(speedButtonFinder);
      expect(semantics, isNotNull);
      expect(semantics.label, contains('Playback speed'));
    });

    testWidgets('play button meets 44px minimum tap target', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      final playButtonFinder = find.byIcon(Icons.play_arrow);
      final playButtonBox = tester.getRect(playButtonFinder);
      expect(playButtonBox.width, greaterThanOrEqualTo(44));
      expect(playButtonBox.height, greaterThanOrEqualTo(44));
    });

    testWidgets('displays formatted duration correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 125.0, // 2 minutes 5 seconds
      ));

      // Should show "2:05" for duration
      expect(find.textContaining('2:05'), findsWidgets);
    });

    testWidgets('opens playback speed menu when speed button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      // Tap the speed button
      await tester.tap(find.text('1x'));
      await tester.pumpAndSettle();

      // Should show speed options
      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
    });

    testWidgets('is focusable for keyboard navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(
        audioUrl: 'https://example.com/audio.mp3',
        duration: 120.0,
      ));

      // Should have Focus widget
      expect(find.byType(Focus), findsOneWidget);
    });
  });
}


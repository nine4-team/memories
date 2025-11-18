import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/screens/capture/capture_screen.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/services/dictation_service.dart';
import 'package:memories/services/geolocation_service.dart';
import 'package:memories/services/audio_cache_service.dart';

void main() {
  group('CaptureScreen', () {
    Widget createWidget() {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: const CaptureScreen(),
          ),
        ),
      );
    }

    testWidgets('displays capture screen with memory type toggles', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Check for memory type toggle buttons
      expect(find.text('Moment'), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Memento'), findsOneWidget);
    });

    testWidgets('displays dictation control', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Check for microphone button or dictation helper text
      expect(
        find.text('Tap the microphone to start dictating'),
        findsOneWidget,
      );
    });

    testWidgets('displays description input field', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Description (optional)'), findsOneWidget);
    });

    testWidgets('displays media add buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('displays tag input', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Add tags (optional)'), findsOneWidget);
    });

    testWidgets('displays save button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('displays cancel button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('save button is disabled when no content', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      expect(saveButton, findsOneWidget);
      
      // Button should be disabled when no content
      final button = tester.widget<ElevatedButton>(saveButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('shows app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Capture Memory'), findsOneWidget);
    });

    // Note: More comprehensive tests would require mocking services
    // See test/integration/ for end-to-end tests with real services
  });
}


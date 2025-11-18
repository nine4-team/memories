import 'package:flutter_test/flutter_test.dart';
import 'package:memories/services/title_generation_service.dart';

// Note: Full integration tests for TitleGenerationService require a real Supabase instance
// These tests verify the response parsing and structure

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TitleGenerationResponse', () {
    test('parses JSON response correctly', () {
      final json = {
        'title': 'Test Generated Title',
        'status': 'success',
        'generatedAt': DateTime.now().toIso8601String(),
      };

      final response = TitleGenerationResponse.fromJson(json);

      expect(response.title, equals('Test Generated Title'));
      expect(response.status, equals('success'));
      expect(response.generatedAt, isA<DateTime>());
    });

    test('handles fallback status', () {
      final json = {
        'title': 'Untitled Moment',
        'status': 'fallback',
        'generatedAt': DateTime.now().toIso8601String(),
      };

      final response = TitleGenerationResponse.fromJson(json);

      expect(response.title, equals('Untitled Moment'));
      expect(response.status, equals('fallback'));
    });

    test('creates response with all fields', () {
      final now = DateTime.now();
      final response = TitleGenerationResponse(
        title: 'Test Title',
        status: 'success',
        generatedAt: now,
      );

      expect(response.title, equals('Test Title'));
      expect(response.status, equals('success'));
      expect(response.generatedAt, equals(now));
    });
  });

  // Note: Full integration tests for TitleGenerationService require a real Supabase instance
  // See test/integration/ for end-to-end tests with real Supabase edge function
}


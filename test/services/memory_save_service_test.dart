import 'package:flutter_test/flutter_test.dart';
import 'package:memories/services/memory_save_service.dart';

// Note: Full integration tests for MemorySaveService require a real Supabase instance
// These tests verify the service structure and error handling logic

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('MemorySaveService', () {
    group('Exception Types', () {
      test('OfflineException has correct message', () {
        final exception = OfflineException('Device is offline');
        expect(exception.toString(), equals('Device is offline'));
        expect(exception.message, equals('Device is offline'));
      });

      test('StorageQuotaException has correct message', () {
        final exception = StorageQuotaException('Storage limit reached');
        expect(exception.toString(), equals('Storage limit reached'));
        expect(exception.message, equals('Storage limit reached'));
      });

      test('NetworkException has correct message', () {
        final exception = NetworkException('Network error');
        expect(exception.toString(), equals('Network error'));
        expect(exception.message, equals('Network error'));
      });

      test('PermissionException has correct message', () {
        final exception = PermissionException('Permission denied');
        expect(exception.toString(), equals('Permission denied'));
        expect(exception.message, equals('Permission denied'));
      });

      test('SaveException has correct message', () {
        final exception = SaveException('Failed to save');
        expect(exception.toString(), equals('Failed to save'));
        expect(exception.message, equals('Failed to save'));
      });
    });

    group('MemorySaveResult', () {
      test('creates result with all fields', () {
        final result = MemorySaveResult(
          momentId: 'test-id',
          generatedTitle: 'Test Title',
          titleGeneratedAt: DateTime.now(),
          photoUrls: ['photo1.jpg', 'photo2.jpg'],
          videoUrls: ['video1.mp4'],
          hasLocation: true,
        );

        expect(result.momentId, equals('test-id'));
        expect(result.generatedTitle, equals('Test Title'));
        expect(result.photoUrls.length, equals(2));
        expect(result.videoUrls.length, equals(1));
        expect(result.hasLocation, isTrue);
      });

      test('creates result without optional fields', () {
        final result = MemorySaveResult(
          momentId: 'test-id',
          photoUrls: [],
          videoUrls: [],
          hasLocation: false,
        );

        expect(result.momentId, equals('test-id'));
        expect(result.generatedTitle, isNull);
        expect(result.titleGeneratedAt, isNull);
        expect(result.hasLocation, isFalse);
      });
    });

    // Note: Full integration tests require a real Supabase instance
    // See test/integration/ for end-to-end tests with real Supabase
  });
}


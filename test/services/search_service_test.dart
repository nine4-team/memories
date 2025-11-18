import 'package:flutter_test/flutter_test.dart';
import 'package:memories/services/search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';

// Mock Supabase client
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchService', () {
    late MockSupabaseClient mockSupabase;
    late SearchService searchService;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      searchService = SearchService(mockSupabase);
    });

    group('searchMemories', () {
      test('throws ArgumentError for empty query', () {
        expect(
          () => searchService.searchMemories(query: ''),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => searchService.searchMemories(query: '   '),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates query is not empty after trimming', () {
        expect(
          () => searchService.searchMemories(query: ''),
          throwsA(predicate<ArgumentError>(
            (e) => e.message?.contains('empty') ?? false,
          )),
        );
      });
    });

    group('addRecentSearch', () {
      test('throws ArgumentError for empty query', () {
        expect(
          () => searchService.addRecentSearch(''),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => searchService.addRecentSearch('   '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // Note: Full integration tests for SearchService require a real Supabase instance
    // See test/integration/ for end-to-end tests with real Supabase
    // The service primarily delegates to Supabase RPC calls, which are best tested
    // in integration tests where we can verify:
    // - Query normalization and parameter passing
    // - Response parsing
    // - Error handling
  });
}


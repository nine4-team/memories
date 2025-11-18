import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/search_provider.dart';
import 'package:memories/services/search_service.dart';
import 'package:memories/models/memory_type.dart';
import '../helpers/test_supabase_setup.dart';

/// Integration tests for search functionality
/// 
/// These tests require a real Supabase instance with migrations applied.
/// 
/// Run with:
/// ```bash
/// flutter test test/integration/search_integration_test.dart \
///   --dart-define=TEST_SUPABASE_URL=https://xxxxx.supabase.co \
///   --dart-define=TEST_SUPABASE_ANON_KEY=your-anon-key
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search Integration Tests (Real Supabase)', () {
    late ProviderContainer container;
    late SupabaseClient supabase;
    late SearchService searchService;
    String? testUserId;

    bool _isSupabaseConfigured() {
      try {
        final testUrl = const String.fromEnvironment('TEST_SUPABASE_URL');
        final testKey = const String.fromEnvironment('TEST_SUPABASE_ANON_KEY');
        return testUrl.isNotEmpty && testKey.isNotEmpty;
      } catch (e) {
        return false;
      }
    }

    setUpAll(() {
      // Set up real Supabase container for integration tests
      if (_isSupabaseConfigured()) {
        try {
          container = createTestSupabaseContainer();
          supabase = container.read(supabaseClientProvider);
          searchService = container.read(searchServiceProvider);
        } catch (e) {
          // Skip tests if Supabase credentials not configured
          print('Skipping integration tests: $e');
          print(
              'Set TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY to run these tests');
        }
      }
    });

    tearDownAll(() {
      container.dispose();
    });

    setUp(() async {
      // Create a test user for each test
      if (_isSupabaseConfigured()) {
        final testUser = await createTestUser(
          supabase,
          email: 'search_test_${DateTime.now().millisecondsSinceEpoch}@test.com',
          password: 'testpassword123',
        );
        testUserId = testUser.user.id;
      }
    });

    tearDown(() async {
      // Clean up test user and their data
      if (testUserId != null) {
        try {
          // Delete memories first (they should cascade, but be explicit)
          await supabase.from('memories').delete().eq('user_id', testUserId!);
          await cleanupTestUser(supabase, testUserId!);
        } catch (e) {
          // Ignore cleanup errors
          print('Cleanup error: $e');
        }
      }
    });

    test('creates memories of different types and verifies they are searchable',
        () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Create test memories
      final momentResponse = await supabase.from('memories').insert({
        'user_id': testUserId,
        'memory_type': 'moment',
        'title': 'Test Moment Title',
        'input_text': 'This is a test moment with searchable content',
        'tags': ['test', 'moment'],
      }).select().single();

      final storyResponse = await supabase.from('memories').insert({
        'user_id': testUserId,
        'memory_type': 'story',
        'title': 'Test Story Title',
        'input_text': 'This is a test story with searchable content',
        'processed_text': 'This is the processed story text',
        'tags': ['test', 'story'],
      }).select().single();

      // Wait a moment for search_vector to be updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Search by title
      var results = await searchService.searchMemories(query: 'Test Moment');
      expect(results.items.length, greaterThanOrEqualTo(1));
      expect(
          results.items.any((item) => item.id == momentResponse['id']), isTrue);

      // Search by input_text
      results = await searchService.searchMemories(query: 'searchable');
      expect(results.items.length, greaterThanOrEqualTo(2));

      // Search by tags
      results = await searchService.searchMemories(query: 'moment');
      expect(
          results.items.any((item) => item.id == momentResponse['id']), isTrue);

      // Search by processed_text (for story)
      results = await searchService.searchMemories(query: 'processed');
      expect(
          results.items.any((item) => item.id == storyResponse['id']), isTrue);
    });

    test('verifies RLS: authenticated user only sees their own memories',
        () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Create memory for test user
      await supabase.from('memories').insert({
        'user_id': testUserId,
        'memory_type': 'moment',
        'title': 'Private Memory',
        'input_text': 'This is a private memory',
      });

      // Wait for search_vector update
      await Future.delayed(const Duration(milliseconds: 500));

      // Search should return only this user's memory
      final results = await searchService.searchMemories(query: 'Private');
      expect(results.items.length, greaterThanOrEqualTo(1));
      expect(
          results.items.every((item) => item.id != null), isTrue); // All have IDs

      // Create another user and verify they can't see this memory
      final otherUser = await createTestUser(
        supabase,
        email: 'other_user_${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'testpassword123',
      );

      // Switch to other user's session
      await supabase.auth.signOut();
      await supabase.auth.signInWithPassword(
        email: otherUser.user.email!,
        password: 'testpassword123',
      );

      // Search should not return the first user's memory
      final otherResults = await searchService.searchMemories(query: 'Private');
      expect(
          otherResults.items.any((item) => item.title == 'Private Memory'),
          isFalse);

      // Cleanup other user
      await cleanupTestUser(supabase, otherUser.user.id);
    });

    test('verifies memory_type filter works', () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Create memories of different types
      await supabase.from('memories').insert([
        {
          'user_id': testUserId,
          'memory_type': 'moment',
          'title': 'Test Moment',
          'input_text': 'moment content',
        },
        {
          'user_id': testUserId,
          'memory_type': 'story',
          'title': 'Test Story',
          'input_text': 'story content',
        },
        {
          'user_id': testUserId,
          'memory_type': 'memento',
          'title': 'Test Memento',
          'input_text': 'memento content',
        },
      ]);

      // Wait for search_vector updates
      await Future.delayed(const Duration(milliseconds: 500));

      // Search without filter (should return all types)
      var results = await searchService.searchMemories(query: 'Test');
      expect(results.items.length, greaterThanOrEqualTo(3));

      // Search with moment filter
      results = await searchService.searchMemories(
        query: 'Test',
        memoryType: MemoryType.moment,
      );
      expect(results.items.length, greaterThanOrEqualTo(1));
      expect(
          results.items.every((item) => item.memoryType == 'moment'), isTrue);

      // Search with story filter
      results = await searchService.searchMemories(
        query: 'Test',
        memoryType: MemoryType.story,
      );
      expect(results.items.length, greaterThanOrEqualTo(1));
      expect(
          results.items.every((item) => item.memoryType == 'story'), isTrue);
    });

    test('verifies pagination works correctly', () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Create multiple memories (more than page size)
      final memories = List.generate(25, (index) {
        return {
          'user_id': testUserId,
          'memory_type': 'moment',
          'title': 'Test Memory $index',
          'input_text': 'Content for memory $index',
        };
      });

      await supabase.from('memories').insert(memories);

      // Wait for search_vector updates
      await Future.delayed(const Duration(milliseconds: 1000));

      // Search page 1
      var results = await searchService.searchMemories(
        query: 'Test',
        page: 1,
        pageSize: 10,
      );

      expect(results.items.length, equals(10));
      expect(results.page, equals(1));
      expect(results.pageSize, equals(10));
      expect(results.hasMore, isTrue);

      // Search page 2
      results = await searchService.searchMemories(
        query: 'Test',
        page: 2,
        pageSize: 10,
      );

      expect(results.items.length, equals(10));
      expect(results.page, equals(2));
      expect(results.hasMore, isTrue);

      // Search page 3 (should have fewer results)
      results = await searchService.searchMemories(
        query: 'Test',
        page: 3,
        pageSize: 10,
      );

      expect(results.items.length, lessThanOrEqualTo(10));
      expect(results.page, equals(3));
      // Last page might or might not have more, depending on exact count
    });

    test('verifies recent searches functionality', () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Clear any existing recent searches
      await searchService.clearRecentSearches();

      // Add some searches
      await searchService.addRecentSearch('query 1');
      await searchService.addRecentSearch('query 2');
      await searchService.addRecentSearch('query 3');

      // Get recent searches
      var recent = await searchService.getRecentSearches();
      expect(recent.length, greaterThanOrEqualTo(3));
      expect(recent.any((s) => s.query == 'query 1'), isTrue);
      expect(recent.any((s) => s.query == 'query 2'), isTrue);
      expect(recent.any((s) => s.query == 'query 3'), isTrue);

      // Add duplicate (should move to top)
      await searchService.addRecentSearch('query 1');
      recent = await searchService.getRecentSearches();
      expect(recent.first.query, equals('query 1'));

      // Verify limit (should maintain only 5)
      await searchService.addRecentSearch('query 4');
      await searchService.addRecentSearch('query 5');
      await searchService.addRecentSearch('query 6');
      recent = await searchService.getRecentSearches();
      expect(recent.length, lessThanOrEqualTo(5));

      // Clear recent searches
      await searchService.clearRecentSearches();
      recent = await searchService.getRecentSearches();
      expect(recent, isEmpty);
    });

    test('verifies search results include snippets and metadata', () async {
      if (!_isSupabaseConfigured()) {
        return;
      }

      // Create memory with both input_text and processed_text
      await supabase.from('memories').insert({
        'user_id': testUserId,
        'memory_type': 'story',
        'title': 'Story with Processed Text',
        'input_text': 'This is the raw input text',
        'processed_text': 'This is the processed story text that should appear in snippet',
      });

      // Wait for search_vector update
      await Future.delayed(const Duration(milliseconds: 500));

      // Search
      final results = await searchService.searchMemories(query: 'Story');
      expect(results.items.length, greaterThanOrEqualTo(1));

      final result = results.items.firstWhere(
        (item) => item.title == 'Story with Processed Text',
      );

      // Verify result has required fields
      expect(result.id, isNotEmpty);
      expect(result.memoryType, equals('story'));
      expect(result.title, isNotEmpty);
      expect(result.createdAt, isNotNull);
      // Snippet should prefer processed_text if available
      if (result.snippetText != null) {
        expect(result.snippetText, contains('processed'));
      }
    });
  });
}


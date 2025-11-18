import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/timeline_moment.dart';

/// Test grouping logic for unified feed
///
/// Verifies that memories are correctly grouped by Year → Season → Month hierarchy
void main() {
  group('Unified Feed Grouping Logic', () {
    test('groups memories by year correctly', () {
      final memories = [
        TimelineMoment(
          id: '1',
          userId: 'user-1',
          title: 'Memory 1',
          capturedAt: DateTime(2025, 1, 15),
          createdAt: DateTime(2025, 1, 15),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 15,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '2',
          userId: 'user-1',
          title: 'Memory 2',
          capturedAt: DateTime(2024, 12, 20),
          createdAt: DateTime(2024, 12, 20),
          year: 2024,
          season: 'Winter',
          month: 12,
          day: 20,
          tags: [],
          captureType: 'moment',
        ),
      ];

      final grouped = _groupMemoriesByHierarchy(memories);

      expect(grouped.keys.length, 2);
      expect(grouped.containsKey(2025), true);
      expect(grouped.containsKey(2024), true);
      expect(
          grouped[2025]!
              .values
              .expand((seasonMap) =>
                  seasonMap.values.expand((monthList) => monthList))
              .length,
          1);
      expect(
          grouped[2024]!
              .values
              .expand((seasonMap) =>
                  seasonMap.values.expand((monthList) => monthList))
              .length,
          1);
    });

    test('groups memories by season correctly', () {
      final memories = [
        TimelineMoment(
          id: '1',
          userId: 'user-1',
          title: 'Winter Memory',
          capturedAt: DateTime(2025, 1, 15),
          createdAt: DateTime(2025, 1, 15),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 15,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '2',
          userId: 'user-1',
          title: 'Spring Memory',
          capturedAt: DateTime(2025, 3, 20),
          createdAt: DateTime(2025, 3, 20),
          year: 2025,
          season: 'Spring',
          month: 3,
          day: 20,
          tags: [],
          captureType: 'moment',
        ),
      ];

      final grouped = _groupMemoriesByHierarchy(memories);

      expect(grouped[2025]!.keys.length, 2);
      expect(grouped[2025]!.containsKey('Winter'), true);
      expect(grouped[2025]!.containsKey('Spring'), true);
    });

    test('groups memories by month correctly', () {
      final memories = [
        TimelineMoment(
          id: '1',
          userId: 'user-1',
          title: 'January Memory',
          capturedAt: DateTime(2025, 1, 15),
          createdAt: DateTime(2025, 1, 15),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 15,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '2',
          userId: 'user-1',
          title: 'February Memory',
          capturedAt: DateTime(2025, 2, 10),
          createdAt: DateTime(2025, 2, 10),
          year: 2025,
          season: 'Winter',
          month: 2,
          day: 10,
          tags: [],
          captureType: 'moment',
        ),
      ];

      final grouped = _groupMemoriesByHierarchy(memories);

      expect(grouped[2025]!['Winter']!.keys.length, 2);
      expect(grouped[2025]!['Winter']!.containsKey(1), true);
      expect(grouped[2025]!['Winter']!.containsKey(2), true);
      expect(grouped[2025]!['Winter']![1]!.length, 1);
      expect(grouped[2025]!['Winter']![2]!.length, 1);
    });

    test('handles multiple memories in same month', () {
      final memories = [
        TimelineMoment(
          id: '1',
          userId: 'user-1',
          title: 'Memory 1',
          capturedAt: DateTime(2025, 1, 15),
          createdAt: DateTime(2025, 1, 15),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 15,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '2',
          userId: 'user-1',
          title: 'Memory 2',
          capturedAt: DateTime(2025, 1, 20),
          createdAt: DateTime(2025, 1, 20),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 20,
          tags: [],
          captureType: 'moment',
        ),
      ];

      final grouped = _groupMemoriesByHierarchy(memories);

      expect(grouped[2025]!['Winter']![1]!.length, 2);
    });

    test('handles empty list', () {
      final grouped = _groupMemoriesByHierarchy([]);
      expect(grouped.isEmpty, true);
    });

    test('handles memories across multiple years, seasons, and months', () {
      final memories = [
        TimelineMoment(
          id: '1',
          userId: 'user-1',
          title: '2024 Winter Dec',
          capturedAt: DateTime(2024, 12, 15),
          createdAt: DateTime(2024, 12, 15),
          year: 2024,
          season: 'Winter',
          month: 12,
          day: 15,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '2',
          userId: 'user-1',
          title: '2025 Winter Jan',
          capturedAt: DateTime(2025, 1, 10),
          createdAt: DateTime(2025, 1, 10),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 10,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '3',
          userId: 'user-1',
          title: '2025 Spring Mar',
          capturedAt: DateTime(2025, 3, 20),
          createdAt: DateTime(2025, 3, 20),
          year: 2025,
          season: 'Spring',
          month: 3,
          day: 20,
          tags: [],
          captureType: 'moment',
        ),
        TimelineMoment(
          id: '4',
          userId: 'user-1',
          title: '2025 Spring Apr',
          capturedAt: DateTime(2025, 4, 5),
          createdAt: DateTime(2025, 4, 5),
          year: 2025,
          season: 'Spring',
          month: 4,
          day: 5,
          tags: [],
          captureType: 'moment',
        ),
      ];

      final grouped = _groupMemoriesByHierarchy(memories);

      // Verify structure
      expect(grouped.keys.length, 2); // 2024, 2025
      expect(grouped[2024]!.keys.length, 1); // Winter
      expect(grouped[2025]!.keys.length, 2); // Winter, Spring
      expect(grouped[2024]!['Winter']!.keys.length, 1); // December
      expect(grouped[2025]!['Winter']!.keys.length, 1); // January
      expect(grouped[2025]!['Spring']!.keys.length, 2); // March, April

      // Verify counts
      expect(grouped[2024]!['Winter']![12]!.length, 1);
      expect(grouped[2025]!['Winter']![1]!.length, 1);
      expect(grouped[2025]!['Spring']![3]!.length, 1);
      expect(grouped[2025]!['Spring']![4]!.length, 1);
    });
  });
}

/// Group memories by Year → Season → Month hierarchy
///
/// This matches the implementation in timeline_screen.dart
Map<int, Map<String, Map<int, List<TimelineMoment>>>> _groupMemoriesByHierarchy(
  List<TimelineMoment> memories,
) {
  final grouped = <int, Map<String, Map<int, List<TimelineMoment>>>>{};

  for (final moment in memories) {
    grouped.putIfAbsent(moment.year, () => {});
    final yearMap = grouped[moment.year]!;

    yearMap.putIfAbsent(moment.season, () => {});
    final seasonMap = yearMap[moment.season]!;

    seasonMap.putIfAbsent(moment.month, () => []);
    seasonMap[moment.month]!.add(moment);
  }

  return grouped;
}

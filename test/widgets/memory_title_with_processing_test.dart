import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/memory_processing_status.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/providers/memory_processing_status_provider.dart';
import 'package:memories/widgets/memory_title_with_processing.dart';

void main() {
  const serverId = 'server-id-1';

  TimelineMemory buildMemory({
    String title = 'Untitled Moment',
    String? generatedTitle,
    DateTime? titleGeneratedAt,
  }) {
    final capturedAt = DateTime(2025, 1, 1);
    final createdAt = DateTime(2025, 1, 1);
    return TimelineMemory(
      id: 'timeline-$serverId',
      userId: 'user-id',
      title: title,
      generatedTitle: generatedTitle,
      titleGeneratedAt: titleGeneratedAt,
      tags: const [],
      memoryType: 'moment',
      capturedAt: capturedAt,
      createdAt: createdAt,
      memoryDate: capturedAt,
      year: 2025,
      season: 'Winter',
      month: 1,
      day: 1,
      primaryMedia: null,
      snippetText: null,
      memoryLocationData: null,
      nextCursorCapturedAt: null,
      nextCursorId: null,
      isOfflineQueued: false,
      isPreviewOnly: false,
      isDetailCachedLocally: false,
      localId: null,
      serverId: serverId,
      offlineSyncStatus: OfflineSyncStatus.synced,
    );
  }

  MemoryProcessingStatus buildStatus(MemoryProcessingState state) {
    final now = DateTime.now();
    return MemoryProcessingStatus(
      memoryId: serverId,
      state: state,
      createdAt: now,
      lastUpdatedAt: now,
    );
  }

  Future<void> pumpTitleWidget(
    WidgetTester tester,
    TimelineMemory memory,
    MemoryProcessingStatus status,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryProcessingStatusStreamProvider(memory.serverId!).overrideWith(
            (ref) => Stream<MemoryProcessingStatus?>.value(status),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MemoryTitleWithProcessing.timeline(memory: memory),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'shows spinner when scheduled status and no generated title available',
      (tester) async {
    final memory = buildMemory(title: 'Untitled Moment', generatedTitle: null);
    final status = buildStatus(MemoryProcessingState.scheduled);

    await pumpTitleWidget(tester, memory, status);

    expect(find.text('Generating title…'), findsOneWidget);
  });

  testWidgets('uses generated title even while processing, suppressing spinner',
      (tester) async {
    final memory = buildMemory(
      title: 'Legacy Title',
      generatedTitle: 'Generated Title',
      titleGeneratedAt: DateTime(2025, 1, 2),
    );
    final status = buildStatus(MemoryProcessingState.processing);

    await pumpTitleWidget(tester, memory, status);

    expect(find.text('Generating title…'), findsNothing);
    expect(find.text('Generated Title'), findsOneWidget);
  });

  testWidgets(
      'complete states fall back to plain titles without showing spinner',
      (tester) async {
    final memory = buildMemory(title: 'Legacy Title', generatedTitle: null);
    final status = buildStatus(MemoryProcessingState.complete);

    await pumpTitleWidget(tester, memory, status);

    expect(find.text('Generating title…'), findsNothing);
    expect(find.text('Legacy Title'), findsOneWidget);
  });
}

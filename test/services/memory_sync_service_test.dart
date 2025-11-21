import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';
import 'package:memories/services/memory_sync_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/capture_state.dart';

// Mock classes
class MockOfflineQueueService extends Mock implements OfflineQueueService {}

class MockOfflineStoryQueueService extends Mock implements OfflineStoryQueueService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockMemorySaveService extends Mock implements MemorySaveService {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(QueuedMoment(
      localId: 'fallback',
      memoryType: 'moment',
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(QueuedStory(
      localId: 'fallback',
      memoryType: 'story',
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(const CaptureState());
  });

  group('MemorySyncService', () {
    late MockOfflineQueueService mockQueueService;
    late MockOfflineStoryQueueService mockStoryQueueService;
    late MockConnectivityService mockConnectivity;
    late MockMemorySaveService mockSaveService;
    late MemorySyncService syncService;

    setUp(() {
      mockQueueService = MockOfflineQueueService();
      mockStoryQueueService = MockOfflineStoryQueueService();
      mockConnectivity = MockConnectivityService();
      mockSaveService = MockMemorySaveService();

      syncService = MemorySyncService(
        mockQueueService,
        mockStoryQueueService,
        mockConnectivity,
        mockSaveService,
      );
    });

    tearDown(() {
      syncService.dispose();
    });

    group('SyncCompleteEvent', () {
      test('emits event with correct fields when moment syncs', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-1',
          memoryType: 'moment',
          inputText: 'Test moment',
          createdAt: DateTime.now(),
        );

        final saveResult = MemorySaveResult(
          memoryId: 'server-1',
          photoUrls: [],
          videoUrls: [],
          hasLocation: false,
        );

        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
        when(() => mockQueueService.getByStatus('queued'))
            .thenAnswer((_) async => [queuedMoment]);
        when(() => mockQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('queued'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockQueueService.update(any()))
            .thenAnswer((_) async => {});
        when(() => mockSaveService.saveMemory(state: any(named: 'state')))
            .thenAnswer((_) async => saveResult);
        when(() => mockQueueService.remove(any())).thenAnswer((_) async => {});

        final events = <SyncCompleteEvent>[];
        final subscription = syncService.syncCompleteStream.listen((event) {
          events.add(event);
        });

        await syncService.syncQueuedMemories();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(events.length, 1);
        expect(events.first.localId, 'local-1');
        expect(events.first.serverId, 'server-1');
        expect(events.first.memoryType, MemoryType.moment);

        await subscription.cancel();
      });

      test('emits event with correct fields when story syncs', () async {
        final queuedStory = QueuedStory(
          localId: 'local-story-1',
          memoryType: 'story',
          inputText: 'Test story',
          createdAt: DateTime.now(),
        );

        final saveResult = MemorySaveResult(
          memoryId: 'server-story-1',
          photoUrls: [],
          videoUrls: [],
          hasLocation: false,
        );

        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
        when(() => mockQueueService.getByStatus('queued'))
            .thenAnswer((_) async => []);
        when(() => mockQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('queued'))
            .thenAnswer((_) async => [queuedStory]);
        when(() => mockStoryQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.update(any()))
            .thenAnswer((_) async => {});
        when(() => mockSaveService.saveMemory(state: any(named: 'state')))
            .thenAnswer((_) async => saveResult);
        when(() => mockStoryQueueService.remove(any()))
            .thenAnswer((_) async => {});

        final events = <SyncCompleteEvent>[];
        final subscription = syncService.syncCompleteStream.listen((event) {
          events.add(event);
        });

        await syncService.syncQueuedMemories();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(events.length, 1);
        expect(events.first.localId, 'local-story-1');
        expect(events.first.serverId, 'server-story-1');
        expect(events.first.memoryType, MemoryType.story);

        await subscription.cancel();
      });

      test('emits event with correct memory type for memento', () async {
        final queuedMemento = QueuedMoment(
          localId: 'local-memento-1',
          memoryType: 'memento',
          inputText: 'Test memento',
          createdAt: DateTime.now(),
        );

        final saveResult = MemorySaveResult(
          memoryId: 'server-memento-1',
          photoUrls: [],
          videoUrls: [],
          hasLocation: false,
        );

        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
        when(() => mockQueueService.getByStatus('queued'))
            .thenAnswer((_) async => [queuedMemento]);
        when(() => mockQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('queued'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockQueueService.update(any()))
            .thenAnswer((_) async => {});
        when(() => mockSaveService.saveMemory(state: any(named: 'state')))
            .thenAnswer((_) async => saveResult);
        when(() => mockQueueService.remove(any())).thenAnswer((_) async => {});

        final events = <SyncCompleteEvent>[];
        final subscription = syncService.syncCompleteStream.listen((event) {
          events.add(event);
        });

        await syncService.syncQueuedMemories();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(events.length, 1);
        expect(events.first.memoryType, MemoryType.memento);

        await subscription.cancel();
      });

      test('does not emit event when sync fails', () async {
        final queuedMoment = QueuedMoment(
          localId: 'local-1',
          memoryType: 'moment',
          inputText: 'Test moment',
          createdAt: DateTime.now(),
        );

        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);
        when(() => mockQueueService.getByStatus('queued'))
            .thenAnswer((_) async => [queuedMoment]);
        when(() => mockQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('queued'))
            .thenAnswer((_) async => []);
        when(() => mockStoryQueueService.getByStatus('failed'))
            .thenAnswer((_) async => []);
        when(() => mockQueueService.update(any()))
            .thenAnswer((_) async => {});
        when(() => mockSaveService.saveMemory(state: any(named: 'state')))
            .thenThrow(Exception('Sync failed'));

        final events = <SyncCompleteEvent>[];
        final subscription = syncService.syncCompleteStream.listen((event) {
          events.add(event);
        });

        await syncService.syncQueuedMemories();

        await Future.delayed(const Duration(milliseconds: 100));

        expect(events.length, 0);

        await subscription.cancel();
      });
    });
  });
}


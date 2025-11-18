import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories/services/audio_cache_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  group('AudioCacheService', () {
    late AudioCacheService service;
    late Directory tempDir;

    setUp(() async {
      service = AudioCacheService();
      tempDir = await getTemporaryDirectory();
    });

    tearDown(() async {
      // Clean up test files
      try {
        final cacheDir = await service.getCacheDirectoryPath();
        final dir = Directory(cacheDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('storeAudioFile stores audio file and returns cached path', () async {
      // Create a temporary source file
      final sourceFile = File('${tempDir.path}/test_audio.m4a');
      await sourceFile.writeAsString('test audio content');

      final sessionId = 'test-session-1';
      final cachedPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
        metadata: {'duration': 45.5, 'locale': 'en-US'},
      );

      // Verify file was copied to cache
      expect(cachedPath, isNotEmpty);
      final cachedFile = File(cachedPath);
      expect(await cachedFile.exists(), isTrue);
      expect(await cachedFile.readAsString(), equals('test audio content'));

      // Verify session tracking
      expect(service.getAudioPath(sessionId), equals(cachedPath));
      expect(await service.hasAudioFile(sessionId), isTrue);
    });

    test('storeAudioFile reuses existing file for same session (retry scenario)', () async {
      // Create a temporary source file
      final sourceFile = File('${tempDir.path}/test_audio.m4a');
      await sourceFile.writeAsString('test audio content');

      final sessionId = 'test-session-2';
      
      // First store
      final firstPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
      );

      // Second store with same session ID (simulating retry)
      final secondPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
      );

      // Should return the same path (reuse existing file)
      expect(firstPath, equals(secondPath));
      expect(await File(firstPath).exists(), isTrue);
    });

    test('cleanupAudioFile deletes file when keepIfQueued is false', () async {
      // Create and store a file
      final sourceFile = File('${tempDir.path}/test_audio.m4a');
      await sourceFile.writeAsString('test audio content');

      final sessionId = 'test-session-3';
      final cachedPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
      );

      expect(await File(cachedPath).exists(), isTrue);

      // Cleanup without keeping
      await service.cleanupAudioFile(
        sessionId: sessionId,
        keepIfQueued: false,
      );

      // File should be deleted
      expect(await File(cachedPath).exists(), isFalse);
      expect(service.getAudioPath(sessionId), isNull);
    });

    test('cleanupAudioFile keeps file when keepIfQueued is true', () async {
      // Create and store a file
      final sourceFile = File('${tempDir.path}/test_audio.m4a');
      await sourceFile.writeAsString('test audio content');

      final sessionId = 'test-session-4';
      final cachedPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
      );

      expect(await File(cachedPath).exists(), isTrue);

      // Cleanup with keepIfQueued = true
      await service.cleanupAudioFile(
        sessionId: sessionId,
        keepIfQueued: true,
      );

      // File should still exist
      expect(await File(cachedPath).exists(), isTrue);
      // But tracking should be removed
      expect(service.getAudioPath(sessionId), isNull);
    });

    test('storeAudioFile throws AudioCacheException when source file does not exist', () async {
      final sessionId = 'test-session-5';
      
      expect(
        () => service.storeAudioFile(
          sourcePath: '/nonexistent/path/audio.m4a',
          sessionId: sessionId,
        ),
        throwsA(isA<AudioCacheException>()),
      );
    });

    test('getAudioPath returns null for unknown session', () {
      expect(service.getAudioPath('unknown-session'), isNull);
    });

    test('hasAudioFile returns false for unknown session', () async {
      expect(await service.hasAudioFile('unknown-session'), isFalse);
    });

    test('cleanupAllTemporaryFiles removes untracked files', () async {
      // Create a tracked file
      final sourceFile1 = File('${tempDir.path}/test_audio1.m4a');
      await sourceFile1.writeAsString('content1');
      final sessionId1 = 'session-1';
      final trackedPath = await service.storeAudioFile(
        sourcePath: sourceFile1.path,
        sessionId: sessionId1,
      );

      // Create an untracked file manually in cache directory
      final cacheDir = await service.getCacheDirectoryPath();
      final untrackedFile = File('$cacheDir/untracked.m4a');
      await untrackedFile.writeAsString('untracked content');

      expect(await File(trackedPath).exists(), isTrue);
      expect(await untrackedFile.exists(), isTrue);

      // Cleanup temporary files
      await service.cleanupAllTemporaryFiles();

      // Tracked file should still exist
      expect(await File(trackedPath).exists(), isTrue);
      // Untracked file should be deleted
      expect(await untrackedFile.exists(), isFalse);
    });

    test('getCacheSize returns total size of cached files', () async {
      // Create and store multiple files
      final sourceFile1 = File('${tempDir.path}/test1.m4a');
      await sourceFile1.writeAsString('content1');
      await service.storeAudioFile(
        sourcePath: sourceFile1.path,
        sessionId: 'session-1',
      );

      final sourceFile2 = File('${tempDir.path}/test2.m4a');
      await sourceFile2.writeAsString('content2');
      await service.storeAudioFile(
        sourcePath: sourceFile2.path,
        sessionId: 'session-2',
      );

      final cacheSize = await service.getCacheSize();
      expect(cacheSize, greaterThan(0));
      // Should be at least the size of both files
      expect(cacheSize, greaterThanOrEqualTo(16)); // 'content1' + 'content2' = 16 bytes
    });

    test('clearSessionTracking removes tracking without deleting files', () async {
      // Create and store a file
      final sourceFile = File('${tempDir.path}/test_audio.m4a');
      await sourceFile.writeAsString('test audio content');

      final sessionId = 'test-session-6';
      final cachedPath = await service.storeAudioFile(
        sourcePath: sourceFile.path,
        sessionId: sessionId,
      );

      expect(service.getAudioPath(sessionId), isNotNull);

      // Clear tracking
      service.clearSessionTracking();

      // Tracking should be removed
      expect(service.getAudioPath(sessionId), isNull);
      // But file should still exist
      expect(await File(cachedPath).exists(), isTrue);
    });
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/memory_type.dart';

void main() {
  group('CaptureState.canSave - Validation Rules', () {
    group('Stories', () {
      test('can save with audio only (no text, no media)', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          audioPath: '/path/to/audio.m4a',
        );
        expect(state.canSave, isTrue);
      });

      test('can save with audio + text', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          audioPath: '/path/to/audio.m4a',
          inputText: 'Some text',
        );
        expect(state.canSave, isTrue);
      });

      test('can save with audio + media', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          audioPath: '/path/to/audio.m4a',
          photoPaths: ['/path/to/photo.jpg'],
        );
        expect(state.canSave, isTrue);
      });

      test('cannot save without audio (even with text/media)', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          inputText: 'Some text',
          photoPaths: ['/path/to/photo.jpg'],
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with empty audio path', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          audioPath: '',
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with null audio path', () {
        const state = CaptureState(
          memoryType: MemoryType.story,
          audioPath: null,
        );
        expect(state.canSave, isFalse);
      });
    });

    group('Moments', () {
      test('can save with inputText only', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Some description text',
        );
        expect(state.canSave, isTrue);
      });

      test('can save with photo only', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          photoPaths: ['/path/to/photo.jpg'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with video only', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          videoPaths: ['/path/to/video.mp4'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with inputText + media', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Some description',
          photoPaths: ['/path/to/photo.jpg'],
          videoPaths: ['/path/to/video.mp4'],
        );
        expect(state.canSave, isTrue);
      });

      test('cannot save with tags only', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with empty state', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with whitespace-only inputText', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: '   \n\t  ',
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with null inputText and no media', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: null,
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with empty string inputText and no media', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: '',
        );
        expect(state.canSave, isFalse);
      });

      test('can save with tags + inputText', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          inputText: 'Some description',
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with tags + photo', () {
        const state = CaptureState(
          memoryType: MemoryType.moment,
          photoPaths: ['/path/to/photo.jpg'],
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isTrue);
      });
    });

    group('Mementos', () {
      test('can save with inputText only', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: 'Some description text',
        );
        expect(state.canSave, isTrue);
      });

      test('can save with photo only', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          photoPaths: ['/path/to/photo.jpg'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with video only', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          videoPaths: ['/path/to/video.mp4'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with inputText + media', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: 'Some description',
          photoPaths: ['/path/to/photo.jpg'],
          videoPaths: ['/path/to/video.mp4'],
        );
        expect(state.canSave, isTrue);
      });

      test('cannot save with tags only', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with empty state', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with whitespace-only inputText', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: '   \n\t  ',
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with null inputText and no media', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: null,
        );
        expect(state.canSave, isFalse);
      });

      test('cannot save with empty string inputText and no media', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: '',
        );
        expect(state.canSave, isFalse);
      });

      test('can save with tags + inputText', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          inputText: 'Some description',
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isTrue);
      });

      test('can save with tags + photo', () {
        const state = CaptureState(
          memoryType: MemoryType.memento,
          photoPaths: ['/path/to/photo.jpg'],
          tags: ['tag1', 'tag2'],
        );
        expect(state.canSave, isTrue);
      });
    });
  });
}


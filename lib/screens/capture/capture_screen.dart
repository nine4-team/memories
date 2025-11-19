import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/media_picker_provider.dart';
import 'package:memories/providers/queue_status_provider.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
import 'package:memories/utils/platform_utils.dart';
import 'package:memories/widgets/media_tray.dart';
import 'package:memories/widgets/queue_status_chips.dart';

/// Unified capture screen for creating Moments, Stories, and Mementos
///
/// Provides:
/// - Memory type toggles (Moment/Story/Memento)
/// - Dictation controls
/// - Optional description input
/// - Media attachment (photos/videos)
/// - Tagging
/// - Save/Cancel actions
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _descriptionController = TextEditingController();
  bool _isSaving = false;
  String? _saveProgressMessage;
  double? _saveProgress;
  bool _hasInitializedDescription = false;

  @override
  void initState() {
    super.initState();
    // Initialize input text controller from capture state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(captureStateNotifierProvider);
      if (state.inputText != null && !_hasInitializedDescription) {
        _descriptionController.text = state.inputText!;
        _hasInitializedDescription = true;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Sync input text controller with state when state changes (e.g., from dictation)
  void _syncInputTextController(String? inputText) {
    // Only update controller if it differs from current text to avoid triggering onChanged
    final currentText = _descriptionController.text;
    final newText = inputText ?? '';
    if (currentText != newText) {
      _descriptionController.text = newText;
    }
  }

  Future<void> _handleAddPhoto() async {
    final mediaPicker = ref.read(mediaPickerServiceProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final path = source == ImageSource.camera
        ? await mediaPicker.pickPhotoFromCamera()
        : await mediaPicker.pickPhotoFromGallery();

    if (path != null && mounted) {
      notifier.addPhoto(path);
    }
  }

  Future<void> _handleAddVideo() async {
    final mediaPicker = ref.read(mediaPickerServiceProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final path = source == ImageSource.camera
        ? await mediaPicker.pickVideoFromCamera()
        : await mediaPicker.pickVideoFromGallery();

    if (path != null && mounted) {
      notifier.addVideo(path);
    }
  }

  Future<void> _handleAddTag() async {
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              notifier.addTag(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                notifier.addTag(textController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    textController.dispose();
  }

  Future<void> _handleSave() async {
    final state = ref.read(captureStateNotifierProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    if (!state.canSave) {
      final message = state.memoryType == MemoryType.story
          ? 'Please record audio to save'
          : state.memoryType == MemoryType.memento
              ? 'Please add description text or at least one photo/video'
              : 'Please add description text or at least one photo/video';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
      return;
    }

    if (_isSaving) {
      return; // Prevent double-save
    }

    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
      _saveProgressMessage = 'Preparing...';
    });

    try {
      // Step 1: Capture location metadata
      _saveProgressMessage = 'Capturing location...';
      _saveProgress = 0.05;
      setState(() {});

      await notifier.captureLocation();

      // Step 2: Set captured timestamp
      final capturedAt = DateTime.now();
      notifier.setCapturedAt(capturedAt);
      final finalState = ref.read(captureStateNotifierProvider);

      // Step 3: Handle Story vs Moment/Memento saving
      if (finalState.memoryType == MemoryType.story) {
        // For Stories, queue for offline sync
        // MemorySyncService will automatically sync when connectivity is restored
        // Check connectivity to determine if we should queue
        final connectivityService = ref.read(connectivityServiceProvider);
        final isOnline = await connectivityService.isOnline();

        try {
          // Queue story for sync (MemorySyncService handles automatic syncing)
          // This queues whenever uploads cannot proceed (offline or when upload service unavailable)
          final storyQueueService = ref.read(offlineStoryQueueServiceProvider);
          final localId = OfflineStoryQueueService.generateLocalId();

          // Check for duplicate submissions: if a story with identical content is already queued,
          // update it instead of creating a duplicate. The deterministic local ID prevents
          // duplicate submissions during the same save operation.
          final queuedStory = QueuedStory.fromCaptureState(
            localId: localId,
            state: finalState,
            audioPath: finalState.audioPath,
            audioDuration: finalState.audioDuration,
            capturedAt: capturedAt,
          );
          await storyQueueService.enqueue(queuedStory);

          // Invalidate queue status to refresh UI (shows queued/syncing badges)
          ref.invalidate(queueStatusProvider);

          if (mounted) {
            // Reset saving state before navigation
            setState(() {
              _isSaving = false;
              _saveProgressMessage = null;
              _saveProgress = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isOnline
                      ? 'Story queued for sync'
                      : 'Story queued for sync when connection is restored',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
            await notifier.clear(keepAudioIfQueued: true);
            // Only pop if there's a route to pop (i.e., if this screen was pushed)
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            return;
          }
        } catch (e) {
          // Handle queue errors gracefully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to queue story: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _handleSave(),
                ),
              ),
            );
          }
          // Re-throw to be caught by outer catch block
          rethrow;
        }
      }

      // Step 3: Save moment with progress updates (or queue if offline)
      final saveService = ref.read(memorySaveServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);
      MemorySaveResult? result;

      try {
        result = await saveService.saveMoment(
          state: finalState,
          onProgress: ({message, progress}) {
            if (mounted) {
              setState(() {
                _saveProgressMessage = message;
                _saveProgress = progress;
              });
            }
          },
        );
      } on OfflineException {
        // Queue for offline sync
        final localId = OfflineQueueService.generateLocalId();
        final queuedMoment = QueuedMoment.fromCaptureState(
          localId: localId,
          state: finalState,
          capturedAt: capturedAt,
        );
        await queueService.enqueue(queuedMoment);

        // Invalidate queue status to refresh UI
        ref.invalidate(queueStatusProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Memory queued for sync when connection is restored'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          await notifier.clear(keepAudioIfQueued: true);
          // Only pop if there's a route to pop (i.e., if this screen was pushed)
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }
      }

      if (result == null) return; // Should not happen, but safety check

      // Step 4: Show success message and navigate to detail view
      if (mounted) {
        final mediaCount = result.photoUrls.length + result.videoUrls.length;
        final locationText = result.hasLocation ? ' with location' : '';
        final mediaText = mediaCount > 0
            ? ' ($mediaCount ${mediaCount == 1 ? 'item' : 'items'})'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memory saved$locationText$mediaText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear state and navigate to detail view
        await notifier.clear();
        // Only pop if there's a route to pop (i.e., if this screen was pushed)
        // If this is the root screen in navigation shell, just navigate to detail
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        // Navigate to moment detail view
        final savedMomentId = result.momentId;
        if (savedMomentId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MomentDetailScreen(momentId: savedMomentId),
            ),
          );
        }
      }
    } on OfflineException {
      // Already handled above, but catch here to prevent generic error
      return;
    } on StorageQuotaException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSave(),
            ),
          ),
        );
      }
    } on PermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleSave(),
            ),
          ),
        );
      }
      notifier.setError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveProgressMessage = null;
          _saveProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureStateNotifierProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    // Sync input text controller when state.inputText changes (e.g., from dictation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInputTextController(state.inputText);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Memory'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Queue status chips
            const QueueStatusChips(),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Memory type toggles at top
                    _MemoryTypeToggle(
                      selectedType: state.memoryType,
                      onTypeChanged: (type) => notifier.setMemoryType(type),
                    ),
                    // Centered capture controls section
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Media add buttons (Tag, Video, Photo)
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  label: 'Add tag',
                                  button: true,
                                  child: OutlinedButton.icon(
                                    onPressed: _handleAddTag,
                                    icon: const Icon(Icons.tag, size: 18),
                                    label: const Text('Tag',
                                        style: TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Semantics(
                                  label: 'Add video',
                                  button: true,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        state.canAddVideo ? _handleAddVideo : null,
                                    icon: const Icon(Icons.videocam, size: 18),
                                    label: const Text('Video',
                                        style: TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Semantics(
                                  label: 'Add photo',
                                  button: true,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        state.canAddPhoto ? _handleAddPhoto : null,
                                    icon: const Icon(Icons.photo_camera, size: 18),
                                    label: const Text('Photo',
                                        style: TextStyle(fontSize: 13)),
                                    style: OutlinedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Swipeable input container (dictation and type modes) - EXPANDABLE
                          _SwipeableInputContainer(
                            inputMode: state.inputMode,
                            memoryType: state.memoryType,
                            isDictating: state.isDictating,
                            transcript: state.inputText ?? '',
                            elapsedDuration: state.elapsedDuration,
                            errorMessage: state.errorMessage,
                            descriptionController: _descriptionController,
                            onInputModeChanged: (mode) => notifier.setInputMode(mode),
                            onStartDictation: () => notifier.startDictation(),
                            onStopDictation: () => notifier.stopDictation(),
                            onCancelDictation: () => notifier.cancelDictation(),
                            onTextChanged: (value) => notifier
                                .updateInputText(value.isEmpty ? null : value),
                          ),
                        ],
                      ),
                    ),
                    // Media tray and tags at bottom (scrollable if needed)
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Media tray
                          MediaTray(
                            photoPaths: state.photoPaths,
                            videoPaths: state.videoPaths,
                            onPhotoRemoved: (index) => notifier.removePhoto(index),
                            onVideoRemoved: (index) => notifier.removeVideo(index),
                            canAddPhoto: state.canAddPhoto,
                            canAddVideo: state.canAddVideo,
                          ),
                          const SizedBox(height: 16),

                          // Display tags as chips if any exist
                          if (state.tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (int i = 0; i < state.tags.length; i++)
                                  InputChip(
                                    label: Text(state.tags[i]),
                                    onDeleted: () => notifier.removeTag(i),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom section with buttons anchored above navigation bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Save button with progress indicator
                  Semantics(
                    label: 'Save memory',
                    button: true,
                    child: ElevatedButton(
                      onPressed:
                          (state.canSave && !_isSaving) ? _handleSave : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 48),
                      ),
                      child: _isSaving
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label:
                                      _saveProgressMessage ?? 'Saving memory',
                                  value: _saveProgress != null
                                      ? '${(_saveProgress! * 100).toInt()}% complete'
                                      : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      if (_saveProgressMessage != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _saveProgressMessage!,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                      if (_saveProgress != null) ...[
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: _saveProgress,
                                          backgroundColor:
                                              Colors.white.withOpacity(0.3),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Colors.white),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTypeToggle extends StatelessWidget {
  final MemoryType selectedType;
  final ValueChanged<MemoryType> onTypeChanged;

  const _MemoryTypeToggle({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MemoryType>(
      segments: [
        ButtonSegment<MemoryType>(
          value: MemoryType.moment,
          label: Text(MemoryType.moment.displayName),
          icon: const Icon(Icons.access_time),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.story,
          label: Text(MemoryType.story.displayName),
          icon: const Icon(Icons.book),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.memento,
          label: Text(MemoryType.memento.displayName),
          icon: const Icon(Icons.inventory_2),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (Set<MemoryType> selection) {
        if (selection.isNotEmpty) {
          onTypeChanged(selection.first);
        }
      },
    );
  }
}

/// Text container widget for dictation mode - contains only the transcription display
/// This is separated from controls/hints to ensure consistent sizing with type mode
class _DictationTextContainer extends StatelessWidget {
  final String transcript;
  final MemoryType memoryType;
  final bool isDictating;
  final bool showSwipeHint;
  final ScrollController? scrollController;

  const _DictationTextContainer({
    required this.transcript,
    required this.memoryType,
    required this.isDictating,
    required this.showSwipeHint,
    this.scrollController,
  });

  /// Get contextual hint text based on memory type (for inside container)
  String _getTapMicText(MemoryType memoryType) {
    switch (memoryType) {
      case MemoryType.moment:
        return 'Describe the moment';
      case MemoryType.story:
        return 'Tell your story';
      case MemoryType.memento:
        return 'Describe the object and its significance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSimulator = PlatformUtils.isSimulator;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine display text - show immediately without delay
          final displayText = transcript.isNotEmpty
              ? transcript
              : (isSimulator
                  ? 'Dictation unavailable on simulator'
                  : (showSwipeHint ? _getTapMicText(memoryType) : ''));

          final isEmpty = transcript.isEmpty && !isDictating;

          // Build the transcript widget - use AnimatedSwitcher for smooth transitions
          // When empty, center the placeholder text both vertically and horizontally
          // When not empty, align content to top-left and allow scrolling when content exceeds container
          final transcriptWidget = isEmpty
              ? Center(
                  child: Semantics(
                    label: 'Dictation transcript',
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        displayText,
                        key: ValueKey(displayText),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxHeight: constraints.maxHeight.isInfinite
                        ? double.infinity
                        : constraints.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    // SingleChildScrollView naturally aligns content to top-left
                    child: Semantics(
                      label: 'Dictation transcript',
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          displayText,
                          key: ValueKey(displayText),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                  ),
                );

          // Return the transcript widget - it will expand to fill available space
          // since the parent Container is wrapped in Expanded
          return transcriptWidget;
        },
      ),
    );
  }
}

/// Swipeable input container that allows switching between dictation and type modes
class _SwipeableInputContainer extends ConsumerStatefulWidget {
  final InputMode inputMode;
  final MemoryType memoryType;
  final bool isDictating;
  final String transcript;
  final Duration elapsedDuration;
  final String? errorMessage;
  final TextEditingController descriptionController;
  final ValueChanged<InputMode> onInputModeChanged;
  final VoidCallback onStartDictation;
  final VoidCallback onStopDictation;
  final VoidCallback onCancelDictation;
  final ValueChanged<String> onTextChanged;

  const _SwipeableInputContainer({
    required this.inputMode,
    required this.memoryType,
    required this.isDictating,
    required this.transcript,
    required this.elapsedDuration,
    this.errorMessage,
    required this.descriptionController,
    required this.onInputModeChanged,
    required this.onStartDictation,
    required this.onStopDictation,
    required this.onCancelDictation,
    required this.onTextChanged,
  });

  @override
  ConsumerState<_SwipeableInputContainer> createState() =>
      _SwipeableInputContainerState();
}

class _SwipeableInputContainerState
    extends ConsumerState<_SwipeableInputContainer> {
  late PageController _pageController;
  bool _isDragging = false;
  final FocusNode _textFieldFocusNode = FocusNode();
  final ScrollController _dictationScrollController = ScrollController();
  double? _dragStartX;
  double? _cachedHeight; // Cache height to prevent resizing during swipe
  bool _isTextFieldFocused = false;

  @override
  void initState() {
    super.initState();
    // Initialize page controller to dictation mode (page 0) or type mode (page 1)
    _pageController = PageController(
      initialPage: widget.inputMode == InputMode.dictation ? 0 : 1,
    );

    // Listen to page controller position changes to detect dragging
    _pageController.addListener(_onPageControllerChanged);

    // Listen to focus changes to update text alignment
    _textFieldFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_textFieldFocusNode.hasFocus != _isTextFieldFocused) {
      setState(() {
        _isTextFieldFocused = _textFieldFocusNode.hasFocus;
      });
    }
  }

  void _onPageControllerChanged() {
    if (!_pageController.hasClients) return;

    final page = _pageController.page ?? 0;
    final isDragging = page % 1 != 0; // Page is fractional when dragging

    if (_isDragging != isDragging) {
      setState(() {
        _isDragging = isDragging;
        // Reset cached height when drag ends to allow recalculation if needed
        if (!isDragging) {
          _cachedHeight = null;
        }
      });
    }
  }

  @override
  void didUpdateWidget(_SwipeableInputContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync page controller if input mode changed externally
    if (oldWidget.inputMode != widget.inputMode) {
      final targetPage = widget.inputMode == InputMode.dictation ? 0 : 1;
      if (_pageController.hasClients &&
          _pageController.page?.round() != targetPage) {
        // Reset cached height when mode changes externally to allow recalculation
        _cachedHeight = null;
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          // When switching to dictation mode, scroll to the end of the text
          if (widget.inputMode == InputMode.dictation && widget.transcript.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_dictationScrollController.hasClients) {
                _dictationScrollController.animateTo(
                  _dictationScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
          
          // When switching to type mode, move cursor to the end of the text
          if (widget.inputMode == InputMode.type && widget.descriptionController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final text = widget.descriptionController.text;
              widget.descriptionController.selection = TextSelection.fromPosition(
                TextPosition(offset: text.length),
              );
            });
          }
        });
      }
    }
    
    // When transcript changes and we're in dictation mode, scroll to end
    if (widget.inputMode == InputMode.dictation &&
        oldWidget.transcript != widget.transcript &&
        widget.transcript.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dictationScrollController.hasClients) {
          _dictationScrollController.animateTo(
            _dictationScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageControllerChanged);
    _pageController.dispose();
    _textFieldFocusNode.removeListener(_onFocusChanged);
    _textFieldFocusNode.dispose();
    _dictationScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final newMode = page == 0 ? InputMode.dictation : InputMode.type;
    if (newMode != widget.inputMode) {
      // Reset cached height when page changes to allow recalculation
      _cachedHeight = null;
      widget.onInputModeChanged(newMode);
      
      // When switching to dictation mode, scroll to the end of the text
      if (newMode == InputMode.dictation && widget.transcript.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_dictationScrollController.hasClients) {
            _dictationScrollController.animateTo(
              _dictationScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      
      // When switching to type mode, move cursor to the end of the text
      if (newMode == InputMode.type && widget.descriptionController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final text = widget.descriptionController.text;
          widget.descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      }
    }
  }

  /// Get placeholder text based on memory type
  String _getPlaceholderText(MemoryType memoryType) {
    switch (memoryType) {
      case MemoryType.moment:
        return 'Describe the moment';
      case MemoryType.story:
        return 'Tell your story';
      case MemoryType.memento:
        return 'Describe the object and its significance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate max height: screen height minus app bar, queue chips, padding, other content, and navigation bar
        // Use a reasonable max height that ensures content doesn't scroll beyond the menu
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.4; // Max 40% of screen height
        final minHeight = 200.0; // Minimum height for consistent layout

        // Cache height calculation - only recalculate if not dragging or if cached value is null
        // This prevents resizing during swipe transitions
        if (_cachedHeight == null || !_isDragging) {
          _cachedHeight = constraints.maxHeight.isInfinite
              ? minHeight.clamp(minHeight, maxHeight)
              : constraints.maxHeight.clamp(minHeight, maxHeight);
        }

        // Account for simulator banner if shown (it's outside the text container area)
        final simulatorBannerHeight =
            (isIOS && PlatformUtils.isSimulator) ? 60.0 : 0.0;
        final adjustedTotalHeight = _cachedHeight! + simulatorBannerHeight;

        final hasError = widget.errorMessage != null;

        // Swipe hints should ALWAYS be visible - never hide them
        final shouldShowDictationHint = true;

        return SizedBox(
          height: adjustedTotalHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              // Page 0: Dictation mode
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Simulator warning banner (if applicable)
                  if (isIOS && PlatformUtils.isSimulator)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Voice dictation is unavailable on iOS Simulator. Please test on a physical device.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Text container - Expanded so it can grow, starts at same size as type mode
                  Expanded(
                    child: isIOS
                        ? _DictationTextContainer(
                            transcript: widget.transcript,
                            memoryType: widget.memoryType,
                            isDictating: widget.isDictating,
                            showSwipeHint: shouldShowDictationHint,
                            scrollController: _dictationScrollController,
                          )
                        : // Platform not supported banner
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Voice dictation is currently available on iOS. Android support coming soon.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  // Swipe hint - ALWAYS visible, never hide
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tap to talk',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_downward,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Swipe to type',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // AudioControlsDecorator for mic button
                  AudioControlsDecorator(
                    isListening: widget.isDictating,
                    elapsedTime: widget.elapsedDuration,
                    onMicPressed: isIOS
                        ? (widget.isDictating
                            ? widget.onStopDictation
                            : widget.onStartDictation)
                        : null,
                    onCancelPressed:
                        widget.isDictating ? widget.onCancelDictation : null,
                    waveformController: ref.watch(waveformControllerProvider),
                    child: const SizedBox(height: 0),
                  ),
                  // Error message display
                  if (widget.errorMessage != null)
                    Semantics(
                      label: 'Error message',
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Page 1: Type mode
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text container - Expanded so it can grow, starts at same size as dictation mode
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (details) {
                        // Unfocus text field when horizontal drag starts to allow PageView swipe
                        _textFieldFocusNode.unfocus();
                        _dragStartX = details.globalPosition.dx;
                      },
                      onHorizontalDragUpdate: (details) {
                        // If horizontal drag is significant, ensure text field stays unfocused
                        if (_dragStartX != null) {
                          final deltaX =
                              (details.globalPosition.dx - _dragStartX!).abs();
                          if (deltaX > 10) {
                            _textFieldFocusNode.unfocus();
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Semantics(
                          label: 'Input text',
                          textField: true,
                          hint: _getPlaceholderText(widget.memoryType),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final shouldShowPlaceholder =
                                  widget.descriptionController.text.isEmpty &&
                                      !_isTextFieldFocused;
                              return ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                  maxHeight: constraints.maxHeight.isInfinite
                                      ? double.infinity
                                      : constraints.maxHeight,
                                ),
                                child: Stack(
                                  children: [
                                    TextField(
                                      controller: widget.descriptionController,
                                      focusNode: _textFieldFocusNode,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      maxLines: null,
                                      expands: true,
                                      textAlign: TextAlign.start,
                                      textAlignVertical: TextAlignVertical.top,
                                      keyboardType: TextInputType.multiline,
                                      onChanged: (value) {
                                        widget.onTextChanged(value);
                                        // Update placeholder visibility when text changes
                                        setState(() {});
                                      },
                                    ),
                                    if (shouldShowPlaceholder)
                                      IgnorePointer(
                                        child: SizedBox.expand(
                                          child: Center(
                                            child: Text(
                                              _getPlaceholderText(
                                                  widget.memoryType),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Swipe hint - ALWAYS visible, never hide
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _SwipeHint(
                      currentMode: InputMode.type,
                      isVisible: true,
                    ),
                  ),
                  // Spacer to match AudioControlsDecorator height exactly
                  ExcludeSemantics(
                    child: Visibility(
                      visible: false,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: AudioControlsDecorator(
                        isListening: false,
                        elapsedTime: widget.elapsedDuration,
                        onMicPressed: null,
                        onCancelPressed: null,
                        waveformController:
                            ref.watch(waveformControllerProvider),
                        child: const SizedBox(height: 0),
                      ),
                    ),
                  ),
                  // Spacer for error message area (matches dictation mode layout)
                  if (hasError) const SizedBox(height: 60),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Subtle swipe hint widget showing direction to switch modes
class _SwipeHint extends StatelessWidget {
  final InputMode currentMode;
  final bool isVisible;

  const _SwipeHint({
    required this.currentMode,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final isDictationMode = currentMode == InputMode.dictation;
    final hintText = isDictationMode ? 'Swipe to type' : 'Swipe to talk';
    final arrowIcon = isDictationMode ? Icons.arrow_forward : Icons.arrow_back;

    // Always render but control visibility with opacity to prevent layout shifts
    return Opacity(
      opacity: isVisible ? 1.0 : 0.0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDictationMode) ...[
              Icon(
                arrowIcon,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              hintText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.5),
                    fontSize: 12,
                  ),
            ),
            if (isDictationMode) ...[
              const SizedBox(width: 4),
              Icon(
                arrowIcon,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

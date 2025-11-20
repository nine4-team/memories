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
import 'package:memories/providers/memory_detail_provider.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/media_picker_service.dart';
import 'package:memories/screens/memory/memory_detail_screen.dart';
import 'package:memories/utils/platform_utils.dart';
import 'package:memories/widgets/media_tray.dart';
import 'package:memories/widgets/queue_status_chips.dart';
import 'package:memories/widgets/inspirational_quote.dart';

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
  String? _previousInputText; // Track previous state to detect external changes

  @override
  void initState() {
    super.initState();
    // Initialize input text controller from capture state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(captureStateNotifierProvider);
      if (state.inputText != null && !_hasInitializedDescription) {
        _descriptionController.text = state.inputText!;
        _hasInitializedDescription = true;
        _previousInputText = state.inputText;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Sync input text controller with state when state changes (e.g., from dictation)
  /// Only syncs when state changes from an external source, not from TextField edits
  void _syncInputTextController(String? inputText) {
    final currentText = _descriptionController.text;
    final newText = inputText ?? '';

    // Only sync if:
    // 1. The state actually changed from previous value (indicates external change)
    // 2. AND the controller text doesn't match the new state (needs syncing)
    // This prevents interference when user is typing/deleting, as the controller
    // will already match the state after the onChanged callback updates it
    if (_previousInputText != inputText && currentText != newText) {
      _descriptionController.text = newText;
    }

    // Update previous value for next comparison
    _previousInputText = inputText;
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

    try {
      if (source == ImageSource.camera) {
        // Camera: single photo selection
        final path = await mediaPicker.pickPhotoFromCamera();
        if (path != null && mounted) {
          notifier.addPhoto(path);
        }
      } else {
        // Gallery: multi-photo selection
        final paths = await mediaPicker.pickMultiplePhotos();
        if (paths.isNotEmpty && mounted) {
          // Add each photo (addPhoto will respect the 10-photo limit)
          for (final path in paths) {
            notifier.addPhoto(path);
          }
        }
      }
    } on MediaPickerException catch (e) {
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
            content: Text('Failed to pick photo: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

    try {
      final path = source == ImageSource.camera
          ? await mediaPicker.pickVideoFromCamera()
          : await mediaPicker.pickVideoFromGallery();

      if (path != null && mounted) {
        notifier.addVideo(path);
      }
    } on MediaPickerException catch (e) {
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
            content: Text('Failed to pick video: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleAddTag() async {
    final notifier = ref.read(captureStateNotifierProvider.notifier);

    await showDialog(
      context: context,
      builder: (context) => _AddTagDialog(
        onTagAdded: (tag) => notifier.addTag(tag),
      ),
    );
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

      // Step 3: Save or update memory with progress updates (or queue if offline)
      final saveService = ref.read(memorySaveServiceProvider);
      final queueService = ref.read(offlineQueueServiceProvider);
      MemorySaveResult? result;
      final isEditing = finalState.isEditing;
      final editingMemoryId = finalState.editingMemoryId;

      try {
        if (isEditing && editingMemoryId != null) {
          // Update existing memory
          result = await saveService.updateMemory(
            memoryId: editingMemoryId,
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
        } else {
          // Create new memory
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
        }
      } on OfflineException {
        // Queue for offline sync (only for new memories, not edits)
        if (!isEditing) {
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
        } else {
          // Editing requires online connection
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Editing requires internet connection'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (result == null) return; // Should not happen, but safety check

      // Step 4: Show success message and navigate appropriately
      if (mounted) {
        final mediaCount = result.photoUrls.length + result.videoUrls.length;
        final locationText = result.hasLocation ? ' with location' : '';
        final mediaText = mediaCount > 0
            ? ' ($mediaCount ${mediaCount == 1 ? 'item' : 'items'})'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Memory updated$locationText$mediaText' : 'Memory saved$locationText$mediaText',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear state completely (including editingMemoryId)
        await notifier.clear();

        if (isEditing) {
          // When editing, navigate back to detail screen
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Refresh detail screen to show updated content
          if (editingMemoryId != null) {
            ref.read(memoryDetailNotifierProvider(editingMemoryId).notifier).refresh();
          }
        } else {
          // When creating, navigate to detail view
          // Only pop if there's a route to pop (i.e., if this screen was pushed)
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Navigate to memory detail view
          final savedMemoryId = result.memoryId;
          if (savedMemoryId.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MemoryDetailScreen(memoryId: savedMemoryId),
              ),
            );
          }
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

    // Initialize previous input text if not set
    if (_previousInputText == null) {
      _previousInputText = state.inputText;
    }

    // Sync input text controller when state.inputText changes (e.g., from dictation)
    // Only syncs when state changes from external source, not from TextField edits
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInputTextController(state.inputText);
    });

    return PopScope(
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && state.hasUnsavedChanges) {
          final shouldCancel = await _showCancelConfirmation(context);
          if (shouldCancel == true && mounted) {
            await _handleCancel(context, ref, notifier);
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: _MemoryTypeToggle(
            selectedType: state.memoryType,
            onTypeChanged: (type) => notifier.setMemoryType(type),
          ),
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
                    // Inspirational quote - hide when media/tags are present to make room
                    InspirationalQuote(
                      showQuote: state.photoPaths.isEmpty &&
                          state.videoPaths.isEmpty &&
                          state.tags.isEmpty &&
                          (state.inputText == null || state.inputText!.isEmpty),
                    ),
                    // Centered capture controls section
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Media add buttons (Tag, Video, Photo)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                label: 'Add tag',
                                button: true,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: _handleAddTag,
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.local_offer,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: 'Add video',
                                button: true,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: state.canAddVideo
                                          ? _handleAddVideo
                                          : null,
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.videocam,
                                          size: 18,
                                          color: state.canAddVideo
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.38),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: 'Add photo',
                                button: true,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: state.canAddPhoto
                                          ? _handleAddPhoto
                                          : null,
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.photo_camera,
                                          size: 18,
                                          color: state.canAddPhoto
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.38),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Combined container for tags and media
                          if (state.photoPaths.isNotEmpty ||
                              state.videoPaths.isNotEmpty ||
                              state.existingPhotoUrls.isNotEmpty ||
                              state.existingVideoUrls.isNotEmpty ||
                              state.tags.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Media strip - horizontally scrolling
                                  if (state.photoPaths.isNotEmpty ||
                                      state.videoPaths.isNotEmpty ||
                                      state.existingPhotoUrls.isNotEmpty ||
                                      state.existingVideoUrls.isNotEmpty)
                                    SizedBox(
                                      height: 100,
                                      child: MediaTray(
                                        photoPaths: state.photoPaths,
                                        videoPaths: state.videoPaths,
                                        existingPhotoUrls: state.existingPhotoUrls,
                                        existingVideoUrls: state.existingVideoUrls,
                                        onPhotoRemoved: (index) =>
                                            notifier.removePhoto(index),
                                        onVideoRemoved: (index) =>
                                            notifier.removeVideo(index),
                                        onExistingPhotoRemoved: state.isEditing
                                            ? (index) => notifier.removeExistingPhoto(index)
                                            : null,
                                        onExistingVideoRemoved: state.isEditing
                                            ? (index) => notifier.removeExistingVideo(index)
                                            : null,
                                        canAddPhoto: state.canAddPhoto,
                                        canAddVideo: state.canAddVideo,
                                      ),
                                    ),
                                  // Spacing between media and tags
                                  if ((state.photoPaths.isNotEmpty ||
                                          state.videoPaths.isNotEmpty) &&
                                      state.tags.isNotEmpty)
                                    const SizedBox(height: 8),
                                  // Tags - horizontally scrolling
                                  if (state.tags.isNotEmpty)
                                    SizedBox(
                                      height: 36,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            for (int i = 0;
                                                i < state.tags.length;
                                                i++)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  right:
                                                      i < state.tags.length - 1
                                                          ? 8
                                                          : 0,
                                                ),
                                                child: InputChip(
                                                  label: Text(
                                                    state.tags[i],
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                  ),
                                                  onDeleted: () =>
                                                      notifier.removeTag(i),
                                                  deleteIcon: Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  backgroundColor: Theme.of(
                                                          context)
                                                      .scaffoldBackgroundColor,
                                                  side: BorderSide.none,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
                            onInputModeChanged: (mode) =>
                                notifier.setInputMode(mode),
                            onStartDictation: () => notifier.startDictation(),
                            onStopDictation: () => notifier.stopDictation(),
                            onCancelDictation: () => notifier.cancelDictation(),
                            onTextChanged: (value) => notifier
                                .updateInputText(value.isEmpty ? null : value),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom section with buttons anchored above navigation bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cancel and Save buttons side by side
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: Semantics(
                          label: 'Cancel',
                          button: true,
                          enabled: state.hasUnsavedChanges || state.isEditing,
                          child: ElevatedButton(
                            onPressed: (state.hasUnsavedChanges || state.isEditing)
                                ? () => _handleCancelWithConfirmation(context, ref, notifier)
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(0, 48),
                              backgroundColor: (state.hasUnsavedChanges || state.isEditing)
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : null,
                              foregroundColor: (state.hasUnsavedChanges || state.isEditing)
                                  ? Theme.of(context).colorScheme.onSurface
                                  : null,
                              elevation: (state.hasUnsavedChanges || state.isEditing) ? 1 : 0,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save button with progress indicator
                      Expanded(
                        child: Semantics(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Show cancel confirmation dialog
  Future<bool?> _showCancelConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  /// Handle cancel with confirmation dialog
  Future<void> _handleCancelWithConfirmation(
    BuildContext context,
    WidgetRef ref,
    CaptureStateNotifier notifier,
  ) async {
    final shouldCancel = await _showCancelConfirmation(context);
    if (shouldCancel == true && mounted) {
      await _handleCancel(context, ref, notifier);
    }
  }

  /// Handle cancel action - clears state and navigates appropriately
  Future<void> _handleCancel(
    BuildContext context,
    WidgetRef ref,
    CaptureStateNotifier notifier,
  ) async {
    final state = ref.read(captureStateNotifierProvider);
    
    // Clear state completely
    await notifier.clear();
    
    // Navigate back if editing (to detail screen)
    // If creating, stay on capture screen (or pop if screen was pushed)
    if (state.isEditing && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFF2B2B2B),
        selectedForegroundColor: const Color(0xFFFFFFFF),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2B2B2B),
      ),
      segments: [
        ButtonSegment<MemoryType>(
          value: MemoryType.moment,
          label: Text(MemoryType.moment.displayName),
          icon: Icon(MemoryType.moment.icon),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.story,
          label: Text(MemoryType.story.displayName),
          icon: Icon(MemoryType.story.icon),
        ),
        ButtonSegment<MemoryType>(
          value: MemoryType.memento,
          label: Text(MemoryType.memento.displayName),
          icon: Icon(MemoryType.memento.icon),
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
class _DictationTextContainer extends ConsumerWidget {
  final String transcript;
  final MemoryType memoryType;
  final bool isDictating;
  final bool showSwipeHint;
  final ScrollController? scrollController;
  final VoidCallback? onMicPressed;
  final VoidCallback? onCancelPressed;
  final Duration elapsedDuration;
  final WaveformController waveformController;

  const _DictationTextContainer({
    required this.transcript,
    required this.memoryType,
    required this.isDictating,
    required this.showSwipeHint,
    this.scrollController,
    this.onMicPressed,
    this.onCancelPressed,
    required this.elapsedDuration,
    required this.waveformController,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isSimulator = PlatformUtils.isSimulator;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    // Add padding at the bottom to prevent text from being hidden behind mic button
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Semantics(
                      label: 'Dictation transcript',
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          displayText,
                          key: ValueKey(displayText),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ),
                  ),
                );

          // Return the transcript widget with AudioControlsDecorator centered horizontally at bottom
          // since the parent Container is wrapped in Expanded
          return Stack(
            children: [
              transcriptWidget,
              // AudioControlsDecorator centered horizontally at the bottom of the container
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: AudioControlsDecorator(
                    isListening: isDictating,
                    elapsedTime: elapsedDuration,
                    onMicPressed: onMicPressed,
                    onCancelPressed: onCancelPressed,
                    waveformController: waveformController,
                    child: const SizedBox(height: 0),
                  ),
                ),
              ),
            ],
          );
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
        _pageController
            .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
            .then((_) {
          // When switching to dictation mode, scroll to the end of the text
          if (widget.inputMode == InputMode.dictation &&
              widget.transcript.isNotEmpty) {
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
          if (widget.inputMode == InputMode.type &&
              widget.descriptionController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final text = widget.descriptionController.text;
              widget.descriptionController.selection =
                  TextSelection.fromPosition(
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
      if (newMode == InputMode.type &&
          widget.descriptionController.text.isNotEmpty) {
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
        final minHeight =
            250.0; // Minimum height for consistent layout - increased for larger initial size

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
                            onMicPressed: widget.isDictating
                                ? widget.onStopDictation
                                : widget.onStartDictation,
                            onCancelPressed: widget.isDictating
                                ? widget.onCancelDictation
                                : null,
                            elapsedDuration: widget.elapsedDuration,
                            waveformController:
                                ref.watch(waveformControllerProvider),
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
                            'Swipe to type',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                  // Error message display (matches dictation mode layout)
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

/// Dialog widget for adding tags
/// Properly manages TextEditingController lifecycle to prevent disposal errors
class _AddTagDialog extends StatefulWidget {
  final ValueChanged<String> onTagAdded;

  const _AddTagDialog({
    required this.onTagAdded,
  });

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final value = _textController.text.trim();
    if (value.isNotEmpty) {
      widget.onTagAdded(value);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tag'),
      content: TextField(
        controller: _textController,
        decoration: const InputDecoration(
          hintText: 'Enter tag name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleSubmit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _handleSubmit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

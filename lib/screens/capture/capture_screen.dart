import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories/models/memory_type.dart';
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
import 'package:memories/widgets/tag_chip_input.dart';

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
              content: const Text('Memory queued for sync when connection is restored'),
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
        final mediaText = mediaCount > 0 ? ' ($mediaCount ${mediaCount == 1 ? 'item' : 'items'})' : '';
        
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Memory type toggles
                    _MemoryTypeToggle(
                      selectedType: state.memoryType,
                      onTypeChanged: (type) => notifier.setMemoryType(type),
                    ),
                    const SizedBox(height: 24),

                    // Dictation control (iOS only)
                    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb)
                      _DictationControl(
                        isDictating: state.isDictating,
                        transcript: state.inputText ?? '',
                        elapsedDuration: state.elapsedDuration,
                        errorMessage: state.errorMessage,
                        onStart: () => notifier.startDictation(),
                        onStop: () => notifier.stopDictation(),
                        onCancel: () => notifier.cancelDictation(),
                      )
                    else if (defaultTargetPlatform != TargetPlatform.iOS && !kIsWeb)
                      // Platform not supported banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Voice dictation is currently available on iOS. Android support coming soon.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Input text field
                    Semantics(
                      label: 'Input text',
                      textField: true,
                      child: TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Add any additional details...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        onChanged: (value) => notifier.updateInputText(value.isEmpty ? null : value),
                      ),
                    ),
                    const SizedBox(height: 24),

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

                    // Media add buttons
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Add photo',
                            button: true,
                            child: OutlinedButton.icon(
                              onPressed: state.canAddPhoto ? _handleAddPhoto : null,
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Photo'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            label: 'Add video',
                            button: true,
                            child: OutlinedButton.icon(
                              onPressed: state.canAddVideo ? _handleAddVideo : null,
                              icon: const Icon(Icons.videocam),
                              label: const Text('Video'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tagging input
                    TagChipInput(
                      tags: state.tags,
                      onTagAdded: (tag) => notifier.addTag(tag),
                      onTagRemoved: (index) => notifier.removeTag(index),
                      hintText: 'Add tags (optional)',
                    ),
                    const SizedBox(height: 32),

                    // Save button with progress indicator
                    Semantics(
                      label: 'Save memory',
                      button: true,
                      child: ElevatedButton(
                        onPressed: (state.canSave && !_isSaving) ? _handleSave : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 48),
                        ),
                        child: _isSaving
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    label: _saveProgressMessage ?? 'Saving memory',
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
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                                            backgroundColor: Colors.white.withOpacity(0.3),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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

class _DictationControl extends ConsumerWidget {
  final bool isDictating;
  final String transcript;
  final Duration elapsedDuration;
  final String? errorMessage;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _DictationControl({
    required this.isDictating,
    required this.transcript,
    this.elapsedDuration = Duration.zero,
    this.errorMessage,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waveformController = ref.watch(waveformControllerProvider);
    final isSimulator = PlatformUtils.isSimulator;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Simulator warning banner
        if (isSimulator)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voice dictation is unavailable on iOS Simulator. Please test on a physical device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        
        // Use AudioControlsDecorator for dictation controls
        AudioControlsDecorator(
          isListening: isDictating,
          elapsedTime: elapsedDuration,
          // Disable mic button when on simulator
          onMicPressed: isSimulator ? null : (isDictating ? onStop : onStart),
          onCancelPressed: isDictating ? onCancel : null,
          waveformController: waveformController,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Semantics(
              label: 'Dictation transcript',
              liveRegion: true,
              child: Text(
                transcript.isEmpty && !isDictating
                    ? (isSimulator 
                        ? 'Dictation unavailable on simulator'
                        : 'Tap the microphone to start dictating')
                    : transcript,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: transcript.isEmpty && !isDictating
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: transcript.isEmpty && !isDictating
                    ? TextAlign.center
                    : TextAlign.start,
              ),
            ),
          ),
        ),
        
        // Error message display
        if (errorMessage != null)
          Semantics(
            label: 'Error message',
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}


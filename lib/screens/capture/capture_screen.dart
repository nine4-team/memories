import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queued_moment.dart';
import 'package:memories/models/queued_story.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/media_picker_provider.dart';
import 'package:memories/providers/queue_status_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/moment_sync_service.dart';
import 'package:memories/services/offline_queue_service.dart';
import 'package:memories/services/offline_story_queue_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/screens/moment/moment_detail_screen.dart';
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
        // For Stories, queue for offline sync (story save service will be implemented in task 8)
        // Check connectivity to determine if we should queue
        final connectivityService = ref.read(connectivityServiceProvider);
        final isOnline = await connectivityService.isOnline();
        
        try {
          // Queue story (will be synced when story save service is available in task 8)
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
            Navigator.of(context).pop();
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
          Navigator.of(context).pop();
          return;
        }
      }

      if (result == null) return; // Should not happen, but safety check

      // Step 4: Show title edit dialog if title was generated
      
      if (mounted && result.generatedTitle != null) {
        final editedTitle = await _showTitleEditDialog(result.generatedTitle!);
        
        // Update title if it was edited
        if (editedTitle != null && editedTitle != result.generatedTitle) {
          final supabase = ref.read(supabaseClientProvider);
          await supabase
              .from('memories')
              .update({'title': editedTitle})
              .eq('id', result.momentId);
        }
      }

      // Step 5: Show success message and navigate to detail view
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
        Navigator.of(context).pop();
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

  Future<String?> _showTitleEditDialog(String initialTitle) async {
    final titleController = TextEditingController(text: initialTitle);
    
    return showDialog<String>(
      context: context,
      builder: (context) => Semantics(
        label: 'Edit title dialog',
        child: AlertDialog(
          title: Semantics(
            label: 'Edit Title',
            header: true,
            child: const Text('Edit Title'),
          ),
          content: Semantics(
            label: 'Title input field',
            textField: true,
            hint: 'Enter title',
            child: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Enter title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLength: 60,
            ),
          ),
          actions: [
            Semantics(
              label: 'Keep original title',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.pop(context, initialTitle),
                child: const Text('Keep Original'),
              ),
            ),
            Semantics(
              label: 'Save edited title',
              button: true,
              child: TextButton(
                onPressed: () {
                  final edited = titleController.text.trim();
                  Navigator.pop(
                    context,
                    edited.isEmpty ? initialTitle : edited,
                  );
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleCancel() async {
    final state = ref.read(captureStateNotifierProvider);
    
      if (state.hasUnsavedChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => Semantics(
          label: 'Discard changes confirmation dialog',
          child: AlertDialog(
            title: Semantics(
              label: 'Discard changes?',
              header: true,
              child: const Text('Discard changes?'),
            ),
            content: Semantics(
              label: 'You have unsaved changes. Are you sure you want to discard them?',
              child: const Text('You have unsaved changes. Are you sure you want to discard them?'),
            ),
            actions: [
              Semantics(
                label: 'Keep editing',
                button: true,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Editing'),
                ),
              ),
              Semantics(
                label: 'Discard changes',
                button: true,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ),
            ],
          ),
        ),
      );

      if (shouldDiscard == true) {
        await ref.read(captureStateNotifierProvider.notifier).clear();
        return true;
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureStateNotifierProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    
    // Sync input text controller when state.inputText changes (e.g., from dictation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInputTextController(state.inputText);
    });

    return WillPopScope(
      onWillPop: _handleCancel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Capture Memory'),
          actions: [
            // Sync now action (in overflow menu)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'sync_now') {
                  await _handleSyncNow(ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sync_now',
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 20),
                      SizedBox(width: 8),
                      Text('Sync Now'),
                    ],
                  ),
                ),
              ],
            ),
            // Cancel button
            TextButton(
              onPressed: () async {
                if (await _handleCancel()) {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Cancel'),
            ),
          ],
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
                
                // Dictation control
                _DictationControl(
                  isDictating: state.isDictating,
                  transcript: state.inputText ?? '',
                  audioLevel: state.audioLevel,
                  elapsedDuration: state.elapsedDuration,
                  errorMessage: state.errorMessage,
                  onStart: () => notifier.startDictation(),
                  onStop: () => notifier.stopDictation(),
                  onCancel: () => notifier.cancelDictation(),
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
      ),
    );
  }

  Future<void> _handleSyncNow(WidgetRef ref) async {
    final syncService = ref.read(momentSyncServiceProvider);
    
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Syncing queued moments...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Trigger sync
      await syncService.syncQueuedMoments();
      
      // Invalidate queue status to refresh
      ref.invalidate(queueStatusProvider);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

class _DictationControl extends StatelessWidget {
  final bool isDictating;
  final String transcript;
  final double audioLevel;
  final Duration elapsedDuration;
  final String? errorMessage;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _DictationControl({
    required this.isDictating,
    required this.transcript,
    this.audioLevel = 0.0,
    this.elapsedDuration = Duration.zero,
    this.errorMessage,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  /// Format duration as M:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // When NOT dictating: Show mic button (right aligned, centered)
        if (!isDictating)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Semantics(
                label: 'Start dictation',
                button: true,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mic),
                      iconSize: 32,
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: onStart,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(
                        minWidth: 60,
                        minHeight: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        
        // When dictating: Show control row (cancel X, waveform, timer + checkmark)
        if (isDictating)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cancel button (left)
                Semantics(
                  label: 'Cancel dictation',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.cancel),
                    iconSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.only(right: 8),
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    onPressed: onCancel,
                  ),
                ),
                
                // Waveform (middle, expanded)
                Expanded(
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CustomPaint(
                      painter: _WaveformPainter(audioLevel: audioLevel),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                
                // Timer and checkmark (right)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer text
                    Text(
                      _formatDuration(elapsedDuration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(width: 8),
                    // Checkmark button (confirm/stop)
                    Semantics(
                      label: 'Stop dictation',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.check_circle),
                        iconSize: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: onStop,
                      ),
                    ),
                  ],
                ),
              ],
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
        
        // Transcript display
        if (transcript.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Semantics(
              label: 'Dictation transcript',
              liveRegion: true,
              child: Text(
                transcript,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        
        // Helper text when idle
        if (transcript.isEmpty && !isDictating && errorMessage == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tap the microphone to start dictating',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Custom painter for waveform visualization
class _WaveformPainter extends CustomPainter {
  final double audioLevel;

  _WaveformPainter({required this.audioLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Simple waveform visualization: draw bars based on audio level
    final barCount = 20;
    final barWidth = size.width / barCount;
    final spacing = barWidth * 0.2;

    for (int i = 0; i < barCount; i++) {
      // Vary bar height based on audio level and position
      final normalizedPosition = i / barCount;
      final variation = (normalizedPosition * 2 - 1).abs(); // Creates a V shape
      final barHeight = size.height * audioLevel * (0.3 + variation * 0.7);
      
      final x = i * barWidth + spacing / 2;
      final y = (size.height - barHeight) / 2;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth - spacing, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}


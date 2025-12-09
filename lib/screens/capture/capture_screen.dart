import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dictation/flutter_dictation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/capture_state.dart';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/providers/media_picker_provider.dart';
import 'package:memories/providers/memory_timeline_update_bus_provider.dart';
import 'package:memories/providers/main_navigation_provider.dart';
import 'package:memories/services/memory_save_service.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/media_picker_service.dart';
import 'package:memories/services/plugin_audio_normalizer.dart';
import 'package:memories/utils/platform_utils.dart';
import 'package:memories/widgets/media_tray.dart';
import 'package:memories/widgets/inspirational_quote.dart';
import 'package:memories/widgets/save_button_success_checkmark.dart';
import 'package:memories/models/location_suggestion.dart';
import 'package:memories/services/location_suggestion_service.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/screens/memory/memory_detail_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  final _titleController = TextEditingController();
  final ScrollController _mainContentScrollController = ScrollController();
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey _titleFieldKey = GlobalKey();
  bool _isSaving = false;
  bool _isPickingVideo = false;
  bool _isImportingAudio = false;
  bool _showSuccessCheckmark = false;
  bool _hasInitializedDescription = false;
  bool _hasInitializedTitle = false;
  bool _isDescriptionFieldFocused = false;
  bool _tapDownInsideTitleField = false;
  String? _previousInputText; // Track previous state to detect external changes
  String? _previousMemoryTitle;
  String?
      _previousEditingMemoryId; // Track editing state to reset checkmark when editing starts

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_onTitleFieldFocusChanged);
    debugPrint(
      '[CaptureScreen] ${DateTime.now().toIso8601String()} initState',
    );
    // Initialize input text controller from capture state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '[CaptureScreen] ${DateTime.now().toIso8601String()} addPostFrameCallback executing (first frame rendered)');
      final state = ref.read(captureStateNotifierProvider);
      final notifier = ref.read(captureStateNotifierProvider.notifier);

      if (state.inputText != null && !_hasInitializedDescription) {
        _descriptionController.text = state.inputText!;
        _hasInitializedDescription = true;
        _previousInputText = state.inputText;
      }
      if (state.memoryTitle != null && !_hasInitializedTitle) {
        _titleController.text = state.memoryTitle!;
        _hasInitializedTitle = true;
        _previousMemoryTitle = state.memoryTitle;
      }
      // Reset checkmark state when widget initializes (e.g., when navigating to edit)
      if (_showSuccessCheckmark) {
        setState(() {
          _showSuccessCheckmark = false;
        });
      }
      // Initialize previous editing ID
      _previousEditingMemoryId = state.editingMemoryId;

      // Proactively capture location on screen load (if not already captured)
      // Only capture if we don't already have location status set
      if (state.locationStatus == null) {
        debugPrint(
          '[CaptureScreen] ${DateTime.now().toIso8601String()} requesting captureLocation from initState',
        );
        notifier.captureLocation().catchError((e) {
          // Silently handle errors - location capture is optional
          debugPrint('[CaptureScreen] Failed to capture location on init: $e');
        });
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    _titleFocusNode.removeListener(_onTitleFieldFocusChanged);
    _titleFocusNode.dispose();
    _mainContentScrollController.dispose();
    super.dispose();
  }

  /// Sync input text controller with state when state changes (e.g., from dictation)
  /// Only syncs when state changes from an external source, not from TextField edits
  void _syncInputTextController(String? inputText, {bool forceSync = false}) {
    final currentText = _descriptionController.text;
    final newText = inputText ?? '';

    // Sync if:
    // 1. Force sync is requested (e.g., when loading memory for edit)
    // 2. OR the state actually changed from previous value (indicates external change)
    //    AND the controller text doesn't match the new state (needs syncing)
    // This prevents interference when user is typing/deleting, as the controller
    // will already match the state after the onChanged callback updates it
    if (forceSync ||
        (_previousInputText != inputText && currentText != newText)) {
      _descriptionController.text = newText;
    }

    // Update previous value for next comparison
    _previousInputText = inputText;
  }

  /// Sync curated title controller with state
  void _syncTitleController(String? title, {bool forceSync = false}) {
    final currentText = _titleController.text;
    final newText = title ?? '';

    if (forceSync ||
        (_previousMemoryTitle != title && currentText != newText)) {
      _titleController.text = newText;
    }

    _previousMemoryTitle = title;
  }

  void _onTitleFieldFocusChanged() {
    if (_titleFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_titleFocusNode.hasFocus && _titleFieldKey.currentContext != null) {
          Scrollable.ensureVisible(
            _titleFieldKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  bool _isPointInsideTitleField(Offset globalPosition) {
    final context = _titleFieldKey.currentContext;
    if (context == null) return false;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    final origin = renderBox.localToGlobal(Offset.zero);
    final rect = origin & renderBox.size;
    return rect.contains(globalPosition);
  }

  void _handleMainContentTapDown(TapDownDetails details) {
    _tapDownInsideTitleField = _isPointInsideTitleField(details.globalPosition);
  }

  void _handleMainContentTap() {
    if (!_tapDownInsideTitleField) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _tapDownInsideTitleField = false;
  }

  void _refreshLocationAfterClear(CaptureStateNotifier notifier) {
    notifier.captureLocation().catchError((e) {
      debugPrint('[CaptureScreen] Failed to refresh location after clear: $e');
    });
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

    if (mounted) {
      setState(() {
        _isPickingVideo = true;
      });
    }

    try {
      final path = source == ImageSource.camera
          ? await mediaPicker.pickVideoFromCamera()
          : await mediaPicker.pickVideoFromGallery();

      if (path != null && mounted) {
        // Generate video poster thumbnail
        String? posterPath;
        try {
          final tempDir = await getTemporaryDirectory();
          final thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: path,
            thumbnailPath: tempDir.path,
            imageFormat: ImageFormat.JPEG,
            quality: 85,
            timeMs: 1000, // Extract frame at 1 second
          );
          if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
            posterPath = thumbnailPath;
          }
        } catch (e) {
          // Log error but don't fail video addition - poster is optional
          debugPrint('[CaptureScreen] Failed to generate video poster: $e');
        }

        notifier.addVideo(path, posterPath: posterPath);
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
    } finally {
      if (mounted) {
        setState(() {
          _isPickingVideo = false;
        });
      }
    }
  }

  Future<void> _handleImportAudio() async {
    if (_isImportingAudio) {
      debugPrint(
          '[CaptureScreen] _handleImportAudio: Already importing, ignoring tap');
      return;
    }

    debugPrint('[CaptureScreen] _handleImportAudio: Starting audio import');
    final mediaPicker = ref.read(mediaPickerServiceProvider);
    final notifier = ref.read(captureStateNotifierProvider.notifier);
    final audioNormalizer = ref.read(pluginAudioNormalizerProvider);

    // First, show the picker without busy state
    String? audioFilePath;
    try {
      debugPrint('[CaptureScreen] _handleImportAudio: Calling pickAudioFile');
      audioFilePath = await mediaPicker.pickAudioFile();
      debugPrint(
          '[CaptureScreen] _handleImportAudio: pickAudioFile completed, path: $audioFilePath');
    } on MediaPickerException catch (e) {
      debugPrint(
          '[CaptureScreen] _handleImportAudio: MediaPickerException: ${e.message}');
      _showErrorSnackBar(e.message);
      return;
    } catch (e, stackTrace) {
      debugPrint('[CaptureScreen] _handleImportAudio: Exception: $e');
      debugPrint(
          '[CaptureScreen] _handleImportAudio: Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to pick audio file: $e');
      return;
    }

    // User cancelled selection
    if (audioFilePath == null) {
      return;
    }

    // Now show busy state while normalizing
    if (mounted) {
      setState(() {
        _isImportingAudio = true;
      });
    }

    try {
      final normalizedAudio = await audioNormalizer.normalize(audioFilePath);

      await notifier.applyImportedAudio(
        sourceFilePath: audioFilePath,
        normalizedAudio: normalizedAudio,
      );
    } on AudioNormalizationFailure catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Failed to import audio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isImportingAudio = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
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
    final isEditingOffline = notifier.isEditingOffline;
    final isEditing = state.isEditing || isEditingOffline;

    // Creation flow: enforce content requirements (text/photo/video).
    if (!isEditing && !state.canSave) {
      final message = state.memoryType == MemoryType.story
          ? 'Please add text or record audio to save'
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

    // Edit flow (online or offline): allow saving any change, but block if nothing changed.
    if (isEditing && !state.hasUnsavedChanges) {
      // No-op save – nothing to persist.
      return;
    }

    if (_isSaving) {
      return; // Prevent double-save
    }

    setState(() {
      _isSaving = true;
      _showSuccessCheckmark = false;
    });

    try {
      // Step 1: Capture location metadata
      await notifier.captureLocation();

      // Step 2: Set captured timestamp
      final capturedAt = DateTime.now();
      notifier.setCapturedAt(capturedAt);
      final finalState = ref.read(captureStateNotifierProvider);

      // Step 3: Check if editing offline queued memory
      final captureNotifier = ref.read(captureStateNotifierProvider.notifier);
      if (captureNotifier.isEditingOffline) {
        // Update queued offline memory
        final localId = captureNotifier.editingOfflineLocalId!;
        final saveService = ref.read(memorySaveServiceProvider);

        await saveService.updateQueuedMemory(
          localId: localId,
          state: finalState,
        );

        // Emit updated event with localId so timeline can refresh the card
        // This ensures the timeline card shows the updated media immediately
        final bus = ref.read(memoryTimelineUpdateBusProvider);
        bus.emitUpdated(localId);

        captureNotifier.clearOfflineEditing();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Changes saved. This memory will sync when you are online.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          await notifier.clear(keepAudioIfQueued: true);
          _refreshLocationAfterClear(notifier);
          // Navigate back to memory detail screen for the edited memory
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MemoryDetailScreen(
                  memoryId: localId,
                  isOfflineQueued: true,
                ),
              ),
            );
          }
        }
        return;
      }

      // Step 3: Save or update memory with progress updates (or queue if offline)
      final saveService = ref.read(memorySaveServiceProvider);
      // Use originalEditingMemoryId as a safety net so that edits never
      // silently fall back to creating a new memory row.
      final effectiveEditingMemoryId =
          finalState.editingMemoryId ?? finalState.originalEditingMemoryId;
      final isEditing = effectiveEditingMemoryId != null;
      final inputTextChanged = finalState.hasInputTextChanged;

      // Defensive check: If we have originalEditingMemoryId but isEditing is false,
      // this indicates a state corruption issue. Abort to prevent accidental creation.
      if (finalState.originalEditingMemoryId != null && !isEditing) {
        debugPrint(
            '[CaptureScreen] ERROR: originalEditingMemoryId exists but isEditing is false. Aborting save to prevent accidental creation.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Error: Edit state was lost. Please try editing again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Log save operation for debugging
      debugPrint(
          '[CaptureScreen] Saving memory: isEditing=$isEditing, effectiveEditingMemoryId=$effectiveEditingMemoryId');

      Map<String, dynamic>? memoryLocationDataMap;
      try {
        // Get full memory location data from notifier if available
        memoryLocationDataMap = captureNotifier.getMemoryLocationDataForSave();

        if (isEditing) {
          // Update existing memory
          debugPrint(
              '[CaptureScreen] Updating existing memory: $effectiveEditingMemoryId');
          await saveService.updateMemory(
            memoryId: effectiveEditingMemoryId,
            state: finalState,
            inputTextChanged: inputTextChanged,
            memoryLocationDataMap: memoryLocationDataMap,
          );
        } else {
          // Create new memory
          debugPrint('[CaptureScreen] Creating new memory');
          final result = await saveService.saveMemory(
            state: finalState,
            memoryLocationDataMap: memoryLocationDataMap,
          );
          // Emit created event for online saves so timeline can immediately display the new memory
          final bus = ref.read(memoryTimelineUpdateBusProvider);
          bus.emitCreated(result.memoryId);
        }
      } on OfflineException {
        final queueService = ref.read(offlineMemoryQueueServiceProvider);
        final effectiveLocationDataMap = memoryLocationDataMap ??
            captureNotifier.getMemoryLocationDataForSave();

        if (!isEditing) {
          final queuedMemory = QueuedMemory.fromCaptureState(
            localId: OfflineMemoryQueueService.generateLocalId(),
            state: finalState,
            // fromCaptureState will prefer normalizedAudioPath if available
            audioPath: finalState.audioPath,
            audioDuration: finalState.audioDuration,
            capturedAt: capturedAt,
            memoryLocationData: effectiveLocationDataMap,
          );
          final localId = queuedMemory.localId;
          await queueService.enqueue(queuedMemory);

          await _showOfflineQueueSuccess(
            message:
                'Saved offline. We\'ll sync this memory once you reconnect.',
            notifier: notifier,
            localId: localId,
          );
        } else {
          final String targetMemoryId = effectiveEditingMemoryId;
          final queuedMemory = QueuedMemory.fromCaptureState(
            localId: OfflineMemoryQueueService.generateLocalId(),
            state: finalState,
            // fromCaptureState will prefer normalizedAudioPath if available
            audioPath: finalState.audioPath,
            audioDuration: finalState.audioDuration,
            capturedAt: capturedAt,
            operation: QueuedMemory.operationUpdate,
            targetMemoryId: targetMemoryId,
            memoryLocationData: effectiveLocationDataMap,
          );
          await queueService.enqueue(queuedMemory);

          // Emit updated event so timeline can reflect the pending edit immediately
          // The timeline will merge the queued edit with the existing server-backed entry
          final bus = ref.read(memoryTimelineUpdateBusProvider);
          bus.emitUpdated(targetMemoryId);

          await _showOfflineQueueSuccess(
            message:
                'Edits saved offline. We\'ll update this memory once you\'re online.',
            notifier: notifier,
          );
        }
        return;
      }

      // Step 4: Show success checkmark and navigate appropriately
      if (mounted) {
        // Show success checkmark briefly before navigation
        setState(() {
          _isSaving = false;
          _showSuccessCheckmark = true;
        });

        // Wait for checkmark animation
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          // Capture effective editing ID BEFORE clearing state (since clear() resets it)
          final savedEditingMemoryId = effectiveEditingMemoryId;
          final wasEditing = isEditing && savedEditingMemoryId != null;

          // Clear state completely (including editingMemoryId)
          await notifier.clear();
          _refreshLocationAfterClear(notifier);
          // Reset checkmark before navigation
          setState(() {
            _showSuccessCheckmark = false;
          });

          if (wasEditing) {
            // When editing, emit updated event so timeline can refresh with updated data
            // savedEditingMemoryId is guaranteed to be non-null when wasEditing is true
            final memoryId = savedEditingMemoryId;
            debugPrint(
                '[CaptureScreen] Emitting updated event for memory: $memoryId');
            final bus = ref.read(memoryTimelineUpdateBusProvider);
            bus.emitUpdated(memoryId);

            // When editing, navigate back to memory detail screen
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MemoryDetailScreen(
                    memoryId: memoryId,
                    isOfflineQueued: false,
                  ),
                ),
              );
            }
          } else {
            // When creating, navigate to timeline
            // Dismiss keyboard before navigation
            FocusScope.of(context).unfocus();
            // Only pop if there's a route to pop (i.e., if this screen was pushed)
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            // Switch to timeline tab
            ref
                .read(mainNavigationTabNotifierProvider.notifier)
                .switchToTimeline();
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
      if (mounted && !_showSuccessCheckmark) {
        setState(() {
          _isSaving = false;
          _showSuccessCheckmark = false;
        });
      }
    }
  }

  Future<void> _showOfflineQueueSuccess({
    required String message,
    required CaptureStateNotifier notifier,
    String? localId,
  }) async {
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _showSuccessCheckmark = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) {
      return;
    }

    await notifier.clear(keepAudioIfQueued: true);
    _refreshLocationAfterClear(notifier);

    setState(() {
      _showSuccessCheckmark = false;
    });

    // Unfocus input before navigation
    FocusScope.of(context).unfocus();

    // Navigate back if possible
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Switch to timeline tab to match online save flow
    ref.read(mainNavigationTabNotifierProvider.notifier).switchToTimeline();

    // Emit created event once navigation has returned to the timeline tab
    if (localId != null) {
      final bus = ref.read(memoryTimelineUpdateBusProvider);
      bus.emitCreated(localId);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildStartTime = DateTime.now();
    debugPrint(
        '[CaptureScreen.build] ${buildStartTime.toIso8601String()} START');

    final state = ref.watch(captureStateNotifierProvider);
    final canTapAddVideo = state.canAddVideo && !_isPickingVideo;
    debugPrint(
        '[CaptureScreen.build] ${DateTime.now().toIso8601String()} after watch provider (${DateTime.now().difference(buildStartTime).inMilliseconds}ms)');

    final notifier = ref.read(captureStateNotifierProvider.notifier);
    debugPrint(
        '[CaptureScreen.build] ${DateTime.now().toIso8601String()} after read notifier (${DateTime.now().difference(buildStartTime).inMilliseconds}ms)');
    final isEditingOffline = notifier.isEditingOffline;
    final showTitleField = state.isEditing || isEditingOffline;

    // Initialize previous input text if not set
    if (_previousInputText == null) {
      _previousInputText = state.inputText;
    }

    // Reset checkmark when editing state changes (user starts editing a memory)
    // or when state is cleared (normal capture state)
    final currentEditingId = state.editingMemoryId;
    final editingStateChanged = _previousEditingMemoryId != currentEditingId;
    final shouldResetCheckmark = !_isSaving &&
        (_showSuccessCheckmark &&
            (editingStateChanged || !state.hasUnsavedChanges));

    if (shouldResetCheckmark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showSuccessCheckmark = false;
          });
        }
      });
    }

    // Update previous editing ID for next comparison
    _previousEditingMemoryId = currentEditingId;

    // Sync input text controller when state.inputText changes (e.g., from dictation)
    // Only syncs when state changes from external source, not from TextField edits
    // Force sync when editing a memory to ensure controller is populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isEditing = state.editingMemoryId != null;
      final shouldForceDescriptionSync = (isEditing || isEditingOffline) &&
          (_descriptionController.text != (state.inputText ?? ''));
      _syncInputTextController(state.inputText,
          forceSync: shouldForceDescriptionSync);

      final shouldForceTitleSync = (isEditing || isEditingOffline) &&
          (_titleController.text != (state.memoryTitle ?? ''));
      _syncTitleController(state.memoryTitle, forceSync: shouldForceTitleSync);
    });

    debugPrint(
        '[CaptureScreen.build] ${DateTime.now().toIso8601String()} about to return widget (${DateTime.now().difference(buildStartTime).inMilliseconds}ms)');
    final result = PopScope(
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
        resizeToAvoidBottomInset: true,
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
              // Main content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: _handleMainContentTapDown,
                      onTap: _handleMainContentTap,
                      child: SingleChildScrollView(
                        controller: _mainContentScrollController,
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Inspirational quote - hide when media/tags are present to make room
                              InspirationalQuote(
                                showQuote: !_isDescriptionFieldFocused &&
                                    state.photoPaths.isEmpty &&
                                    state.videoPaths.isEmpty &&
                                    state.tags.isEmpty &&
                                    (state.inputText == null ||
                                        state.inputText!.isEmpty),
                              ),
                              Column(
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
                                                color: Colors.black
                                                    .withOpacity(0.08),
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
                                              customBorder:
                                                  const CircleBorder(),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
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
                                                color: Colors.black
                                                    .withOpacity(0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              onTap: canTapAddVideo
                                                  ? _handleAddVideo
                                                  : null,
                                              customBorder:
                                                  const CircleBorder(),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                width: 48,
                                                height: 48,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.videocam,
                                                  size: 18,
                                                  color: canTapAddVideo
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
                                                color: Colors.black
                                                    .withOpacity(0.08),
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
                                              customBorder:
                                                  const CircleBorder(),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
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
                                      if (state.memoryType ==
                                          MemoryType.story) ...[
                                        const SizedBox(width: 8),
                                        Semantics(
                                          label: 'Import audio',
                                          button: true,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: _isImportingAudio
                                                    ? null
                                                    : _handleImportAudio,
                                                customBorder:
                                                    const CircleBorder(),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  width: 48,
                                                  height: 48,
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    Icons.multitrack_audio,
                                                    size: 18,
                                                    color: _isImportingAudio
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.38)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_isPickingVideo)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child:
                                          const _VideoSelectionProgressBanner(
                                        message: 'Preparing video preview...',
                                      ),
                                    ),
                                  if (_isPickingVideo)
                                    const SizedBox(height: 12),
                                  if (_isImportingAudio)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: const _AudioImportBusyBanner(),
                                    ),
                                  if (_isImportingAudio)
                                    const SizedBox(height: 12),

                                  // Combined container for tags, media, and uploaded audio
                                  if (state.photoPaths.isNotEmpty ||
                                      state.videoPaths.isNotEmpty ||
                                      state.existingPhotoUrls.isNotEmpty ||
                                      state.existingVideoUrls.isNotEmpty ||
                                      state.tags.isNotEmpty ||
                                      // For stories, also surface an imported/recorded or existing audio indicator
                                      (state.memoryType == MemoryType.story &&
                                          (state.normalizedAudioPath != null ||
                                              state.audioPath != null ||
                                              state.existingAudioPath != null)))
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5),
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
                                            color:
                                                Colors.black.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Media strip - horizontally scrolling
                                          if (state.photoPaths.isNotEmpty ||
                                              state.videoPaths.isNotEmpty ||
                                              state.existingPhotoUrls
                                                  .isNotEmpty ||
                                              state.existingVideoUrls
                                                  .isNotEmpty ||
                                              (state.memoryType ==
                                                      MemoryType.story &&
                                                  (state.normalizedAudioPath !=
                                                          null ||
                                                      state.audioPath != null ||
                                                      state.existingAudioPath !=
                                                          null)))
                                            SizedBox(
                                              height: 100,
                                              child: MediaTray(
                                                key: ValueKey([
                                                  ...state.photoPaths,
                                                  ...state.videoPaths,
                                                  ...state.existingPhotoUrls,
                                                  ...state.existingVideoUrls,
                                                ].join('|')),
                                                photoPaths: state.photoPaths,
                                                videoPaths: state.videoPaths,
                                                videoPosterPaths:
                                                    state.videoPosterPaths,
                                                existingPhotoUrls:
                                                    state.existingPhotoUrls,
                                                existingVideoUrls:
                                                    state.existingVideoUrls,
                                                existingVideoPosterUrls: state
                                                    .existingVideoPosterUrls,
                                                onPhotoRemoved: (index) =>
                                                    notifier.removePhoto(index),
                                                onVideoRemoved: (index) =>
                                                    notifier.removeVideo(index),
                                                onExistingPhotoRemoved: state
                                                        .isEditing
                                                    ? (index) => notifier
                                                        .removeExistingPhoto(
                                                            index)
                                                    : null,
                                                onExistingVideoRemoved: state
                                                        .isEditing
                                                    ? (index) => notifier
                                                        .removeExistingVideo(
                                                            index)
                                                    : null,
                                                canAddPhoto: state.canAddPhoto,
                                                canAddVideo: state.canAddVideo,
                                                hasAudioAttachment: state
                                                            .memoryType ==
                                                        MemoryType.story &&
                                                    (state.normalizedAudioPath !=
                                                            null ||
                                                        state.audioPath !=
                                                            null ||
                                                        state.existingAudioPath !=
                                                            null),
                                                audioDurationSeconds:
                                                    state.audioDuration,
                                                audioFileSizeBytes:
                                                    state.audioFileSizeBytes,
                                                onAudioRemoved: notifier
                                                    .removeAudioAttachment,
                                              ),
                                            ),
                                          // Spacing between media and tags
                                          if ((state.photoPaths.isNotEmpty ||
                                                  state
                                                      .videoPaths.isNotEmpty) &&
                                              state.tags.isNotEmpty)
                                            const SizedBox(height: 8),
                                          // Tags - horizontally scrolling
                                          if (state.tags.isNotEmpty)
                                            SizedBox(
                                              height: 36,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    for (int i = 0;
                                                        i < state.tags.length;
                                                        i++)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                          right: i <
                                                                  state.tags
                                                                          .length -
                                                                      1
                                                              ? 8
                                                              : 0,
                                                        ),
                                                        child: InputChip(
                                                          label: Text(
                                                            state.tags[i],
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .onSurface,
                                                                ),
                                                          ),
                                                          onDeleted: () =>
                                                              notifier
                                                                  .removeTag(i),
                                                          deleteIcon: Icon(
                                                            Icons.close,
                                                            size: 16,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurface,
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          backgroundColor: Theme
                                                                  .of(context)
                                                              .scaffoldBackgroundColor,
                                                          side: BorderSide.none,
                                                          padding:
                                                              const EdgeInsets
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

                                  const SizedBox(height: 8),

                                  // Date picker row - full-width tappable bar
                                  _MemoryDatePicker(
                                    memoryDate:
                                        state.memoryDate ?? DateTime.now(),
                                    onDateChanged: (date) =>
                                        notifier.setMemoryDate(date),
                                  ),

                                  const SizedBox(height: 8),

                                  // Location picker row - full-width tappable bar
                                  _MemoryLocationPicker(
                                    memoryLocationLabel:
                                        state.memoryLocationLabel,
                                    gpsLatitude: state.latitude,
                                    gpsLongitude: state.longitude,
                                    locationStatus: state.locationStatus,
                                    isReverseGeocoding:
                                        state.isReverseGeocoding,
                                    onLocationChanged: ({
                                      String? label,
                                      double? latitude,
                                      double? longitude,
                                    }) =>
                                        notifier.setMemoryLocationLabel(
                                      label: label,
                                      latitude: latitude,
                                      longitude: longitude,
                                    ),
                                  ),

                                  if (showTitleField) ...[
                                    const SizedBox(height: 8),
                                    _MemoryTitleField(
                                      controller: _titleController,
                                      focusNode: _titleFocusNode,
                                      textFieldKey: _titleFieldKey,
                                      onChanged: notifier.setMemoryTitle,
                                      onClear: () {
                                        notifier.setMemoryTitle(null);
                                        _titleController.clear();
                                        _titleFocusNode.requestFocus();
                                      },
                                      showLabel: false,
                                    ),
                                  ],

                                  const SizedBox(height: 8),

                                  // Swipeable input container (dictation and type modes) - EXPANDABLE
                                  _SwipeableInputContainer(
                                    inputMode: state.inputMode,
                                    memoryType: state.memoryType,
                                    isDictating: state.isDictating,
                                    transcript: state.inputText ?? '',
                                    elapsedDuration: state.elapsedDuration,
                                    errorMessage: state.errorMessage,
                                    descriptionController:
                                        _descriptionController,
                                    onTextFieldFocusChanged: (isFocused) {
                                      if (_isDescriptionFieldFocused !=
                                          isFocused) {
                                        setState(() {
                                          _isDescriptionFieldFocused =
                                              isFocused;
                                        });
                                      }
                                    },
                                    onInputModeChanged: (mode) =>
                                        notifier.setInputMode(mode),
                                    onStartDictation: () =>
                                        notifier.startDictation(),
                                    onStopDictation: () =>
                                        notifier.stopDictation(),
                                    onCancelDictation: () =>
                                        notifier.cancelDictation(),
                                    onTextChanged: (value) =>
                                        notifier.updateInputText(
                                            value.isEmpty ? null : value),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Bottom section with buttons anchored above navigation bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              onPressed:
                                  (state.hasUnsavedChanges || state.isEditing)
                                      ? () => _handleCancelWithConfirmation(
                                          context, ref, notifier)
                                      : null,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(0, 48),
                                backgroundColor:
                                    (state.hasUnsavedChanges || state.isEditing)
                                        ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                        : null,
                                foregroundColor: (state.hasUnsavedChanges ||
                                        state.isEditing)
                                    ? Theme.of(context).colorScheme.onSurface
                                    : null,
                                elevation:
                                    (state.hasUnsavedChanges || state.isEditing)
                                        ? 1
                                        : 0,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save button with compact spinner and success checkmark
                        Expanded(
                          child: Semantics(
                            label: 'Save memory',
                            button: true,
                            child: ElevatedButton(
                              onPressed: (((state.isEditing ||
                                              ref
                                                  .read(
                                                      captureStateNotifierProvider
                                                          .notifier)
                                                  .isEditingOffline)
                                          ? state.hasUnsavedChanges
                                          : state.canSave) &&
                                      !_isSaving &&
                                      !_showSuccessCheckmark)
                                  ? _handleSave
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(0, 48),
                              ),
                              child: _showSuccessCheckmark
                                  ? const SaveButtonSuccessCheckmark()
                                  : _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
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

    debugPrint(
        '[CaptureScreen.build] ${DateTime.now().toIso8601String()} COMPLETE (${DateTime.now().difference(buildStartTime).inMilliseconds}ms)');
    return result;
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
    final wasEditing = state.isEditing;

    // Dismiss keyboard first - use both methods to ensure it closes
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Clear state completely
    await notifier.clear();
    _refreshLocationAfterClear(notifier);

    // Reset input mode to dictation (default)
    notifier.setInputMode(InputMode.dictation);

    // Clear the description controller text
    _descriptionController.clear();

    // Ensure keyboard is dismissed after state is cleared
    // Use a small delay to ensure state updates complete first
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }

    // Navigate back if editing (to detail screen)
    // If creating, stay on capture screen (or pop if screen was pushed)
    if (!mounted) return;
    if (wasEditing && Navigator.of(context).canPop()) {
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

class _MemoryTitleField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;
  final bool showLabel;
  final FocusNode? focusNode;
  final Key? textFieldKey;

  const _MemoryTitleField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.showLabel = true,
    this.focusNode,
    this.textFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textField = TextField(
      key: textFieldKey,
      focusNode: focusNode,
      controller: controller,
      onChanged: (value) => onChanged(value.isEmpty ? null : value),
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      maxLines: 1,
      decoration: InputDecoration(
        hintText: null,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: theme.textTheme.bodyMedium,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              'Curated title',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final showClear = value.text.isNotEmpty;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: child!),
                  if (showClear)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(
                        Icons.clear,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              );
            },
            child: textField,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(8),
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
              ? Transform.translate(
                  offset: const Offset(0, -40),
                  child: Center(
                    child: Semantics(
                      label: 'Dictation transcript',
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          displayText,
                          key: ValueKey(displayText),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
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
                    // Add padding at the bottom to prevent text from being hidden behind mic button and hint text
                    // Hint text is positioned at bottom: 8, with AudioControlsDecorator + spacing + hint row (~30px total)
                    padding: const EdgeInsets.only(bottom: 110),
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
                              .bodyMedium
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
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: AudioControlsDecorator(
                        isListening: isDictating,
                        elapsedTime: elapsedDuration,
                        onMicPressed: onMicPressed,
                        onCancelPressed: onCancelPressed,
                        waveformController: waveformController,
                        child: const SizedBox(height: 0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
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
                        ],
                      ),
                    ),
                  ],
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
  final Future<void> Function(InputMode) onInputModeChanged;
  final VoidCallback onStartDictation;
  final VoidCallback onStopDictation;
  final VoidCallback onCancelDictation;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<bool>? onTextFieldFocusChanged;

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
    this.onTextFieldFocusChanged,
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
  final GlobalKey _textFieldKey = GlobalKey();
  double? _dragStartX;
  double? _cachedHeight; // Cache height to prevent resizing during swipe
  bool _isTextFieldFocused = false;

  void _handleSwipePointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
  }

  void _handleSwipePointerMove(PointerMoveEvent event) {
    if (_dragStartX == null) return;
    final deltaX = (event.position.dx - _dragStartX!).abs();
    if (deltaX > 10) {
      _textFieldFocusNode.unfocus();
    }
  }

  void _resetSwipeTracking() {
    _dragStartX = null;
  }

  @override
  void initState() {
    super.initState();
    // Initialize page controller to dictation mode (page 0) or type mode (page 1)
    _pageController = PageController(
      initialPage: widget.inputMode == InputMode.dictation ? 0 : 1,
    );

    // Listen to page controller position changes to detect dragging
    _pageController.addListener(_onPageControllerChanged);

    // Listen to focus changes to update text alignment and scroll into view
    _textFieldFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    final wasFocused = _isTextFieldFocused;
    final isNowFocused = _textFieldFocusNode.hasFocus;

    if (isNowFocused != wasFocused) {
      debugPrint(
        '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} focusChanged: $isNowFocused',
      );
      setState(() {
        _isTextFieldFocused = isNowFocused;
      });
      widget.onTextFieldFocusChanged?.call(isNowFocused);

      // When text field gains focus, scroll it into view after keyboard appears
      if (isNowFocused) {
        debugPrint(
          '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} scheduling ensureVisible for TextField',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _textFieldKey.currentContext != null) {
            debugPrint(
              '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} ensureVisible executing',
            );
            Scrollable.ensureVisible(
              _textFieldKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.1, // Show near top of visible area
            );
          }
        });
      }
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
      debugPrint(
        '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} didUpdateWidget -> inputMode=${widget.inputMode}',
      );
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

          // When switching to type mode, move cursor to the end of the text and scroll to it
          if (widget.inputMode == InputMode.type &&
              widget.descriptionController.text.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Focus the text field first to ensure it can scroll
              if (!_textFieldFocusNode.hasFocus) {
                _textFieldFocusNode.requestFocus();
              }
              // Then set cursor to end, which will trigger automatic scrolling
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

  Future<void> _onPageChanged(int page) async {
    final newMode = page == 0 ? InputMode.dictation : InputMode.type;
    debugPrint(
      '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} onPageChanged -> page=$page mode=$newMode',
    );
    if (newMode != widget.inputMode) {
      // Reset cached height when page changes to allow recalculation
      _cachedHeight = null;
      debugPrint(
        '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} calling onInputModeChanged($newMode)',
      );
      await widget.onInputModeChanged(newMode);

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

      // When switching to type mode, move cursor to the end of the text and scroll to it
      if (newMode == InputMode.type &&
          widget.descriptionController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Focus the text field first to ensure it can scroll
          if (!_textFieldFocusNode.hasFocus) {
            _textFieldFocusNode.requestFocus();
          }
          // Then set cursor to end, which will trigger automatic scrolling
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
    final keyboardInset = widget.inputMode == InputMode.type
        ? MediaQuery.of(context).viewInsets.bottom
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate max height: screen height minus app bar, queue chips, padding, other content, and navigation bar
        // Use a reasonable max height that ensures content doesn't scroll beyond the menu
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.4; // Max 40% of screen height
        final minHeight =
            180.0; // Minimum height for consistent layout - increased for larger initial size

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

        return AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SizedBox(
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: _handleSwipePointerDown,
                        onPointerMove: _handleSwipePointerMove,
                        onPointerUp: (_) => _resetSwipeTracking(),
                        onPointerCancel: (_) => _resetSwipeTracking(),
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
                                        key: _textFieldKey,
                                        controller:
                                            widget.descriptionController,
                                        focusNode: _textFieldFocusNode,
                                        onTap: () {
                                          debugPrint(
                                            '[SwipeableInputContainer] ${DateTime.now().toIso8601String()} textField onTap',
                                          );
                                        },
                                        onTapOutside: (_) {
                                          FocusScope.of(context).unfocus();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          // Add bottom padding to prevent text from overlapping hint text
                                          // Hint text is positioned at bottom: 4, with ~24px height
                                          contentPadding:
                                              const EdgeInsets.only(bottom: 30),
                                        ),
                                        maxLines: null,
                                        expands: true,
                                        textAlign: TextAlign.start,
                                        textAlignVertical:
                                            TextAlignVertical.top,
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
                                            child: Transform.translate(
                                              offset: const Offset(0, -40),
                                              child: Center(
                                                child: Text(
                                                  _getPlaceholderText(
                                                      widget.memoryType),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
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
                                        ),
                                      // Swipe hint centered at bottom
                                      Positioned(
                                        bottom: 4,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Swipe to talk',
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
          ),
        );
      },
    );
  }
}

/// Date picker widget for selecting memory date and time
class _MemoryDatePicker extends StatelessWidget {
  final DateTime memoryDate;
  final ValueChanged<DateTime> onDateChanged;

  const _MemoryDatePicker({
    required this.memoryDate,
    required this.onDateChanged,
  });

  Future<void> _showDatePicker(BuildContext context) async {
    // Convert UTC to local time for display
    final localDate = memoryDate.toLocal();

    // Show date picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: localDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Select date',
    );

    if (pickedDate == null) return;

    // Show time picker immediately after date is selected
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localDate),
      helpText: 'Select time',
    );

    if (pickedTime == null) return;

    // Combine date and time, then convert to UTC for storage
    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Convert to UTC for storage
    final utcDateTime = combinedDateTime.toUtc();

    onDateChanged(utcDateTime);
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(localDate)} at ${timeFormat.format(localDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Date & time: ${_formatDate(memoryDate)}',
      button: true,
      child: InkWell(
        onTap: () => _showDatePicker(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDate(memoryDate),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Location picker widget for selecting memory location
class _MemoryLocationPicker extends StatelessWidget {
  final String? memoryLocationLabel;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String? locationStatus;
  final bool isReverseGeocoding;
  final void Function({String? label, double? latitude, double? longitude})
      onLocationChanged;

  const _MemoryLocationPicker({
    required this.memoryLocationLabel,
    this.gpsLatitude,
    this.gpsLongitude,
    this.locationStatus,
    this.isReverseGeocoding = false,
    required this.onLocationChanged,
  });

  Future<void> _showLocationPicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LocationPickerBottomSheet(
        initialLabel: memoryLocationLabel,
        gpsLatitude: gpsLatitude,
        gpsLongitude: gpsLongitude,
        locationStatus: locationStatus,
        onLocationSaved: onLocationChanged,
      ),
    );
  }

  String _getDisplayText() {
    // Show resolved location name if available
    if (memoryLocationLabel != null && memoryLocationLabel!.isNotEmpty) {
      return memoryLocationLabel!;
    }

    // Show "Detecting location..." while reverse geocoding is in progress
    if (isReverseGeocoding) {
      return 'Detecting location…';
    }

    // Check GPS status
    if (locationStatus == 'granted' &&
        gpsLatitude != null &&
        gpsLongitude != null) {
      // GPS captured but reverse geocoding hasn't completed yet (or failed)
      // Show a more neutral message since we're auto-detecting
      return 'Detecting location…';
    }

    if (locationStatus == 'denied' || locationStatus == 'unavailable') {
      return 'Location unavailable (tap to set)';
    }

    // If we have no location status yet, we are not actually detecting anything.
    // Default to unavailable to avoid implying background work that isn't happening.
    return 'Location unavailable (tap to set)';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Location: ${_getDisplayText()}',
      button: true,
      child: InkWell(
        onTap: () => _showLocationPicker(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDisplayText(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                    if (isReverseGeocoding)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for location picker
class _LocationPickerBottomSheet extends ConsumerStatefulWidget {
  final String? initialLabel;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String? locationStatus;
  final void Function({String? label, double? latitude, double? longitude})
      onLocationSaved;

  const _LocationPickerBottomSheet({
    this.initialLabel,
    this.gpsLatitude,
    this.gpsLongitude,
    this.locationStatus,
    required this.onLocationSaved,
  });

  @override
  ConsumerState<_LocationPickerBottomSheet> createState() =>
      _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState
    extends ConsumerState<_LocationPickerBottomSheet> {
  late final TextEditingController _textController;
  bool _hasGpsLocation = false;
  List<LocationSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _isOffline = false;
  String? _lastSearchQuery;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialLabel ?? '');
    _hasGpsLocation = widget.locationStatus == 'granted' &&
        widget.gpsLatitude != null &&
        widget.gpsLongitude != null;

    // Check connectivity and load initial suggestions if online
    _checkConnectivityAndSearch();

    // Listen to text changes for debounced search
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    // Cancel any pending debounced searches
    final suggestionService = ref.read(locationSuggestionServiceProvider);
    suggestionService.cancelDebouncedSearch();
    super.dispose();
  }

  Future<void> _checkConnectivityAndSearch() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    setState(() {
      _isOffline = !isOnline;
    });

    // If online and we have an initial label, try to search
    if (isOnline && _textController.text.trim().length >= 2) {
      _performSearch(_textController.text.trim());
    }
  }

  void _onTextChanged() {
    final query = _textController.text.trim();

    // Clear suggestions if query is too short
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    // Skip if same query (avoid duplicate searches)
    if (query == _lastSearchQuery) {
      return;
    }

    // Only search if online
    if (!_isOffline) {
      _performDebouncedSearch(query);
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  Future<void> _performDebouncedSearch(String query) async {
    setState(() {
      _isLoadingSuggestions = true;
      _lastSearchQuery = query;
    });

    try {
      final suggestionService = ref.read(locationSuggestionServiceProvider);

      // Get user location for biasing if available
      ({double latitude, double longitude})? userLocation;
      if (_hasGpsLocation &&
          widget.gpsLatitude != null &&
          widget.gpsLongitude != null) {
        userLocation = (
          latitude: widget.gpsLatitude!,
          longitude: widget.gpsLongitude!,
        );
      }

      final results = await suggestionService.searchDebounced(
        query: query,
        limit: 5,
        userLocation: userLocation,
        delay: const Duration(milliseconds: 300),
      );

      // Only update if query hasn't changed
      if (mounted && query == _textController.text.trim()) {
        setState(() {
          _suggestions = results;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      // On error, clear suggestions but don't show error to user
      // They can still use manual text entry
      if (mounted && query == _textController.text.trim()) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _lastSearchQuery = query;
    });

    try {
      final suggestionService = ref.read(locationSuggestionServiceProvider);

      ({double latitude, double longitude})? userLocation;
      if (_hasGpsLocation &&
          widget.gpsLatitude != null &&
          widget.gpsLongitude != null) {
        userLocation = (
          latitude: widget.gpsLatitude!,
          longitude: widget.gpsLongitude!,
        );
      }

      final results = await suggestionService.search(
        query: query,
        limit: 5,
        userLocation: userLocation,
      );

      if (mounted && query == _textController.text.trim()) {
        setState(() {
          _suggestions = results;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted && query == _textController.text.trim()) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _handleUseCurrentLocation() {
    if (_hasGpsLocation) {
      widget.onLocationSaved(
        label: 'Current location',
        latitude: widget.gpsLatitude,
        longitude: widget.gpsLongitude,
      );
      Navigator.pop(context);
    }
  }

  void _handleSuggestionSelected(LocationSuggestion suggestion) {
    // Fill the text field with the suggestion's display name
    _textController.text = suggestion.displayName;

    // Save with the suggestion's coordinates and structured data
    widget.onLocationSaved(
      label: suggestion.displayName,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
    );
    Navigator.pop(context);
  }

  void _handleSave() {
    final label = _textController.text.trim();
    widget.onLocationSaved(
      label: label.isEmpty ? null : label,
      latitude: widget.gpsLatitude,
      longitude: widget.gpsLongitude,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Text(
              'Memory Location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Search/input field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Search for a place or type one in…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              autofocus:
                  widget.initialLabel == null || widget.initialLabel!.isEmpty,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSave(),
            ),
            // Offline hint
            if (_isOffline) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Offline: suggestions not available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ],
            // Suggestions list
            if (_suggestions.isNotEmpty && !_isOffline) ...[
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.1),
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return InkWell(
                        onTap: () => _handleSuggestionSelected(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      suggestion.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (suggestion.secondaryLine != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        suggestion.secondaryLine!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // Use GPS location option (shown when GPS is available and user wants to change/edit)
            // Only show if we don't already have a location label set (to avoid redundancy)
            if (_hasGpsLocation && widget.initialLabel == null) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _handleUseCurrentLocation,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use GPS location',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              _isOffline
                                  ? 'Coordinates only'
                                  : 'From current position',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _handleSave,
                  child: const Text('Save location'),
                ),
              ],
            ),
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

class _VideoSelectionProgressBanner extends StatelessWidget {
  final String message;

  const _VideoSelectionProgressBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Video preparation in progress',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioImportBusyBanner extends StatelessWidget {
  const _AudioImportBusyBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Audio is being prepared for upload',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Preparing audio for upload…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
